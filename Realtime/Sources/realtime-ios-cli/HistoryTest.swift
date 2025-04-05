import Foundation
import Realtime

class HistoryTest {
    static func main() async throws {
        print("🧪 Starting History Test...")
        
        // Initialize Realtime instance with debug mode
        print("\n📱 Initializing Realtime instance...")
        let realtime = try Realtime(staging: false, opts: ["debug": true])
        
        // Set authentication
        try realtime.setAuth(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        // Connect to NATS
        print("\n🔄 Connecting to NATS server...")
        try await realtime.connect()
        
        // Set up message listener for history test
        let listener = TestMessageListener(name: "History Test")
        try await realtime.on(topic: "test.history", listener: listener)
        
        // First, publish some test messages
        print("\n📤 Publishing test messages...")
        let testMessages = [
            ["type": "text", "content": "History test message 1"],
            ["type": "text", "content": "History test message 2"],
            ["type": "text", "content": "History test message 3"]
        ]
        
        for message in testMessages {
            _ = try await realtime.publish(topic: "test.history", message: message)
            print("✅ Published test message")
        }
        
        // Wait for messages to be processed
        print("\n⏳ Waiting for messages to be processed (3 seconds)...")
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Test different history scenarios
        print("\n🧪 Testing history retrieval scenarios...")
        
        // Scenario 1: Last 5 minutes
        print("\n📜 Scenario 1: Retrieving messages from last 5 minutes")
        let startDate = Date().addingTimeInterval(-300) // 5 minutes ago
        let messages1 = try await realtime.history(topic: "test.history", startDate: startDate)
        printMessages(messages1, scenario: "Last 5 minutes")
        
        // Scenario 2: Custom time range
        print("\n📜 Scenario 2: Retrieving messages from custom time range")
        let endDate = Date()
        let startDate2 = endDate.addingTimeInterval(-3600) // Last hour
        let messages2 = try await realtime.history(topic: "test.history", startDate: startDate2, endDate: endDate)
        printMessages(messages2, scenario: "Custom time range")
        
        // Scenario 3: Testing invalid date range
        print("\n📜 Scenario 3: Testing invalid date range")
        do {
            let invalidEndDate = Date()
            let invalidStartDate = invalidEndDate.addingTimeInterval(3600) // Start date after end date
            _ = try await realtime.history(topic: "test.history", startDate: invalidStartDate, endDate: invalidEndDate)
            print("❌ Test failed: Should have thrown an error for invalid date range")
        } catch RelayError.invalidDate {
            print("✅ Successfully caught invalid date error")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
        
        // Scenario 4: Past week messages
        print("\n📜 Scenario 4: Retrieving messages from past week")
        let weekStartDate = Date().addingTimeInterval(-7 * 24 * 3600) // 7 days ago
        let weekMessages = try await realtime.history(topic: "test.history", startDate: weekStartDate)
        printMessages(weekMessages, scenario: "Past week")
        
        // Clean up
        print("\nDisconnecting...")
        try await realtime.disconnect()
        print("✅ History test completed")
    }
    
    private static func printMessages(_ messages: [[String: Any]], scenario: String) {
        print("\n📋 Retrieved \(messages.count) messages for \(scenario):")
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
    }
}

// Message listener implementation for history test
//class TestMessageListener: MessageListener {
//    let name: String
//    var receivedMessages: [[String: Any]] = []
//    
//    init(name: String) {
//        self.name = name
//    }
//    
//    func onMessage(_ message: [String: Any]) {
//        print("\n📨 [\(name)] Received message via listener:")
//        if let messageContent = message["message"] {
//            print("   Content: \(messageContent)")
//        }
//        if let clientId = message["client_id"] {
//            print("   From: \(clientId)")
//        }
//        if let timestamp = message["start"] {
//            print("   Timestamp: \(timestamp)")
//        }
//        receivedMessages.append(message)
//    }
//} 
