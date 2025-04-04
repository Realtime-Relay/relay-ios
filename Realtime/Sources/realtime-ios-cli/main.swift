//
//  main.swift
//  Realtime
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation
import Realtime

//print("Starting test...")
//
//let realtime = try Realtime(
//    apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
//    secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
//)
//
//print("Connecting to NATS...")
//try await realtime.connect()
//print("Connected successfully")
//
//print("Setting up subscription...")
//let subscription = try await realtime.subscribe(subject: "test")
//print("Subscription set up successfully")
//
//// Start a task to handle incoming messages
//Task {
//    do {
//        for try await message in subscription {
//            print("Received message: \(message.string ?? "no string")")
//        }
//    } catch {
//        print("Error receiving messages: \(error)")
//    }
//}
//
//print("Publishing test messages...")
//_ = try await realtime.publish(subject: "test", message: "Hello, NATS!")
//print("Published string message: Hello, NATS!")
//
//_ = try await realtime.publish(subject: "test", message: "Another message")
//print("Published string message")
//
//struct ChatMessage: Codable, Sendable {
//    let sender: String
//    let text: String
//}
//
//let chatMessage = ChatMessage(sender: "Test", text: "Hello!")
//_ = try await realtime.publish(subject: "test", object: chatMessage)
//print("Published chat message")
//
//// Wait for messages to be stored
//print("Waiting for messages to be stored...")
//try await Task.sleep(nanoseconds: 2_000_000_000)
//
//print("Getting message history...")
//let messages = try await realtime.getMessageHistory(stream: "test")
//print("Retrieved \(messages.count) messages from history")
//
//// Set up a JSON message handler for chat messages
//let chatHandler = JSONMessageHandler<ChatMessage> { message in
//    print("Received chat message from \(message.sender): \(message.text)")
//}
//
//// Process the history with the handler
//let historyHandler = JSONHistoryHandler<ChatMessage> { messages in
//    print("Received \(messages.count) chat messages from history")
//    for message in messages {
//        print("History: \(message.sender) said: \(message.text)")
//    }
//}
//
//historyHandler.handleHistory(messages)
//
//// Set up a request handler for chat messages
//let requestHandler = RequestHandler<ChatMessage, String>(realtime: realtime) { message in
//    return "Received message from \(message.sender)"
//}
//
//// Test the request handler with history
//try await requestHandler.handleHistory(stream: "test") { messages in
//    print("Request handler received \(messages.count) chat messages")
//    for message in messages {
//        print("Request handler: \(message.sender) said: \(message.text)")
//    }
//}
//
//print("Message history request completed")
//
//print("Test running for 30 seconds...")
//try await Task.sleep(nanoseconds: 30_000_000_000)
//
//print("Disconnecting...")
//try await realtime.disconnect()
//print("Disconnected successfully")
