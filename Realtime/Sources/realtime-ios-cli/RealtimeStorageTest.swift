import Foundation
import Realtime

struct RealtimeStorageTest {
    static func run() async throws {
        print("\n🧪 Starting Offline Storage Test...\n")
        
        // Initialize Realtime with debug mode enabled
        let realtime = try Realtime(staging: false, opts: ["debug": true])
        
        // Set authentication
        try await realtime.setAuth(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        // Connect to NATS first
        print("\nConnecting to NATS server...")
        try await realtime.connect()
        print("Connected successfully")
        
        // Create test stream
        print("\nCreating test stream...")
        try await realtime.createStream(name: "test_stream", subjects: ["test.*"])
        print("Stream created successfully")
        
        // Set up subscription
        print("\nSetting up subscription...")
        let subscription = try await realtime.subscribe(topic: "test.room1")
        print("Subscription set up successfully")
        
        // Start a task to handle incoming messages
        Task {
            do {
                print("Listening for messages...")
                for try await message in subscription {
                    if let json = try? JSONSerialization.jsonObject(with: message.payload) as? [String: Any],
                       let messageContent = json["message"] {
                        print("\n📨 Received message:")
                        print("   Content: \(messageContent)")
                        if let metadata = json["client_id"] {
                            print("   From: \(metadata)")
                        }
                        if let timestamp = json["start"] {
                            print("   Timestamp: \(timestamp)")
                        }
                    }
                }
            } catch {
                print("❌ Error receiving messages: \(error)")
            }
        }
        
        // Test 1: Publish while offline
        print("\nTest 1: Publishing while offline...")
        try await realtime.disconnect()
        print("Disconnected from NATS server")
        
        let offlineMessage: [String: Any] = [
            "type": "offline",
            "content": "This message was sent while offline",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let offlineResult = try await realtime.publish(topic: "test.room1", message: offlineMessage)
        print("Message stored offline: \(offlineResult)")
        
        // Test 2: Publish multiple messages while offline
        print("\nTest 2: Publishing multiple messages while offline...")
        for i in 1...3 {
            let multipleMessage: [String: Any] = [
                "type": "offline_batch",
                "content": "Offline message \(i)",
                "timestamp": Date().timeIntervalSince1970
            ]
            let result = try await realtime.publish(topic: "test.room1", message: multipleMessage)
            print("Stored offline message \(i): \(result)")
        }
        
        // Reconnect and wait for messages to be resent
        print("\nReconnecting to NATS server...")
        try await realtime.connect()
        print("Connected successfully")
        
        // Wait for messages to be resent
        print("\nWaiting for stored messages to be resent (10 seconds)...")
        try await Task.sleep(nanoseconds: 10_000_000_000)
        
        // Clean up
        print("\nDisconnecting...")
        try await realtime.disconnect()
        print("Disconnected successfully")
    }
} 