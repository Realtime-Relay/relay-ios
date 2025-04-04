//
//  main.swift
//  Realtime
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation
import Realtime

struct RealtimeCLI {
    static func main() async throws {
        print("Starting Realtime test...")
        
        // Initialize Realtime with debug mode enabled
        let realtime = try Realtime(staging: false, opts: ["debug": true])
        
        // Set authentication
        try await realtime.setAuth(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        print("Connecting to NATS server...")
        try await realtime.connect()
        print("Connected successfully")
        
        // Create a test stream
        print("Creating test stream...")
        try await realtime.createStream(name: "test_stream", subjects: ["test.*"])
        print("Stream created successfully")
        
        // Set up subscription
        print("Setting up subscription...")
        let subscription = try await realtime.subscribe(topic: "test.room1")
        print("Subscription set up successfully")
        
        // Start a task to handle incoming messages
        Task {
            do {
                for try await message in subscription {
                    if let json = try? JSONSerialization.jsonObject(with: message.payload) as? [String: Any],
                       let messageContent = json["message"] {
                        print("Received message: \(messageContent)")
                    }
                }
            } catch {
                print("Error receiving messages: \(error)")
            }
        }
        
        // Publish some test messages
        print("Publishing test messages...")
        
        // Publish a string message wrapped in a dictionary
        let stringMessage: [String: Any] = [
            "type": "text",
            "content": "Hello, Realtime!",
            "timestamp": Date().timeIntervalSince1970
        ]
        let publishResult1 = try await realtime.publish(topic: "test.room1", message: stringMessage)
        if publishResult1 {
            print("Published string message successfully")
        }
        
        // Publish a dictionary message
        let dictMessage: [String: Any] = [
            "type": "test",
            "content": "This is a test message",
            "timestamp": Date().timeIntervalSince1970
        ]
        let publishResult2 = try await realtime.publish(topic: "test.room1", message: dictMessage)
        if publishResult2 {
            print("Published dictionary message successfully")
        }
        
        // Wait for messages to be received
        print("Waiting for messages (30 seconds)...")
        try await Task.sleep(nanoseconds: 30_000_000_000)
        
        // Clean up
        print("Disconnecting...")
        try await realtime.disconnect()
        print("Disconnected successfully")
    }
}

// Run the main function
try await RealtimeCLI.main()
