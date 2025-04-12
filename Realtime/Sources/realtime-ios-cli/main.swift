import Foundation
import Realtime

// Create a status listener
class StatusListener: MessageListener {
    func onMessage(_ message: [String: Any]) {
        print("\n📡 Status Update:")
        if let status = message["message"] as? [String: Any],
            let statusType = status["status"] as? String
        {
            switch statusType {
            case "connected":
                print("   ✅ Connected to server")
                print("   Namespace: \(status["namespace"] ?? "unknown")")
            case "disconnected":
                print("   ❌ Disconnected from server")
            case "reconnecting":
                print("   🔄 Reconnecting to server...")
            case "reconnected":
                print("   ✅ Reconnected to server")
            case "messageResend":
                print("   📤 Resending messages...")
            default:
                print("   ℹ️ Unknown status: \(statusType)")
            }
        }
    }
}

// Create a chat message listener
class ChatMessageListener: MessageListener {
    var messageCount: Int = 0

    func onMessage(_ message: [String: Any]) {
        messageCount += 1
        print("\n📥 Received chat message:")
        print("   From: \(message["sender"] ?? "Unknown")")
        print("   Message: \(message["text"] ?? "")")
        print("   Time: \(message["timestamp"] ?? "")")
    }
}

// Run the tests
Task {
    do {
        // Initialize Realtime client
        let realtime = try Realtime(
            apiKey:
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )

        // Prepare with production settings (staging: false)
        try realtime.prepare(staging: false, opts: ["debug": true])

        // Set up status monitoring
        print("\n=== Testing Connection Status Monitoring ===")
        let statusListener = StatusListener()
        try await realtime.on(topic: SystemEvent.connected.rawValue, listener: statusListener)
        try await realtime.on(topic: SystemEvent.disconnected.rawValue, listener: statusListener)
        try await realtime.on(topic: SystemEvent.reconnecting.rawValue, listener: statusListener)
        try await realtime.on(topic: SystemEvent.reconnected.rawValue, listener: statusListener)
        try await realtime.on(topic: SystemEvent.messageResend.rawValue, listener: statusListener)
        print("✅ Status monitoring set up")

        // Connect to the service
        try await realtime.connect()
        print("✅ Successfully connected to Realtime service")

        // Test disconnection
        print("\n🧪 Testing disconnection...")
        try await realtime.close()
        print("✅ Disconnected from service")

        // Test reconnection
        print("\n🧪 Testing reconnection...")
        try await realtime.connect()
        print("✅ Reconnected to service")

        // Run comprehensive tests
        let tests = try RealtimeTests(
            apiKey:
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        try await tests.runAllTests()

        // Demonstrate real-time pub/sub functionality
        print("\n=== Demonstrating Real-time Pub/Sub ===")

        let demoTopic = "demo_chat_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let chatListener = ChatMessageListener()

        // Set up subscription
        print("\n📱 Setting up chat subscription...")
        try await realtime.on(topic: demoTopic, listener: chatListener)
        print("✅ Chat subscription active")

        // Send some demo messages
        let demoMessages = [
            [
                "sender": "Alice", "text": "Hello, is anyone there?",
                "timestamp": Date().description,
            ],
            ["sender": "Bob", "text": "Hi Alice! Yes, I'm here!", "timestamp": Date().description],
            [
                "sender": "Alice", "text": "Great! How's the realtime chat working?",
                "timestamp": Date().description,
            ],
        ]

        print("\n📤 Sending demo messages...")
        for message in demoMessages {
            let success = try await realtime.publish(topic: demoTopic, message: message)
            if success {
                print("✅ Sent: \(message["text"] ?? "")")
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
        }

        // Wait for messages to be processed
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Cleanup
        let unsubscribed = try await realtime.off(topic: demoTopic)
        if unsubscribed {
            print("\n✅ Unsubscribed from chat")
        } else {
            print("\n⚠️ Chat was not subscribed")
        }
        print("✅ Demo completed - Received \(chatListener.messageCount) messages")

        // Final cleanup
        try await realtime.close()

    } catch {
        print("\n❌ Error running tests:")
        print("   Error type: \(type(of: error))")
        print("   Description: \(error)")
        print("   Localized: \(error.localizedDescription)")
        if let relayError = error as? RelayError {
            print("   RelayError: \(relayError)")
        }
    }
    exit(0)
}

// Keep the main thread running
RunLoop.main.run()
