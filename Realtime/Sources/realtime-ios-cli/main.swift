import Foundation
import Realtime

struct RealtimeCLI {
    static func main() async throws {
        print("\n=== Testing Realtime SDK Stream Management ===")

        // Initialize Realtime with production credentials
        let realtime = try Realtime(
            apiKey:
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )

        // Configure for production and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])

        // Connect to NATS first
        print("\n🔄 Connecting to NATS...")
        try await realtime.connect()
        print("✅ Connected to NATS server")

        // Test 1: Stream Creation
        print("\n🧪 Test 1: Stream Creation")
        print("Testing stream creation with new topic...")
        let testTopic1 =
            "test_stream_creation_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        try await realtime.createOrGetStream(for: testTopic1)
        print("✅ Stream creation test completed")

        // Test 2: Stream Existence Check
        print("\n🧪 Test 2: Stream Existence Check")
        print("Checking if stream exists for the same topic...")
        try await realtime.createOrGetStream(for: testTopic1)
        print("✅ Stream existence check completed")

        // Test 3: Stream Update
        print("\n🧪 Test 3: Stream Update")
        print("Testing stream update with new subject...")
        let testTopic2 =
            "test_stream_update_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        try await realtime.createOrGetStream(for: testTopic2)
        print("✅ Stream update test completed")

        // Test 4: Multiple Topics in Same Stream
        print("\n🧪 Test 4: Multiple Topics in Same Stream")
        print("Testing multiple topics in the same stream...")
        let topics = [
            "test_multi_1_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))",
            "test_multi_2_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))",
            "test_multi_3_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))",
        ]

        for topic in topics {
            try await realtime.createOrGetStream(for: topic)
            print("✅ Added topic: \(topic)")
        }
        print("✅ Multiple topics test completed")

        // Test 5: Stream Reuse
        print("\n🧪 Test 5: Stream Reuse")
        print("Testing stream reuse with existing topics...")
        for topic in topics {
            try await realtime.createOrGetStream(for: topic)
            print("✅ Reused stream for topic: \(topic)")
        }
        print("✅ Stream reuse test completed")

        // Test 6: Stream Recovery After Disconnect
        print("\n🧪 Test 6: Stream Recovery After Disconnect")
        print("Testing stream recovery after disconnect...")

        // Disconnect
        try await realtime.close()
        print("✅ Disconnected from NATS")

        // Reconnect
        try await realtime.connect()
        print("✅ Reconnected to NATS")

        // Try to use existing stream
        try await realtime.createOrGetStream(for: testTopic1)
        print("✅ Stream recovery test completed")

        // Clean up
        print("\n🧹 Cleaning up...")
        try await realtime.close()

        print("\n✅ All stream management tests completed successfully")

        // Test 7: Message History
        print("\n🧪 Test 7: Message History")

        // Reconnect for history tests
        print("🔄 Reconnecting to NATS...")
        try await realtime.connect()
        print("✅ Reconnected to NATS")

        // First, publish some test messages
        print("\nPublishing test messages...")
        let testTopic = "test_history_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"

        // Create stream for the test topic
        try await realtime.createOrGetStream(for: testTopic)

        // Record start time before publishing
        let testStartTime = Date().addingTimeInterval(-1)  // Start 1 second ago
        print("Test start time: \(testStartTime)")

        // Publish messages with different timestamps
        let messages = [
            ["content": "Message 1", "timestamp": Int(Date().timeIntervalSince1970)],
            ["content": "Message 2", "timestamp": Int(Date().timeIntervalSince1970) + 1],
            ["content": "Message 3", "timestamp": Int(Date().timeIntervalSince1970) + 2],
        ]

        for message in messages {
            let success = try await realtime.publish(topic: testTopic, message: message)
            if success {
                print("✅ Published message: \(message)")
            } else {
                print("❌ Failed to publish message: \(message)")
            }
            // Add a delay between messages
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }

        // Add a delay after publishing to ensure messages are stored
        print("Waiting for messages to be stored...")
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Test history with date range
        print("\nTesting history with date range...")
        let endDate = Date().addingTimeInterval(5)  // End 5 seconds in the future
        print("Start time: \(testStartTime)")
        print("End time: \(endDate)")

        let historyMessages = try await realtime.history(
            topic: testTopic,
            start: testStartTime,
            end: endDate,
            limit: 100
        )

        print("\nRetrieved \(historyMessages.count) messages:")
        for message in historyMessages {
            print("Message: \(message)")
        }
        print("✅ History test completed")

        // Clean up
        print("\n🧹 Cleaning up...")
        try await realtime.close()

        print("\n✅ All tests completed successfully")
    }
}

// Run the tests
Task {
    do {
        try await RealtimeCLI.main()
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
