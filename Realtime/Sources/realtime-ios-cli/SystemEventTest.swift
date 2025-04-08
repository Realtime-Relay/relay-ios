import Foundation
import Realtime

/// Test class for verifying SystemEvent functionality
@available(iOS 15.0, *)
public struct SystemEventTest {
    public static func main() async throws {
        print("\n🔄 Running System Event Test...")
        
        // Initialize Realtime
        print("\nInitializing Realtime...")
        let realtime = try Realtime(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        // Configure with staging environment and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])
        print("✅ Realtime initialized and prepared")
        
        // Set up listeners for all system events
        print("\nSetting up system event listeners...")
        
        // Connected Event Listener
        let connectedListener = TestMessageListener(name: "Connected") { message in
            print("\n🟢 Connected Event:")
            print("  Time: \(Date().formatted())")
            if let clientId = message["client_id"] as? String {
                print("  Client ID: \(clientId)")
            }
            if let namespace = message["namespace"] as? String {
                print("  Namespace: \(namespace)")
            }
            print("  Raw Message: \(message)")
        }
        try await realtime.on(topic: SystemEvent.connected.rawValue, listener: connectedListener)
        
        // Disconnected Event Listener
        let disconnectedListener = TestMessageListener(name: "Disconnected") { message in
            print("\n🔴 Disconnected Event:")
            print("  Time: \(Date().formatted())")
            if let reason = message["reason"] as? String {
                print("  Reason: \(reason)")
            }
            if let clientId = message["client_id"] as? String {
                print("  Client ID: \(clientId)")
            }
            print("  Raw Message: \(message)")
        }
        try await realtime.on(topic: SystemEvent.disconnected.rawValue, listener: disconnectedListener)
        
        // Reconnecting Event Listener
        let reconnectingListener = TestMessageListener(name: "Reconnecting") { message in
            print("\n🔄 Reconnecting Event:")
            print("  Time: \(Date().formatted())")
            if let attempt = message["attempt"] as? Int {
                print("  Attempt: \(attempt)")
            }
            if let clientId = message["client_id"] as? String {
                print("  Client ID: \(clientId)")
            }
            print("  Raw Message: \(message)")
        }
        try await realtime.on(topic: SystemEvent.reconnecting.rawValue, listener: reconnectingListener)
        
        // Reconnected Event Listener
        let reconnectedListener = TestMessageListener(name: "Reconnected") { message in
            print("\n🟢 Reconnected Event:")
            print("  Time: \(Date().formatted())")
            if let clientId = message["client_id"] as? String {
                print("  Client ID: \(clientId)")
            }
            if let namespace = message["namespace"] as? String {
                print("  Namespace: \(namespace)")
            }
            print("  Raw Message: \(message)")
        }
        try await realtime.on(topic: SystemEvent.reconnected.rawValue, listener: reconnectedListener)
        
        // Message Resend Event Listener
        let messageResendListener = TestMessageListener(name: "Message Resend") { message in
            print("\n📤 Message Resend Event:")
            print("  Time: \(Date().formatted())")
            if let messages = message["messages"] as? [[String: Any]] {
                print("  Messages Count: \(messages.count)")
                for (index, msg) in messages.enumerated() {
                    print("  Message \(index + 1):")
                    if let topic = msg["topic"] as? String {
                        print("    Topic: \(topic)")
                    }
                    if let resent = msg["resent"] as? Bool {
                        print("    Resent: \(resent)")
                    }
                    if let messageContent = msg["message"] as? [String: Any] {
                        print("    Content: \(messageContent)")
                    }
                }
            }
            print("  Raw Message: \(message)")
        }
        try await realtime.on(topic: SystemEvent.messageResend.rawValue, listener: messageResendListener)
        
        print("✅ All system event listeners set up")
        
        // Test 1: Initial Connection
        print("\n🧪 Test 1: Testing initial connection...")
        try await realtime.connect()
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        
        // Test 2: Offline Message Storage and Resend
        print("\n🧪 Test 2: Testing offline message storage and resend...")
        // Simulate offline state by disconnecting
        try await realtime.disconnect()
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        
        // Try to publish while offline
        print("\nPublishing messages while offline...")
        for i in 1...3 {
            _ = try await realtime.publish(topic: "test.offline", message: [
                "type": "text",
                "content": "Offline message \(i)",
                "timestamp": Date().timeIntervalSince1970
            ])
        }
        
        // Reconnect to trigger message resend
        print("\nReconnecting to trigger message resend...")
        try await realtime.connect()
        try await Task.sleep(nanoseconds: 3_000_000_000) // Wait 3 seconds
        
        // Test 3: Reconnection Handling
        print("\n🧪 Test 3: Testing reconnection handling...")
        // Force disconnect and reconnect
        try await realtime.disconnect()
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        try await realtime.connect()
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        
        // Test 4: Topic Validation
        print("\n🧪 Test 4: Testing system topic validation...")
        do {
            _ = try await realtime.publish(topic: SystemEvent.connected.rawValue, message: "test")
            print("❌ Error: Should not be able to publish to system topic")
        } catch {
            print("✅ Successfully prevented publishing to system topic: systemTopicPublish")
        }
        
        // Cleanup
        print("\nCleaning up...")
        try await realtime.disconnect()
        
        print("\n✅ System Event Test completed")
    }
}

/// Helper class for testing message listeners with custom handling
class TestMessageListener: MessageListener {
    private let name: String
    private let handler: ([String: Any]) -> Void
    
    init(name: String, handler: @escaping ([String: Any]) -> Void = { _ in }) {
        self.name = name
        self.handler = handler
    }
    
    func onMessage(_ message: [String: Any]) {
        handler(message)
    }
} 
