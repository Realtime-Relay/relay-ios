import Foundation
import Realtime

struct RealtimeCLI {
    static func main() async throws {
        print("\n=== Testing Realtime Publish ===")
        
        // Initialize Realtime with production credentials
        let realtime = try Realtime(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        // Configure for production and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])
        
        // Connect to NATS
        print("\n🔄 Connecting to NATS...")
        try await realtime.connect()
        
        // Test stream management
        print("\n=== Testing Stream Management ===")
        
        // Test 1: Create stream with first topic
        print("\nTest 1: Creating stream with first topic")
        let topic1 = "test.stream1"
        let success1 = try await realtime.publish(topic: topic1, message: "First stream test")
        print("Stream creation result: \(success1 ? "✅ Success" : "❌ Failed")")
        
        // Test 2: Add second topic to existing stream
        print("\nTest 2: Adding second topic to existing stream")
        let topic2 = "test.stream2"
        let success2 = try await realtime.publish(topic: topic2, message: "Second stream test")
        print("Stream update result: \(success2 ? "✅ Success" : "❌ Failed")")
        
        // Test 3: Publish to existing topic
        print("\nTest 3: Publishing to existing topic")
        let success3 = try await realtime.publish(topic: topic1, message: "Second message to first topic")
        print("Publish to existing topic result: \(success3 ? "✅ Success" : "❌ Failed")")
        
        // Test 4: Publish while disconnected
        print("\nTest 4: Publishing while disconnected")
        try await realtime.disconnect()
        let success4 = try await realtime.publish(topic: topic1, message: "Offline message")
        print("Offline publish result: \(success4 ? "✅ Success (stored locally)" : "❌ Failed")")
        
        // Test 5: Reconnect and verify stream persistence
        print("\nTest 5: Reconnecting and verifying stream persistence")
        try await realtime.connect()
        let success5 = try await realtime.publish(topic: topic1, message: "Post-reconnect message")
        print("Post-reconnect publish result: \(success5 ? "✅ Success" : "❌ Failed")")
        
        // Test 6: Publish to multiple topics
        print("\nTest 6: Publishing to multiple topics")
        let topics = ["test.stream3", "test.stream4", "test.stream5"]
        var allSuccess = true
        for topic in topics {
            let success = try await realtime.publish(topic: topic, message: "Multi-topic test")
            print("  \(topic): \(success ? "✅ Success" : "❌ Failed")")
            allSuccess = allSuccess && success
        }
        print("Multiple topic publish result: \(allSuccess ? "✅ All successful" : "❌ Some failed")")
        
        // Clean up
        print("\n🧹 Cleaning up...")
        try await realtime.disconnect()
        
        print("\n✅ All stream tests completed")
    }
}

// Run the tests
Task {
    do {
        try await RealtimeCLI.main()
    } catch {
        print("❌ Error running tests: \(error)")
    }
    exit(0)
}

// Keep the main thread running
RunLoop.main.run()
