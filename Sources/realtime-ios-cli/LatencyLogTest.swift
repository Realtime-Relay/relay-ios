//
//  LatencyLogTest.swift
//  relay-ios
//
//  Created by Shaxzod on 19/04/25
//

import Foundation
import Realtime

@available(iOS 15.0, *)
enum LatencyLogTest {
    static func main() async throws {
        print("\n=== Running Latency Log Test ===")
        let realtime = try Realtime(
            apiKey: "***API_KEY***",
            secret: "***SECRET_KEY***"
        )
        try realtime.prepare(staging: false, opts: ["debug": true])
        try await realtime.connect()
        print("✅ Connected for latency log test")

        // Use a valid topic without periods
        let topic = "latency_log_test_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let listener = ChatMessageListener()
        try await realtime.on(topic: topic, listener: listener)
        print("✅ Subscribed to topic: \(topic)")

        // Publish a few messages to trigger latency logging
        print("\n📤 Publishing test messages to trigger latency logging...")
        for i in 1...5 {
            let msg = ["sender": "Test", "text": "Latency test #\(i)", "timestamp": Date().description]
            let success = try await realtime.publish(topic: topic, message: msg)
            if success {
                print("✅ Published test message #\(i)")
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        // Wait to allow latency log to trigger by time (30s)
        print("\n⏳ Waiting 31 seconds to trigger latency log by interval...")
        print("   The Realtime client will automatically log latency data to the backend")
        print("   during this time. Check the debug logs for 'Sent latency data to backend' messages.")
        try await Task.sleep(nanoseconds: 31_000_000_000)

        // Cleanup
        _ = try await realtime.off(topic: topic)
        try await realtime.close()
        print("\n✅ Latency log test completed")
        print("   The Realtime client automatically logs latency data to the backend")
        print("   when messages are received or when the latency log interval is reached.")
    }
} 