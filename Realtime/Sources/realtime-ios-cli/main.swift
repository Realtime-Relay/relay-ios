import Foundation
import Realtime

struct RealtimeCLI {
    static func main() async throws {
        print("\n=== Testing CONNECTED Event ===")

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

                print("Event ID: \(id)")
                print("Status: \(status)")
                print("Namespace: \(namespace)")
                print("Timestamp: \(timestamp)")
                print("=== End of CONNECTED Event ===\n")

                eventReceived = true
                eventData = message
            }
        }

        let connectedListener = ConnectedEventListener()

        // Subscribe to the CONNECTED event
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
        } else {
            print("❌ CONNECTED event not received")
        }

        // Clean up
        print("\n🧹 Cleaning up...")
        try await realtime.disconnect()

        print("\n✅ CONNECTED Event Test completed")
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
