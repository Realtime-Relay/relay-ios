//import Foundation
//import Realtime
//
//public struct HistoryTest {
//    public static func main() async throws {
//        print("\n📜 Running History Test...")
//        
//        // Initialize Realtime
//        print("\nInitializing Realtime...")
//        let realtime = try Realtime(apiKey: "test_api_key", secret: "test_secret")
//        try realtime.prepare(staging: false, opts: ["debug": true])
//        print("✅ Realtime initialized")
//        
//        // Connect to Realtime
//        print("\nConnecting to Realtime...")
//        try await realtime.connect()
//        print("✅ Connected to Realtime")
//        
//        // Set up message listener for history test
//        let listener = SimpleListener()
//        try await realtime.on(topic: "test.history", listener: listener)
//        
//        // Publish test messages
//        print("\nPublishing test messages...")
//        for i in 1...3 {
//            _ = try await realtime.publish(topic: "test.history", message: ["message": "Test message \(i)"])
//            try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay
//        }
//        print("✅ Test messages published")
//        
//        // Get message history
//        print("\nFetching message history...")
//        let startDate = Date().addingTimeInterval(-5 * 60)  // 5 minutes ago
//        let history = try await realtime.history(topic: "test.history", startDate: startDate)
//        print("Message history: \(history)")
//        print("✅ Message history fetched")
//        
//        // Disconnect from Realtime
//        print("\nDisconnecting from Realtime...")
//        try await realtime.disconnect()
//        print("✅ Disconnected from Realtime")
//        
//        print("\n✅ History Test completed")
//    }
//} 
