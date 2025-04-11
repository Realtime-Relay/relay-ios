import Foundation
import Realtime

struct RealtimeCLI {
    static func main() async throws {
        print("\n=== Testing Realtime Publish ===")
        
        // Initialize Realtime with production credentials
        let realtime = try Realtime(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        // Configure for production and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])
        
        // Connect to NATS
        print("\n🔄 Connecting to NATS...")
        try await realtime.connect()
        
        // Test stream management
        print("\n=== Testing Stream Management ===")
        
        // Test 1: Publish to a new topic (should create stream)
        print("\nTest 1: Publishing to new topic")
        let topic1 = "test.stream1"
        let success1 = try await realtime.publish(topic: topic1, message: "First message")
        print("✅ Published to new topic: \(success1 ? "Success" : "Failed")")
        
        // Test 2: Publish to same topic again (should use cache)
        print("\nTest 2: Publishing to same topic")
        let success2 = try await realtime.publish(topic: topic1, message: "Second message")
        print("✅ Published to same topic: \(success2 ? "Success" : "Failed")")
        
        // Test 3: Publish to another new topic
        print("\nTest 3: Publishing to another new topic")
        let topic2 = "test.stream2"
        let success3 = try await realtime.publish(topic: topic2, message: "Third message")
        print("✅ Published to new topic: \(success3 ? "Success" : "Failed")")
        
        // Test 4: Publish while disconnected
        print("\nTest 4: Publishing while disconnected")
        try await realtime.disconnect()
        let success4 = try await realtime.publish(topic: topic1, message: "Offline message")
        print("Offline publish result: \(success4 ? "✅ Success (stored locally)" : "❌ Failed")")
        
        // Test 5: Reconnect and verify stream persistence
        print("\nTest 5: Reconnecting and verifying stream persistence")
        try await realtime.connect()
        let success5 = try await realtime.publish(topic: topic1, message: "Post-reconnect message")
        print("Post-reconnect publish result: \(success5 ? "✅ Success" : "❌ Failed")")
        
        // Test 6: Publish to multiple topics
        print("\nTest 6: Publishing to multiple topics")
        let topics = ["test.stream3", "test.stream4", "test.stream5"]
        var allSuccess = true
        for topic in topics {
            let success = try await realtime.publish(topic: topic, message: "Multi-topic test")
            print("  \(topic): \(success ? "✅ Success" : "❌ Failed")")
            allSuccess = allSuccess && success
        }
        print("Multiple topic publish result: \(allSuccess ? "✅ All successful" : "❌ Some failed")")
        
        // Test 7: History Retrieval
        print("\n=== Testing History Retrieval ===")
        
        // Test 7.1: Get all messages from the last hour
        print("\nTest 7.1: Retrieving messages from last hour")
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let messages1 = try await realtime.history(topic: "test.stream1", startDate: oneHourAgo)
        print("Retrieved \(messages1.count) messages from last hour")
        for message in messages1 {
            print("  Message: \(message["message"] ?? "none")")
            print("  Timestamp: \(message["start"] ?? "none")")
        }
        print("History retrieval result: \(messages1.count > 0 ? "✅ Success" : "❌ No messages found")")
        
        // Test 7.2: Get messages with specific time range
        print("\nTest 7.2: Retrieving messages with time range")
        
        // First publish some test messages
        print("Publishing test messages...")
        let testMessages = [
            "Time range test message 1",
            "Time range test message 2",
            "Time range test message 3"
        ]
        
        for (index, message) in testMessages.enumerated() {
            let success = try await realtime.publish(topic: topic1, message: message)
            print("  Published message \(index + 1): \(success ? "✅ Success" : "❌ Failed")")
            // Small delay between messages
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Wait a moment to ensure messages are processed
        print("Waiting for messages to be processed...")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Now retrieve messages from the last 2 minutes
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let messages2 = try await realtime.history(topic: topic1, startDate: twoMinutesAgo, endDate: Date())
        print("\nRetrieved \(messages2.count) messages from last 2 minutes")
        for message in messages2 {
            print("  Message: \(message["message"] ?? "none")")
            print("  Timestamp: \(message["start"] ?? "none")")
        }
        print("Time range history result: \(messages2.count > 0 ? "✅ Success" : "❌ No messages found")")
        
        // Test 7.3: Get history from non-existent topic
        print("\nTest 7.3: Retrieving history from non-existent topic")
        let messages3 = try await realtime.history(topic: "non.existent.topic", startDate: oneHourAgo)
        print("Retrieved \(messages3.count) messages from non-existent topic")
        print("Non-existent topic result: \(messages3.isEmpty ? "✅ Success (empty as expected)" : "❌ Unexpected messages found")")
        
        // Test 7.4: Get history with invalid date range
        print("\nTest 7.4: Retrieving history with invalid date range")
        do {
            let futureDate = Date().addingTimeInterval(3600)
            _ = try await realtime.history(topic: "test.stream1", startDate: futureDate, endDate: Date())
            print("❌ Invalid date range test failed (should have thrown error)")
        } catch {
            print("✅ Invalid date range test passed (error thrown as expected)")
        }
        
        // Clean up
        print("\n🧹 Cleaning up...")
        try await realtime.disconnect()
        
        print("\n✅ All tests completed")
    }
}

// Run the tests
Task {
    do {
        try await RealtimeCLI.main()
    } catch {
        print("❌ Error running tests: \(error)")
    }
    exit(0)
}

// Keep the main thread running
RunLoop.main.run()
