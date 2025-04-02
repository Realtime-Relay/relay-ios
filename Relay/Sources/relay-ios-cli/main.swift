//
//  main.swift
//  Relay
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation
import Relay

//@main
//struct RelayCLI {
//    static func main() async {
//        // MARK: - Configuration
//        let servers = [
//            "nats://api.relay-x.io:4221",
//            "nats://api.relay-x.io:4222",
//            "nats://api.relay-x.io:4223",
//            "nats://api.relay-x.io:4224",
//            "nats://api.relay-x.io:4225",
//            "nats://api.relay-x.io:4226"
//        ].map { URL(string: $0)! }
//        
//        let apiKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA"
//        
//        let secret = "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
//        
//        // MARK: - Initialize Relay
//        let relay = Relay(servers: servers, apiKey: apiKey, secret: secret)
//        
//        do {
//            // MARK: - Connect to NATS
//            print("Connecting to NATS server...")
//            try await relay.connect()
//            print("Successfully connected to NATS server")
//            
//            // MARK: - Example 1: Publish and Subscribe
//            print("\n=== Example 1: Publish and Subscribe ===")
//            let testSubject = "test.subject"
//            
//            // Create a message handler actor to handle messages
//            actor MessageHandler {
//                func handleMessage(_ message: NatsMessage) {
//                    if let data = message.payload,
//                       let string = String(data: data, encoding: .utf8) {
//                        print("Received message: \(string)")
//                    }
//                }
//            }
//            
//            let messageHandler = MessageHandler()
//            
//            // Subscribe to messages
//            let subscription = try await relay.subscribe(subject: testSubject)
//            print("Subscribed to subject: \(testSubject)")
//            
//            // Start listening for messages
//            Task {
//                do {
//                    for await message in subscription {
//                        await messageHandler.handleMessage(message)
//                    }
//                } catch {
//                    print("Error handling messages: \(error)")
//                }
//            }
//            
//            // Publish a test message
//            let testMessage = "Hello from Relay SDK!"
//            try await relay.publish(subject: testSubject, payload: Data(testMessage.utf8))
//            print("Published message: \(testMessage)")
//            
//            // MARK: - Example 2: JetStream History
//            print("\n=== Example 2: JetStream History ===")
//            let streamName = "test.stream"
//            
//            // Get message history
//            let messages = try await relay.getMessageHistory(
//                stream: streamName,
//                subject: testSubject,
//                limit: 10
//            )
//            print("Retrieved \(messages.count) messages from stream: \(streamName)")
//            
//            // Process messages in the actor context
//            for message in messages {
//                await messageHandler.handleMessage(message)
//            }
//            
//            // MARK: - Example 3: Fetch Messages After Sequence
//            print("\n=== Example 3: Fetch Messages After Sequence ===")
//            let sequence: UInt64 = 1
//            let recentMessages = try await relay.fetchMessagesAfter(
//                stream: streamName,
//                sequence: sequence,
//                limit: 5
//            )
//            print("Retrieved \(recentMessages.count) messages after sequence \(sequence)")
//            
//            // Process recent messages in the actor context
//            for message in recentMessages {
//                await messageHandler.handleMessage(message)
//            }
//            
//            // MARK: - Cleanup
//            print("\nCleaning up...")
//            try await relay.disconnect()
//            print("Disconnected from NATS server")
//            
//        } catch {
//            print("Error: \(error)")
//        }
//    }
//}
