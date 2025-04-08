import Foundation
import Realtime

class MessageEncodingTest {
    func run() async throws {
        let realtime = try Realtime(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        try realtime.prepare(staging: false, opts: ["debug": true])
        
        try await realtime.connect()
        print("Connected to NATS")
        
        let listener = TestMessageListener(name: "Test")
        try await realtime.on(topic: "test", listener: listener)
        print("Subscribed to test topic")
        
        // Test string message
        _ = try await realtime.publish(topic: "test", message: "Hello World")
        print("Published string message")
        
        // Test integer message
        _ = try await realtime.publish(topic: "test", message: 42)
        print("Published integer message")
        
        // Test JSON message
        let jsonMessage: [String: Any] = ["key": "value", "number": 123]
        _ = try await realtime.publish(topic: "test", message: jsonMessage)
        print("Published JSON message")
        
        // Wait for messages to be processed
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        try await realtime.disconnect()
        print("Disconnected from NATS")
    }
}
