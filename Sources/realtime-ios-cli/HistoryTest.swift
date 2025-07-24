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
            apiKey: APIKeys.API_KEY,
            secret: APIKeys.SECRET
        )
        
        // Prepare with production settings (staging: false)
        try realtime.prepare(staging: false, opts: ["debug": true])
        
        // Connect to the service
        try await realtime.connect()
        print("✅ Successfully connected to Realtime service")
        
        // Create a unique topic for testing
        let historyTopic = "history_test_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        print("\n📱 Using topic: \(historyTopic)")
        
        // Test 1: JSON Messages
        print("\n🧪 Test 1: Testing with JSON messages")
        let testMessages = [
            ["sender": "User1", "text": "First message", "timestamp": Date().description],
            ["sender": "User2", "text": "Second message", "timestamp": Date().description],
            ["sender": "User1", "text": "Third message", "timestamp": Date().description],
            ["sender": "User3", "text": "Fourth message", "timestamp": Date().description],
            ["sender": "User2", "text": "Fifth message", "timestamp": Date().description]
        ]
        
        print("\n📤 Sending JSON messages...")
        for message in testMessages {
            let success = try await realtime.publish(topic: historyTopic, message: message)
            if success {
                print("✅ Sent: \(message["text"] ?? "")")
            }
            // Add a small delay between messages
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        // Test 2: Simple Text Messages
        print("\n🧪 Test 2: Testing with simple text messages")
        let textMessages = [
            "Hello, this is a simple text message",
            "Another text message for testing",
            "Testing history with plain text",
            "Simple message number four",
            "Final text message for testing"
        ]
        
        print("\n📤 Sending text messages...")
        for message in textMessages {
            let success = try await realtime.publish(topic: historyTopic, message: message)
            if success {
                print("✅ Sent: \(message)")
            }
            // Add a small delay between messages
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        // Wait for messages to be processed
        print("\n⏳ Waiting for messages to be processed...")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Test 3: Get all messages
        print("\n🧪 Test 3: Getting all messages")
        let startDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let allMessages = try await realtime.history(topic: historyTopic, start: startDate)
        print("✅ Retrieved \(allMessages.count) messages")
        
        // Print the messages
        for (index, message) in allMessages.enumerated() {
            print("  Message \(index + 1):")
            if let messageDict = message as? [String: Any] {
                if let sender = messageDict["sender"] as? String {
                    print("    From: \(sender)")
                }
                if let text = messageDict["text"] as? String {
                    print("    Text: \(text)")
                }
                if let timestamp = messageDict["timestamp"] as? String {
                    print("    Time: \(timestamp)")
                }
            } else if let text = message as? String {
                print("    Text: \(text)")
            }
        }
        
        // Test 4: Get messages with limit
        print("\n🧪 Test 4: Getting messages with limit")
        let limitedMessages = try await realtime.history(topic: historyTopic, start: startDate, limit: 5)
        print("✅ Retrieved \(limitedMessages.count) messages with limit")
        
        // Print the limited messages
        for (index, message) in limitedMessages.enumerated() {
            print("  Limited Message \(index + 1):")
            if let messageDict = message as? [String: Any] {
                if let sender = messageDict["sender"] as? String {
                    print("    From: \(sender)")
                }
                if let text = messageDict["text"] as? String {
                    print("    Text: \(text)")
                }
                if let timestamp = messageDict["timestamp"] as? String {
                    print("    Time: \(timestamp)")
                }
            } else if let text = message as? String {
                print("    Text: \(text)")
            }
        }
        
        // Test 5: Get messages within a time range
        print("\n🧪 Test 5: Getting messages within a time range")
        // Use a more recent start date to ensure we get messages
        let recentStartDate = Calendar.current.date(byAdding: .minute, value: -5, to: Date())!
        let endDate = Date()
        let rangeMessages = try await realtime.history(topic: historyTopic, start: recentStartDate, end: endDate)
        print("✅ Retrieved \(rangeMessages.count) messages within time range")
        
        // Print the range messages
        for (index, message) in rangeMessages.enumerated() {
            print("  Range Message \(index + 1):")
            if let messageDict = message as? [String: Any] {
                if let sender = messageDict["sender"] as? String {
                    print("    From: \(sender)")
                }
                if let text = messageDict["text"] as? String {
                    print("    Text: \(text)")
                }
                if let timestamp = messageDict["timestamp"] as? String {
                    print("    Time: \(timestamp)")
                }
            } else if let text = message as? String {
                print("    Text: \(text)")
            }
        }
        
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
