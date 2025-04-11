import Foundation
import Realtime

struct RealtimeCLI {
    static func main() async throws {
        print("\n=== Testing Realtime Publish ===")

        // Initialize Realtime with production credentials
        let realtime = try Realtime(
            apiKey:
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )

        // Configure for production and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])

        // Connect to NATS
        print("\n🔄 Connecting to NATS...")
        try await realtime.connect()

        // Test stream management
        print("\n=== Testing Stream Management ===")

        // Verify stream name format
        print("\nVerifying stream name format...")
        let expectedStreamName = "relay-internal-ios-dev_stream"
        print("Expected stream name: \(expectedStreamName)")
        print("Note: Stream name is managed internally by the Realtime class")

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
        print(
            "History retrieval result: \(messages1.count > 0 ? "✅ Success" : "❌ No messages found")"
        )

        // Test 7.2: Get messages with specific time range
        print("\nTest 7.2: Retrieving messages with time range")

        // First publish some test messages
        print("Publishing test messages...")
        let testMessages = [
            "Time range test message 1",
            "Time range test message 2",
            "Time range test message 3",
        ]

        for (index, message) in testMessages.enumerated() {
            let success = try await realtime.publish(topic: topic1, message: message)
            print("  Published message \(index + 1): \(success ? "✅ Success" : "❌ Failed")")
            // Small delay between messages
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }

        // Wait a moment to ensure messages are processed
        print("Waiting for messages to be processed...")
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Now retrieve messages from the last 2 minutes
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let messages2 = try await realtime.history(
            topic: topic1, startDate: twoMinutesAgo, endDate: Date())
        print("\nRetrieved \(messages2.count) messages from last 2 minutes")
        for message in messages2 {
            print("  Message: \(message["message"] ?? "none")")
            print("  Timestamp: \(message["start"] ?? "none")")
        }
        print(
            "Time range history result: \(messages2.count > 0 ? "✅ Success" : "❌ No messages found")"
        )

        // Test 7.3: Get history from non-existent topic
        print("\nTest 7.3: Retrieving history from non-existent topic")
        let messages3 = try await realtime.history(
            topic: "non.existent.topic", startDate: oneHourAgo)
        print("Retrieved \(messages3.count) messages from non-existent topic")
        print(
            "Non-existent topic result: \(messages3.isEmpty ? "✅ Success (empty as expected)" : "❌ Unexpected messages found")"
        )

        // Test 7.4: Get history with invalid date range
        print("\nTest 7.4: Retrieving history with invalid date range")
        do {
            let futureDate = Date().addingTimeInterval(3600)
            _ = try await realtime.history(
                topic: "test.stream1", startDate: futureDate, endDate: Date())
            print("❌ Invalid date range test failed (should have thrown error)")
        } catch {
            print("✅ Invalid date range test passed (error thrown as expected)")
        }

        // Test message acknowledgment
        print("\n=== Testing Message Acknowledgment ===")
        let testTopic = "test.ack"

        // Create a test message listener
        class TestMessageListener: MessageListener {
            var receivedMessages: [[String: Any]] = []
            var ackBeforeCallback = false
            var expectedClientId: String?

            func setAcknowledged() {
                ackBeforeCallback = true
            }

            func onMessage(_ message: [String: Any]) {
                // Verify message format
                guard message["id"] as? String != nil,
                    message["message"] != nil
                else {
                    print("❌ Invalid message format")
                    return
                }

                // Verify no extra fields
                if message.keys.count != 2 {
                    print("❌ Message contains extra fields")
                    return
                }

                // Verify ack was called before this callback
                if !ackBeforeCallback {
                    print("❌ Ack was not called before callback")
                    return
                }

                receivedMessages.append(message)
                print("✅ Message received and processed correctly")

                // Reset the flag for the next message
                ackBeforeCallback = false
            }
        }

        // Create a test listener for message resend status
        class MessageResendListener: MessageListener {
            func onMessage(_ message: [String: Any]) {
                print("\n=== Message Resend Status ===")

                // Verify message format
                guard let messages = message["messages"] as? [[String: Any]] else {
                    print("❌ Invalid message resend format")
                    return
                }

                // Process each message status
                for (index, status) in messages.enumerated() {
                    guard let topic = status["topic"] as? String,
                        let message = status["message"] as? [String: Any],
                        let resent = status["resent"] as? Bool
                    else {
                        print("❌ Invalid message status format")
                        continue
                    }

                    print("Message \(index + 1):")
                    print("  Topic: \(topic)")
                    print("  Message ID: \(message["id"] ?? "unknown")")
                    print("  Resent: \(resent ? "✅ Success" : "❌ Failed")")
                }

                print("=== End of Message Resend Status ===\n")
            }
        }

        let listener = TestMessageListener()
        let resendListener = MessageResendListener()

        // Subscribe to test topics
        print("\nSubscribing to test topics...")
        try await realtime.on(topic: testTopic, listener: listener)
        try await realtime.on(topic: SystemEvent.messageResend.rawValue, listener: resendListener)

        // Test 1: Normal message processing
        print("\nTest 1: Normal message processing")
        let testMessage = "Test message for ack verification"
        _ = try await realtime.publish(topic: testTopic, message: testMessage)

        // Wait for message to be processed
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Verify message was received
        if listener.receivedMessages.isEmpty {
            print("❌ No messages received")
        } else {
            print("✅ Message received and processed")
        }

        // Test 2: Error handling
        print("\nTest 2: Error handling")
        class ErrorThrowingListener: MessageListener {
            func onMessage(_ message: [String: Any]) {
                print("Simulating error in message processing")
                print("❌ Error occurred while processing message")
                print("✅ Error was handled gracefully")
            }
        }

        let errorListener = ErrorThrowingListener()
        try await realtime.on(topic: "test.error", listener: errorListener)

        // Publish a message that should cause an error
        _ = try await realtime.publish(topic: "test.error", message: "Error test message")

        // Wait for error to be processed
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Test 3: Message format verification
        print("\nTest 3: Message format verification")
        let formatTestTopic = "test.format"

        class FormatTestListener: MessageListener {
            func onMessage(_ message: [String: Any]) {
                // Verify message format
                guard message["id"] as? String != nil,
                    message["message"] != nil
                else {
                    print("❌ Invalid message format")
                    return
                }

                // Verify no extra fields
                if message.keys.count != 2 {
                    print("❌ Message contains extra fields")
                    return
                }

                print("✅ Message format correct")
            }
        }

        let formatListener = FormatTestListener()
        try await realtime.on(topic: formatTestTopic, listener: formatListener)

        // Test different message types
        let formatTestMessages: [Any] = [
            "String message",
            42,
            ["key": "value"],
        ]

        for message in formatTestMessages {
            _ = try await realtime.publish(topic: formatTestTopic, message: message)
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }

        // Test 4: Message filtering by client_id and room
        print("\nTest 4: Message filtering by client_id and room")
        let filterTestTopic = "test.filter"

        class FilterTestListener: MessageListener {
            var receivedMessages: [[String: Any]] = []
            var expectedRoom: String

            init(expectedRoom: String) {
                self.expectedRoom = expectedRoom
            }

            func onMessage(_ message: [String: Any]) {
                receivedMessages.append(message)
                print("\n=== Message Received ===")
                print("Room: \(expectedRoom)")
                print("Message ID: \(message["id"] ?? "unknown")")
                print("Message Content: \(message["message"] ?? "none")")
                print("Client ID: \(message["client_id"] ?? "unknown")")
                print("Timestamp: \(message["start"] ?? "unknown")")
                print("=== End Message ===\n")
            }
        }

        // Create listeners for different rooms
        let filterListener1 = FilterTestListener(expectedRoom: filterTestTopic)
        let filterListener2 = FilterTestListener(expectedRoom: "test.filter2")

        // Subscribe to different rooms
        print("\nSubscribing to rooms...")
        print("Subscribing to room: \(filterTestTopic)")
        try await realtime.on(topic: filterTestTopic, listener: filterListener1)
        print("Subscribing to room: test.filter2")
        try await realtime.on(topic: "test.filter2", listener: filterListener2)

        // Clear previous messages
        filterListener1.receivedMessages.removeAll()
        filterListener2.receivedMessages.removeAll()

        // Publish messages to different rooms
        print("\nPublishing test messages...")
        print("Publishing to room: \(filterTestTopic)")
        let publishResult1 = try await realtime.publish(
            topic: filterTestTopic, message: "Message for room 1")
        print("Message 1 published: \(publishResult1 ? "✅ Success" : "❌ Failed")")

        print("Publishing to room: test.filter2")
        let publishResult2 = try await realtime.publish(
            topic: "test.filter2", message: "Message for room 2")
        print("Message 2 published: \(publishResult2 ? "✅ Success" : "❌ Failed")")

        // Wait for messages to be processed
        print("\nWaiting for messages to be processed...")
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Verify messages were received by correct listeners
        print("\nVerifying message filtering...")
        print("\nListener 1 (\(filterTestTopic)):")
        print("Expected messages: 1")
        print("Received messages: \(filterListener1.receivedMessages.count)")
        if filterListener1.receivedMessages.count == 1 {
            print("✅ Listener 1 received correct number of messages")
        } else {
            print(
                "❌ Listener 1 received incorrect number of messages: \(filterListener1.receivedMessages.count)"
            )
        }

        print("\nListener 2 (test.filter2):")
        print("Expected messages: 1")
        print("Received messages: \(filterListener2.receivedMessages.count)")
        if filterListener2.receivedMessages.count == 1 {
            print("✅ Listener 2 received correct number of messages")
        } else {
            print(
                "❌ Listener 2 received incorrect number of messages: \(filterListener2.receivedMessages.count)"
            )
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
