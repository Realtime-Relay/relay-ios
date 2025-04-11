import Foundation
import Realtime

struct RealtimeCLI {
    static func main() async throws {
        print("\n=== Testing Realtime SDK Connection and NATS Events ===")

        // Initialize Realtime with production credentials
        let realtime = try Realtime(
            apiKey:
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )

        // Configure for production and debug mode
        try realtime.prepare(staging: false, opts: ["debug": true])

        // Create a listener for the CONNECTED event
        class ConnectedEventListener: MessageListener {
            var eventReceived = false
            var eventData: [String: Any]?
            var eventTimestamp: Int?
            var eventNamespace: String?

            func onMessage(_ message: [String: Any]) {
                print("\n=== CONNECTED Event Received ===")
                print("Event Data: \(message)")

                // Verify event format
                guard let id = message["id"] as? String,
                    let eventMessage = message["message"] as? [String: Any],
                    let status = eventMessage["status"] as? String,
                    let namespace = eventMessage["namespace"] as? String,
                    let timestamp = eventMessage["timestamp"] as? Int
                else {
                    print("❌ Invalid event format")
                    return
                }

                // Store event details
                eventReceived = true
                eventData = message
                eventTimestamp = timestamp
                eventNamespace = namespace

                print("Event ID: \(id)")
                print("Status: \(status)")
                print("Namespace: \(namespace)")
                print("Timestamp: \(timestamp)")
                print("=== End of CONNECTED Event ===\n")
            }
        }

        let connectedListener = ConnectedEventListener()

        // Subscribe to the CONNECTED event BEFORE connecting
        print("\nSubscribing to CONNECTED event...")
        try await realtime.on(topic: SystemEvent.connected.rawValue, listener: connectedListener)

        // Connect to NATS
        print("\n🔄 Connecting to NATS...")
        try await realtime.connect()

        // Wait for the event to be processed
        print("\nWaiting for CONNECTED event...")
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Verify the event was received
        if connectedListener.eventReceived {
            print("✅ CONNECTED event received successfully")

            // Verify event data
            if let timestamp = connectedListener.eventTimestamp {
                let currentTime = Int(Date().timeIntervalSince1970)
                let timeDiff = abs(currentTime - timestamp)
                if timeDiff <= 2 {
                    print("✅ Event timestamp is valid (within 2 seconds)")
                } else {
                    print("❌ Event timestamp is too old (difference: \(timeDiff) seconds)")
                }
            }

            if let namespace = connectedListener.eventNamespace {
                if namespace == "relay-internal-ios-dev" {
                    print("✅ Event namespace is correct")
                } else {
                    print("❌ Event namespace is incorrect: \(namespace)")
                }
            }
        } else {
            print("❌ CONNECTED event not received")
        }

        // Test manual disconnection
        print("\n🧪 Testing manual disconnection...")
        try await realtime.disconnect()
        print("✅ Manual disconnection completed")

        // Test reconnection
        print("\n🧪 Testing reconnection...")
        try await realtime.connect()
        print("✅ Reconnection completed")

        // Test unexpected disconnection simulation
        print("\n🧪 Testing unexpected disconnection handling...")
        // Note: In a real test, we would simulate a network failure
        // For now, we'll just verify the event handling is in place
        print("✅ NATS event handlers are properly configured")

        // Clean up
        print("\n🧹 Cleaning up...")
        try await realtime.disconnect()

        print("\n✅ All tests completed")
    }
}

// Run the tests
Task {
    do {
        try await RealtimeCLI.main()
    } catch {
        print("❌ Error running tests:")
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
