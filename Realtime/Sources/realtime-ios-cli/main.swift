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
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    func onMessage(_ message: [String: Any]) {
        print("\n📨 [\(name)] Received message via listener:")
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
        
        // Initialize two Realtime instances with debug mode enabled
        print("\nInitializing two Realtime instances...")
        let realtime1 = try Realtime(staging: false, opts: ["debug": true])
        let realtime2 = try Realtime(staging: false, opts: ["debug": true])
        
        // Set authentication for both instances
        print("\nSetting up authentication...")
        try realtime1.setAuth(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        try realtime2.setAuth(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        print("\nConnecting to NATS server...")
        print("🔄 Instance 1: Connecting and retrieving namespace...")
        try await realtime1.connect()
        
        print("🔄 Instance 2: Connecting and retrieving namespace...")
        try await realtime2.connect()
        print("Both instances connected successfully")
        
        // Create a test stream
        print("\nCreating test stream...")
        try await realtime1.createStream(name: "test_stream", subjects: ["test.*"])
        print("Stream created successfully")
        
        // Set up message listeners
        print("\nSetting up message listeners...")
        let listener1 = TestMessageListener(name: "Instance 1")
        let listener2 = TestMessageListener(name: "Instance 2")
        
        // Add SDK topic listeners
        print("\nSetting up SDK topic listeners...")
        let connectedListener = TestMessageListener(name: "Connected Event")
        let disconnectedListener = TestMessageListener(name: "Disconnected Event")
        let reconnectingListener = TestMessageListener(name: "Reconnecting Event")
        let reconnectedListener = TestMessageListener(name: "Reconnected Event")
        
        try await realtime1.on(topic: SDKTopic.CONNECTED, listener: connectedListener)
        try await realtime1.on(topic: SDKTopic.DISCONNECTED, listener: disconnectedListener)
        try await realtime1.on(topic: SDKTopic.RECONNECTING, listener: reconnectingListener)
        try await realtime1.on(topic: SDKTopic.RECONNECTED, listener: reconnectedListener)
        
        try await realtime1.on(topic: "test.room1", listener: listener1)
        try await realtime2.on(topic: "test.room1", listener: listener2)
        print("Message listeners set up successfully")
        
        // Test bidirectional communication
        print("\n🔄 Testing bidirectional communication...")
        
        // Instance 1 sends a message
        print("\n📤 Instance 1 sending message...")
        let message1: [String: Any] = [
            "type": "text",
            "content": "Hello from Instance 1!",
            "timestamp": Date().timeIntervalSince1970
        ]
        let result1 = try await realtime1.publish(topic: "test.room1", message: message1)
        if result1 {
            print("✅ Instance 1 message sent")
        }
        
        // Wait a bit
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Instance 2 sends a message
        print("\n📤 Instance 2 sending message...")
        let message2: [String: Any] = [
            "type": "text",
            "content": "Hello from Instance 2!",
            "timestamp": Date().timeIntervalSince1970
        ]
        let result2 = try await realtime2.publish(topic: "test.room1", message: message2)
        if result2 {
            print("✅ Instance 2 message sent")
        }
        
        // Wait for messages to be processed
        print("\n⏳ Waiting for messages to be processed (5 seconds)...")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Test unsubscribing
        print("\n🧪 Testing unsubscribe functionality...")
        
        // Unsubscribe Instance 1 from the topic
        print("\nUnsubscribing Instance 1 from topic...")
        let unsubscribed = try await realtime1.off(topic: "test.room1")
        if unsubscribed {
            print("✅ Instance 1 successfully unsubscribed")
        } else {
            print("❌ Instance 1 failed to unsubscribe")
        }
        
        // Send another message from Instance 2
        print("\n📤 Instance 2 sending another message after unsubscribe...")
        let message3: [String: Any] = [
            "type": "text",
            "content": "This message should not be received by Instance 1!",
            "timestamp": Date().timeIntervalSince1970
        ]
        let result3 = try await realtime2.publish(topic: "test.room1", message: message3)
        if result3 {
            print("✅ Instance 2 message sent")
        }
        
        // Wait to see if Instance 1 receives the message (it shouldn't)
        print("\n⏳ Waiting to verify no messages received after unsubscribe (3 seconds)...")
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Test history functionality
        print("\n🧪 Testing history functionality...")
        
        // Get messages from the last 5 minutes
        let startDate = Date().addingTimeInterval(-300) // 5 minutes ago
        print("\n📜 Retrieving messages from the last 5 minutes...")
        let messages = try await realtime2.history(topic: "test.room1", startDate: startDate)
        
        print("\n📋 Retrieved \(messages.count) messages:")
        for (index, message) in messages.enumerated() {
            print("\nMessage \(index + 1):")
            if let content = message["message"] as? [String: Any] {
                print("   Content: \(content)")
            }
            if let clientId = message["client_id"] {
                print("   From: \(clientId)")
            }
            if let timestamp = message["start"] {
                print("   Timestamp: \(timestamp)")
            }
        }
        
        // Clean up
        print("\nDisconnecting...")
        try await realtime1.disconnect()
        try await realtime2.disconnect()
        print("Disconnected successfully")
    }
}

// Run the main function
try await RealtimeCLI.main()

// try await RealtimeStorageTest.run()
 
