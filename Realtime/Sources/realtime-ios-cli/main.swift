import Foundation
import Realtime

// Create a chat message listener
class ChatMessageListener: MessageListener {
    var messageCount: Int = 0

    func onMessage(_ message: Any) {
        messageCount += 1
        print("\n📥 Received chat message:")
        if let messageDict = message as? [String: Any] {
            print("   From: \(messageDict["sender"] ?? "Unknown")")
            print("   Message: \(messageDict["text"] ?? "")")
            print("   Time: \(messageDict["timestamp"] ?? "")")
        } else {
            print("   Message: \(message)")
        }
    }
}

// Run the tests
Task {
    do {
        // Run System Event Tests
        print("\n=== Running System Event Tests ===")
        try await SystemEventTest.main()
        
        // Initialize Realtime client for chat demo
        let realtime = try Realtime(
            apiKey:
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVQU9STjRWQkNXQzJORU1FVkpFWUY3VERIUVdYTUNLTExTWExNTjZRTjRBVU1WUElDSVJOSEpJRyIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDUwNTE2NjcsImp0aSI6IllVMG50TXFNcHhwWFNWbUp0OUJDazhhV0dxd0NwYytVQ0xwa05lWVBVcDNNRTNQWDBRcUJ2ZjBBbVJXMVRDamEvdTg2emIrYUVzSHVKUFNmOFB2SXJnPT0ifQ._LtZJnTADAnz3N6U76OaA-HCYq-XxckChk1WlHi_oZXfYP2vqcGIiNDFSQ-XpfjUTfKtXEuzcf_BDq54nSEMAA",
            secret: "SUAPWRWRITWYL4YP7B5ZHU3W2G2ZPYJ47IN4UWNHLMFTSIJEOMQJWWSWGY"
        )

        // Prepare with production settings (staging: false)
        try realtime.prepare(staging: false, opts: ["debug": true])

        // Connect to the service
        try await realtime.connect()
        print("✅ Successfully connected to Realtime service")

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
