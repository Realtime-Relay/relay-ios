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
        
        // Test publishing different message types
        print("\n📤 Testing message publishing...")
        
        // Test 1: Publish string message
        print("\nTest 1: Publishing string message")
        let stringSuccess = try await realtime.publish(topic: "test.topic", message: "Hello, World!")
        print("String message publish result: \(stringSuccess ? "✅ Success" : "❌ Failed")")
        
        // Test 2: Publish integer message
        print("\nTest 2: Publishing integer message")
        let intSuccess = try await realtime.publish(topic: "test.topic", message: 42)
        print("Integer message publish result: \(intSuccess ? "✅ Success" : "❌ Failed")")
        
        // Test 3: Publish JSON message
        print("\nTest 3: Publishing JSON message")
        let jsonMessage: [String: Any] = [
            "type": "test",
            "data": ["key": "value"],
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        let jsonSuccess = try await realtime.publish(topic: "test.topic", message: jsonMessage)
        print("JSON message publish result: \(jsonSuccess ? "✅ Success" : "❌ Failed")")
        
        // Test 4: Publish offline message
        print("\nTest 4: Publishing while disconnected")
        try await realtime.disconnect()
        let offlineSuccess = try await realtime.publish(topic: "test.topic", message: "Offline message")
        print("Offline message publish result: \(offlineSuccess ? "✅ Success (stored locally)" : "❌ Failed")")
        
        // Reconnect to test message resending
        print("\n🔄 Reconnecting to test message resending...")
        try await realtime.connect()
        
        // Clean up
        print("\n🧹 Cleaning up...")
        try await realtime.disconnect()
        
        print("\n✅ All publish tests completed")
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
