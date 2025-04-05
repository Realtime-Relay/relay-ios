//
//  main.swift
//  Realtime
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation
import Realtime

// Message listener implementation
class TestMessageListener: MessageListener {
    func onMessage(_ message: [String: Any]) {
        print("\n📨 Received message via listener:")
        if let messageContent = message["message"] {
            print("   Content: \(messageContent)")
        }
        if let clientId = message["client_id"] {
            print("   From: \(clientId)")
        }
        if let timestamp = message["start"] {
            print("   Timestamp: \(timestamp)")
        }
    }
}

struct RealtimeCLI {
    static func main() async throws {
        print("🧪 Starting Realtime Test...")
        
        // Initialize Realtime with debug mode enabled
        let realtime = try Realtime(staging: false, opts: ["debug": true])
        
        // Set authentication
        try await realtime.setAuth(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        print("\nConnecting to NATS server...")
        try await realtime.connect()
        print("Connected successfully")
        
        // Create a test stream
        print("\nCreating test stream...")
        try await realtime.createStream(name: "test_stream", subjects: ["test.*"])
        print("Stream created successfully")
        
        // Set up message listener
        print("\nSetting up message listener...")
        let listener = TestMessageListener()
        try await realtime.on(topic: "test.room1", listener: listener)
        print("Message listener set up successfully")
        
        // Publish test messages
        print("\nPublishing test messages...")
        
        // Test 1: Simple text message
        print("\nTest 1: Publishing simple text message...")
        let textMessage: [String: Any] = [
            "type": "text",
            "content": "Hello from JetStream!",
            "timestamp": Date().timeIntervalSince1970
        ]
        let publishResult1 = try await realtime.publish(topic: "test.room1", message: textMessage)
        if publishResult1 {
            print("✅ Text message published successfully")
        }
        
        // Test 2: Complex object
        print("\nTest 2: Publishing complex object...")
        let complexMessage: [String: Any] = [
            "type": "complex",
            "data": [
                "id": UUID().uuidString,
                "name": "Test Object",
                "values": [1, 2, 3, 4, 5],
                "nested": [
                    "field1": "value1",
                    "field2": 42
                ]
            ],
            "timestamp": Date().timeIntervalSince1970
        ]
        let publishResult2 = try await realtime.publish(topic: "test.room1", message: complexMessage)
        if publishResult2 {
            print("✅ Complex object published successfully")
        }
        
        // Test 3: Multiple messages in quick succession
        print("\nTest 3: Publishing multiple messages...")
        for i in 1...3 {
            let quickMessage: [String: Any] = [
                "type": "quick",
                "content": "Quick message \(i)",
                "timestamp": Date().timeIntervalSince1970
            ]
            let result = try await realtime.publish(topic: "test.room1", message: quickMessage)
            if result {
                print("✅ Quick message \(i) published successfully")
            }
            // Small delay between messages
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Wait for messages to be received
        print("\nWaiting for messages (30 seconds)...")
        try await Task.sleep(nanoseconds: 30_000_000_000)
        
        // Clean up
        print("\nDisconnecting...")
        try await realtime.disconnect()
        print("Disconnected successfully")
    }
}

// Run the main function
//try await RealtimeCLI.main()

