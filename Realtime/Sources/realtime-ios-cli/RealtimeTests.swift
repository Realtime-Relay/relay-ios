import Foundation
import Realtime

public class RealtimeTests {
    private let realtime: Realtime
    private var isDebug: Bool = true

    public init(apiKey: String, secret: String) throws {
        self.realtime = try Realtime(apiKey: apiKey, secret: secret)
    }

    public func runAllTests() async throws {
        print("\n=== Testing Realtime SDK Stream Management ===")

        // Configure and connect
        try await setupAndConnect()

        // Run individual tests
        try await testStreamCreation()
        try await testStreamExistence()
        try await testStreamUpdate()
        try await testMultipleTopics()
        try await testStreamReuse()
        try await testStreamRecovery()
        try await testMessageHistory()
        try await testOfflineMessageHandling()
        try await testPublishAndSubscribe()

        // Clean up
        try await cleanup()
    }

    private func setupAndConnect() async throws {
        // Configure for production and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])

        print("\n🔄 Connecting to NATS...")
        try await realtime.connect()
        print("✅ Connected to NATS server")
    }

    private func testStreamCreation() async throws {
        print("\n🧪 Test 1: Stream Creation")
        print("Testing stream creation with new topic...")
        let testTopic =
            "test_stream_creation_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        _ = try await realtime.publish(topic: testTopic, message: ["test": "stream_creation"])
        print("✅ Stream creation test completed")
    }

    private func testStreamExistence() async throws {
        print("\n🧪 Test 2: Stream Existence Check")
        print("Checking if stream exists for the same topic...")
        let testTopic =
            "test_stream_exists_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        _ = try await realtime.publish(topic: testTopic, message: ["test": "stream_exists"])
        _ = try await realtime.publish(topic: testTopic, message: ["test": "stream_exists_again"])
        print("✅ Stream existence check completed")
    }

    private func testStreamUpdate() async throws {
        print("\n🧪 Test 3: Stream Update")
        print("Testing stream update with new subject...")
        let testTopic =
            "test_stream_update_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        _ = try await realtime.publish(topic: testTopic, message: ["test": "stream_update"])
        print("✅ Stream update test completed")
    }

    private func testMultipleTopics() async throws {
        print("\n🧪 Test 4: Multiple Topics in Same Stream")
        print("Testing multiple topics in the same stream...")
        let topics = [
            "test_multi_1_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))",
            "test_multi_2_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))",
            "test_multi_3_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))",
        ]

        for topic in topics {
            _ = try await realtime.publish(topic: topic, message: ["test": "multi_topic"])
            print("✅ Added topic: \(topic)")
        }
        print("✅ Multiple topics test completed")
    }

    private func testStreamReuse() async throws {
        print("\n🧪 Test 5: Stream Reuse")
        print("Testing stream reuse with existing topics...")
        let testTopic =
            "test_stream_reuse_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        _ = try await realtime.publish(topic: testTopic, message: ["test": "first_message"])
        _ = try await realtime.publish(topic: testTopic, message: ["test": "second_message"])
        print("✅ Stream reuse test completed")
    }

    private func testStreamRecovery() async throws {
        print("\n🧪 Test 6: Stream Recovery After Disconnect")
        print("Testing stream recovery after disconnect...")

        // Disconnect
        try await realtime.close()
        print("✅ Disconnected from NATS")

        // Reconnect
        try await realtime.connect()
        print("✅ Reconnected to NATS")

        // Try to use stream after reconnection
        let testTopic =
            "test_recovery_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        _ = try await realtime.publish(topic: testTopic, message: ["test": "recovery_message"])
        print("✅ Stream recovery test completed")
    }

    private func testMessageHistory() async throws {
        print("\n🧪 Test 7: Message History")

        // Reconnect for history tests
        print("🔄 Reconnecting to NATS...")
        try await realtime.connect()
        print("✅ Reconnected to NATS")

        // First, publish some test messages
        print("\nPublishing test messages...")
        let testTopic = "test_history_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"

        // Record start time before publishing
        let testStartTime = Date().addingTimeInterval(-1)  // Start 1 second ago
        print("Test start time: \(testStartTime)")

        // Publish messages with different timestamps
        let messages = [
            ["content": "Message 1", "timestamp": Int(Date().timeIntervalSince1970)],
            ["content": "Message 2", "timestamp": Int(Date().timeIntervalSince1970) + 1],
            ["content": "Message 3", "timestamp": Int(Date().timeIntervalSince1970) + 2],
        ]

        for message in messages {
            let success = try await realtime.publish(topic: testTopic, message: message)
            if success {
                print("✅ Published message: \(message)")
            } else {
                print("❌ Failed to publish message: \(message)")
            }
            // Add a delay between messages
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }

        // Add a delay after publishing to ensure messages are stored
        print("Waiting for messages to be stored...")
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Test history with date range
        print("\nTesting history with date range...")
        let endDate = Date().addingTimeInterval(5)  // End 5 seconds in the future
        print("Start time: \(testStartTime)")
        print("End time: \(endDate)")

        let historyMessages = try await realtime.history(
            topic: testTopic,
            start: testStartTime,
            end: endDate,
            limit: 100
        )

        print("\nRetrieved \(historyMessages.count) messages:")
        for message in historyMessages {
            print("Message: \(message)")
        }
        print("✅ History test completed")
    }

    private func testOfflineMessageHandling() async throws {
        print("\n🧪 Test 8: Offline Message Handling")
        print("Testing offline message storage and resending...")

        // First, disconnect to simulate offline mode
        try await realtime.close()
        print("✅ Disconnected from NATS (offline mode)")

        // Create a test topic
        let testTopic = "test_offline_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"

        // Try to publish messages while offline
        print("\nAttempting to publish messages while offline...")
        let messages = [
            ["content": "Offline Message 1", "timestamp": Int(Date().timeIntervalSince1970)],
            ["content": "Offline Message 2", "timestamp": Int(Date().timeIntervalSince1970) + 1],
            ["content": "Offline Message 3", "timestamp": Int(Date().timeIntervalSince1970) + 2],
        ]

        for message in messages {
            let success = try await realtime.publish(topic: testTopic, message: message)
            if !success {
                print("✅ Message stored locally (offline): \(message)")
            } else {
                print("❌ Unexpected success while offline: \(message)")
            }
            // Add a delay between messages
            try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        }

        // Reconnect to NATS
        print("\n🔄 Reconnecting to NATS...")
        try await realtime.connect()
        print("✅ Reconnected to NATS")

        // Trigger message resending by publishing a new message
        print("\nTriggering message resending...")
        let triggerMessage: [String: Any] = [
            "content": "Trigger Message",
            "timestamp": Int(Date().timeIntervalSince1970),
        ]
        _ = try await realtime.publish(topic: testTopic, message: triggerMessage)

        // Wait for messages to be resent
        print("\nWaiting for stored messages to be resent...")
        try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

        // Verify messages were sent by checking history
        print("\nVerifying message delivery...")
        let startTime = Date().addingTimeInterval(-10)  // Check last 10 seconds
        let endTime = Date().addingTimeInterval(5)  // Include next 5 seconds

        let historyMessages = try await realtime.history(
            topic: testTopic,
            start: startTime,
            end: endTime,
            limit: 100
        )

        print("\nRetrieved \(historyMessages.count) messages from history:")
        for message in historyMessages {
            print("Message: \(message)")
        }

        if historyMessages.count >= messages.count {
            print("✅ Successfully resent all offline messages")
        } else {
            print(
                "❌ Some messages were not resent. Expected: \(messages.count), Got: \(historyMessages.count)"
            )
        }

        print("✅ Offline message handling test completed")
    }

    private func testPublishAndSubscribe() async throws {
        print("\n🧪 Test 9: Publish and Subscribe")
        print("Testing real-time message publishing and subscription...")

        let testTopic = "test_pubsub_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        var receivedMessages: [[String: Any]] = []

        // Create message listener
        class TestMessageListener: MessageListener {
            var messages: [[String: Any]]

            init(messages: [[String: Any]]) {
                self.messages = messages
            }

            func onMessage(_ message: [String: Any]) {
                print("📥 Received message: \(message)")
                messages.append(message)
            }
        }

        let messageListener = TestMessageListener(messages: receivedMessages)

        // Set up subscription
        print("\nSetting up subscription for topic: \(testTopic)")
        try await realtime.on(topic: testTopic, listener: messageListener)
        print("✅ Subscription established")

        // Publish test messages
        print("\nPublishing test messages...")
        let messages = [
            ["content": "PubSub Test 1", "timestamp": Int(Date().timeIntervalSince1970)],
            ["content": "PubSub Test 2", "timestamp": Int(Date().timeIntervalSince1970) + 1],
            ["content": "PubSub Test 3", "timestamp": Int(Date().timeIntervalSince1970) + 2],
        ]

        for message in messages {
            let success = try await realtime.publish(topic: testTopic, message: message)
            if success {
                print("📤 Published message: \(message)")
            } else {
                print("❌ Failed to publish message: \(message)")
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
        }

        // Wait for messages to be received
        print("\nWaiting for messages to be received...")
        try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

        // Verify received messages
        print("\nReceived \(messageListener.messages.count) messages:")
        for message in messageListener.messages {
            print("Message: \(message)")
        }

        // Cleanup subscription
        let unsubscribed = try await realtime.off(topic: testTopic)
        if unsubscribed {
            print("✅ Unsubscribed from topic")
        } else {
            print("⚠️ Topic was not subscribed")
        }

        print("✅ Publish and Subscribe test completed")
    }

    private func cleanup() async throws {
        print("\n🧹 Cleaning up...")
        try await realtime.close()
        print("✅ All tests completed successfully")
    }
}
