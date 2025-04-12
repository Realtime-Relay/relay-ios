import Foundation
import Realtime

class PublishTests {
    private let realtime: Realtime
    private let isDebug: Bool
    private var receivedMessages: [[String: Any]] = []
    private var testTopic: String = "test_publish_\(UUID().uuidString)"
    private var messageExpectation: (() -> Void)?
    private var expectations: [String: (() -> Void)] = [:]

    init(apiKey: String, secret: String, isDebug: Bool = true) throws {
        self.realtime = try Realtime(apiKey: apiKey, secret: secret)
        self.isDebug = isDebug
    }

    func runAllTests() async throws {
        print("\n🧪 Testing Publish and On Methods")

        // Ensure we're starting with a fresh connection
        try await realtime.close()
        try await Task.sleep(nanoseconds: 1_000_000_000)  // Wait for disconnect

        // Connect to NATS with retry logic
        var connectionAttempts = 0
        let maxAttempts = 3

        while connectionAttempts < maxAttempts {
            do {
                try await realtime.connect()
                try await Task.sleep(nanoseconds: 2_000_000_000)  // Wait for connection to stabilize
                break
            } catch {
                connectionAttempts += 1
                if connectionAttempts == maxAttempts {
                    throw error
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)  // Wait before retry
            }
        }

        // Test 1: Basic Publish and On
        try await testBasicPublishAndOn()

        // Test 2: Multiple Messages
        try await testMultipleMessages()

        // Test 3: Offline Publishing
        try await testOfflinePublishing()

        print("\n✅ All publish tests completed successfully")
    }

    private func testBasicPublishAndOn() async throws {
        print("\n🧪 Test 1: Basic Publish and On")

        // Create a listener
        let listener = TestMessageListener(name: "BasicListener") { [weak self] message in
            self?.receivedMessages.append(message)
            self?.messageExpectation?()
        }

        // Subscribe to the topic
        try await realtime.on(topic: testTopic, listener: listener)

        // Wait for subscription to be established
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Set up message expectation
        let messageExpectation = { [weak self] in
            print("Message received")
            self?.expectations["message"]?()
        }
        self.messageExpectation = messageExpectation
        expectations["message"] = { print("Message received") }

        // Publish a test message
        let testMessage: [String: Any] = [
            "content": "Test message",
            "timestamp": Int(Date().timeIntervalSince1970),
        ]
        _ = try await realtime.publish(topic: testTopic, message: testMessage)

        // Wait for message to be received
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Verify message was received
        guard !receivedMessages.isEmpty else {
            throw RelayError.invalidListener("No messages received")
        }

        if isDebug {
            print("✅ Message received: \(receivedMessages.last ?? [:])")
        }
    }

    private func testMultipleMessages() async throws {
        print("\n🧪 Test 2: Multiple Messages")

        // Clear previous messages
        receivedMessages.removeAll()

        // Publish multiple messages
        let messages = [
            ["content": "Message 1", "timestamp": Int(Date().timeIntervalSince1970)],
            ["content": "Message 2", "timestamp": Int(Date().timeIntervalSince1970)],
            ["content": "Message 3", "timestamp": Int(Date().timeIntervalSince1970)],
        ]

        for message in messages {
            _ = try await realtime.publish(topic: testTopic, message: message)
            try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds between messages
        }

        // Wait for all messages to be received
        try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

        // Verify all messages were received
        guard receivedMessages.count == messages.count else {
            throw RelayError.invalidListener(
                "Expected \(messages.count) messages, received \(receivedMessages.count)")
        }

        if isDebug {
            print("✅ All messages received: \(receivedMessages)")
        }
    }

    private func testOfflinePublishing() async throws {
        print("\n🧪 Test 3: Offline Publishing")

        // Clear previous messages
        receivedMessages.removeAll()

        // Disconnect
        try await realtime.close()
        try await Task.sleep(nanoseconds: 1_000_000_000)  // Wait for disconnect

        // Publish messages while offline
        let offlineMessages = [
            ["content": "Offline Message 1", "timestamp": Int(Date().timeIntervalSince1970)],
            ["content": "Offline Message 2", "timestamp": Int(Date().timeIntervalSince1970)],
        ]

        for message in offlineMessages {
            _ = try await realtime.publish(topic: testTopic, message: message)
        }

        // Reconnect
        try await realtime.connect()
        try await Task.sleep(nanoseconds: 2_000_000_000)  // Wait for connection to stabilize

        // Publish a trigger message to initiate resend
        let triggerMessage: [String: Any] = [
            "content": "Trigger Message",
            "timestamp": Int(Date().timeIntervalSince1970),
        ]
        _ = try await realtime.publish(topic: testTopic, message: triggerMessage)

        // Wait for messages to be resent and received
        try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

        // Verify all messages were received
        guard receivedMessages.count >= offlineMessages.count else {
            throw RelayError.invalidListener(
                "Expected at least \(offlineMessages.count) messages, received \(receivedMessages.count)"
            )
        }

        if isDebug {
            print("✅ Offline messages received: \(receivedMessages)")
        }
    }
}

// Helper class for message listening
class TestMessageListener: MessageListener {
    let name: String
    let onMessageCallback: ([String: Any]) -> Void

    init(name: String, onMessage: @escaping ([String: Any]) -> Void) {
        self.name = name
        self.onMessageCallback = onMessage
    }

    func onMessage(_ message: [String: Any]) {
        onMessageCallback(message)
    }
}
