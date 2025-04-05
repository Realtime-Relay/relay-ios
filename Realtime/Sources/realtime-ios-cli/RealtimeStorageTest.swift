import Foundation
import Realtime

struct RealtimeStorageTest {
    static func run() async throws {
        print("🧪 Starting Realtime Storage Test...")
        
        // Initialize Realtime instance with debug mode enabled
        print("\nInitializing Realtime instance...")
        let realtime = try Realtime(staging: false, opts: ["debug": true])
        
        // Set authentication
        print("\nSetting up authentication...")
        try realtime.setAuth(
            apiKey: "eyJ0eX0Q01WQiOi0xLCJ3CJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUJO4"
        )
        
        // Connect to NATS server
        print("\nConnecting to NATS server...")
        try await realtime.connect()
        print("✅ Connected successfully")
        
        // Set up message listener
        print("\nSetting up message listener...")
        let listener = TestMessageListener(name: "Storage Test")
        try await realtime.on(topic: "test.storage", listener: listener)
        print("✅ Message listener set up")
        
        // Test message publishing and retrieval
        print("\n🧪 Testing message storage and retrieval...")
        
        // Publish test messages
        print("\n📤 Publishing test messages...")
        for i in 1...3 {
            let message: [String: Any] = [
                "type": "text",
                "content": "Test message \(i)",
                "timestamp": Date().timeIntervalSince1970
            ]
            let result = try await realtime.publish(topic: "test.storage", message: message)
            if result {
                print("✅ Message \(i) published")
            }
        }
        
        // Wait for messages to be processed
        print("\n⏳ Waiting for messages to be processed (5 seconds)...")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Test history functionality
        print("\n📜 Testing message history...")
        let startDate = Date().addingTimeInterval(-300) // 5 minutes ago
        let messages = try await realtime.history(topic: "test.storage", startDate: startDate)
        
        print("\n📋 Retrieved \(messages.count) messages:")
        for (index, message) in messages.enumerated() {
            print("\nMessage \(index + 1):")
            if let content = message["message"] as? [String: Any] {
                print("   Content: \(content)")
            }
            if let clientId = message["client_id"] {
                print("   From: \(clientId)")
            }
            if let timestamp = message["start"] {
                print("   Timestamp: \(timestamp)")
            }
        }
        
        // Clean up
        print("\nDisconnecting...")
        try await realtime.disconnect()
        print("✅ Test completed successfully")
    }
} 