import Foundation
import Realtime

/// Test class for verifying SystemEvent functionality
@available(iOS 15.0, *)
public struct SystemEventTest {
    public static func main() async throws {
        print("\n🔄 Running System Event Test...")

        // Initialize Realtime
        let realtime = try Realtime(
            apiKey: APIKeys.API_KEY,
            secret: APIKeys.SECRET
        )

        // Configure with staging environment and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])
        print("✅ Realtime initialized and prepared")

        // Set up listeners for all system events
        print("\nSetting up system event listeners...")

        // Connected Event Listener
        let connectedListener = TestMessageListenerSystem(name: SystemEvent.connected.rawValue) { _ in
            print("System Event: \(SystemEvent.connected.rawValue)")
        }
        try await realtime.on(topic: SystemEvent.connected.rawValue, listener: connectedListener)

        // Disconnected Event Listener
        let disconnectedListener = TestMessageListenerSystem(name: SystemEvent.disconnected.rawValue) { _ in
            print("System Event: \(SystemEvent.disconnected.rawValue)")
        }
        try await realtime.on(
            topic: SystemEvent.disconnected.rawValue, listener: disconnectedListener)

        // Reconnecting Event Listener
        let reconnectingListener = TestMessageListenerSystem(name: SystemEvent.reconnecting.rawValue) { _ in
            print("System Event: \(SystemEvent.reconnecting.rawValue)")
        }
        try await realtime.on(
            topic: SystemEvent.reconnecting.rawValue, listener: reconnectingListener)

        // Reconnected Event Listener
        let reconnectedListener = TestMessageListenerSystem(name: SystemEvent.reconnected.rawValue) { _ in
            print("System Event: \(SystemEvent.reconnected.rawValue)")
        }
        try await realtime.on(
            topic: SystemEvent.reconnected.rawValue, listener: reconnectedListener)

        // Message Resend Event Listener
        let messageResendListener = TestMessageListener(name: SystemEvent.messageResend.rawValue) { message in
            if let count = message as? Int {
                print("System Event: Resending \(count) messages")
            }
        }
        try await realtime.on(
            topic: SystemEvent.messageResend.rawValue, listener: messageResendListener)

        print("✅ All system event listeners set up")

        // Test 1: Initial Connection
        print("\n🧪 Test 1: Testing initial connection...")
        try await realtime.connect()
        print("Initial connection successful")

        // Test 2: Offline Message Storage
        print("\n🧪 Test 2: Testing offline message storage...")
        try await realtime.close()
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Store messages while offline
        _ = try await realtime.publish(topic: "test_offline", message: "Offline message 1")
        _ = try await realtime.publish(topic: "test_offline", message: "Offline message 2")
        _ = try await realtime.publish(topic: "test_offline", message: "Offline message 3")

        // Test 3: Reconnection and Message Resend
        print("\n🧪 Test 3: Testing reconnection and message resend...")
        try await realtime.connect()
        try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

        // Test 4: Integer Message Publishing
        print("\n🧪 Test 4: Testing integer message publishing...")
        let integerListener = TestMessageListenerSystem(name: "Integer") { message in
            print("\n🔢 Integer Message Event:")
            print("  Time: \(Date().formatted())")
            print("  Details: \(message)")
        }
        try await realtime.on(topic: "test_integer", listener: integerListener)

        _ = try await realtime.publish(topic: "test_integer", message: NSNumber(value: 42))
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Test 5: Topic Validation
        print("\n🧪 Test 5: Testing system topic validation...")
        do {
            _ = try await realtime.publish(topic: SystemEvent.connected.rawValue, message: "test")
            print("❌ Test failed: Publishing to system topic should not be allowed")
        } catch {
            print("✅ Test passed: Successfully prevented publishing to system topic (this is expected)")
        }

        // Test message publishing while connected
        _ = try await realtime.publish(topic: "test_system", message: "Online message")
        print("Published message while online")

        // Simulate offline scenario
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Test cleanup
        print("\nCleaning up...")
        try await realtime.close()
        print("Test completed - disconnected from NATS")

        print("\n✅ System Event Test completed")
    }
}

class TestMessageListenerSystem: MessageListener {
    let name: String
    let onMessageCallback: (Any) -> Void

    init(name: String, onMessage: @escaping (Any) -> Void) {
        self.name = name
        self.onMessageCallback = onMessage
    }

    func onMessage(_ message: Any) {
        onMessageCallback(message)
    }
}
