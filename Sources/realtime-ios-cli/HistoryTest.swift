//
//  HistoryTest.swift
//  realtime-ios-cli
//
//  Created by Shaxzod on 19/04/25.
//

import Foundation
import Realtime

class HistoryTest {
    static func main() async throws {
        print("\n=== Running History Test ===")
        
        // Initialize Realtime client
        let realtime = try Realtime(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVQU9STjRWQkNXQzJORU1FVkpFWUY3VERIUVdYTUNLTExTWExNTjZRTjRBVU1WUElDSVJOSEpJRyIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDUwNTE2NjcsImp0aSI6IllVMG50TXFNcHhwWFNWbUp0OUJDazhhV0dxd0NwYytVQ0xwa05lWVBVcDNNRTNQWDBRcUJ2ZjBBbVJXMVRDamEvdTg2emIrYUVzSHVKUFNmOFB2SXJnPT0ifQ._LtZJnTADAnz3N6U76OaA-HCYq-XxckChk1WlHi_oZXfYP2vqcGIiNDFSQ-XpfjUTfKtXEuzcf_BDq54nSEMAA",
            secret: "SUAPWRWRITWYL4YP7B5ZHU3W2G2ZPYJ47IN4UWNHLMFTSIJEOMQJWWSWGY"
        )
        
        // Prepare with production settings (staging: false)
        try realtime.prepare(staging: false, opts: ["debug": true])
        
        // Connect to the service
        try await realtime.connect()
        print("✅ Successfully connected to Realtime service")
        
        // Create a unique topic for testing
        let historyTopic = "history_test_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        print("\n📱 Using topic: \(historyTopic)")
        
        // Send some test messages
        let testMessages = [
            ["sender": "User1", "text": "First message", "timestamp": Date().description],
            ["sender": "User2", "text": "Second message", "timestamp": Date().description],
            ["sender": "User1", "text": "Third message", "timestamp": Date().description],
            ["sender": "User3", "text": "Fourth message", "timestamp": Date().description],
            ["sender": "User2", "text": "Fifth message", "timestamp": Date().description]
        ]
        
        print("\n📤 Sending test messages...")
        for message in testMessages {
            let success = try await realtime.publish(topic: historyTopic, message: message)
            if success {
                print("✅ Sent: \(message["text"] ?? "")")
            }
            // Add a small delay between messages
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        // Wait for messages to be processed
        print("\n⏳ Waiting for messages to be processed...")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Test 1: Get all messages
        print("\n🧪 Test 1: Getting all messages")
        let startDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let allMessages = try await realtime.history(topic: historyTopic, start: startDate)
        print("✅ Retrieved \(allMessages.count) messages")
        
        // Print the messages
        for (index, message) in allMessages.enumerated() {
            print("  Message \(index + 1):")
            if let sender = message["sender"] as? String {
                print("    From: \(sender)")
            }
            if let text = message["text"] as? String {
                print("    Text: \(text)")
            }
            if let timestamp = message["timestamp"] as? String {
                print("    Time: \(timestamp)")
            }
        }
        
        // Test 2: Get messages with limit
        print("\n🧪 Test 2: Getting messages with limit")
        let limitedMessages = try await realtime.history(topic: historyTopic, start: startDate, limit: 2)
        print("✅ Retrieved \(limitedMessages.count) messages with limit")
        
        // Test 3: Get messages within a time range
        print("\n🧪 Test 3: Getting messages within a time range")
        let endDate = Date()
        let rangeMessages = try await realtime.history(topic: historyTopic, start: startDate, end: endDate)
        print("✅ Retrieved \(rangeMessages.count) messages within time range")
        
        // Cleanup
        print("\n🧹 Cleaning up...")
        let unsubscribed = try await realtime.off(topic: historyTopic)
        if unsubscribed {
            print("✅ Unsubscribed from topic")
        }
        
        // Close the connection
        try await realtime.close()
        print("✅ Disconnected from Realtime service")
        
        print("\n✅ History Test completed")
    }
} 