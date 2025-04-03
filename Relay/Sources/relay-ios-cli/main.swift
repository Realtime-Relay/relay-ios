//
//  main.swift
//  Relay
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation
import Relay

print("Starting test...")

let relay = Relay(
    servers: [
        URL(string: "nats://api.relay-x.io:4221")!,
        URL(string: "nats://api.relay-x.io:4222")!,
        URL(string: "nats://api.relay-x.io:4223")!,
        URL(string: "nats://api.relay-x.io:4224")!,
        URL(string: "nats://api.relay-x.io:4225")!,
        URL(string: "nats://api.relay-x.io:4226")!
    ],
    apiKey: "eyJ0eXAiOiJKV1QjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
    secret: "SUABDOORDKC4JWCVOMSJO4"
)

print("Connecting to NATS...")
try await relay.connect()
print("Connected successfully")

print("Setting up subscription...")
let subscription = try await relay.subscribe(subject: "test")
print("Subscription set up successfully")

// Start a task to handle incoming messages
Task {
    do {
        for try await message in subscription {
            print("Received message: \(message.string ?? "no string")")
        }
    } catch {
        print("Error receiving messages: \(error)")
    }
}

print("Publishing test messages...")
_ = try await relay.publish(subject: "test", message: "Hello, NATS!")
print("Published string message: Hello, NATS!")

_ = try await relay.publish(subject: "test", message: "Another message")
print("Published string message")

struct ChatMessage: Codable, Sendable {
    let sender: String
    let text: String
}

let chatMessage = ChatMessage(sender: "Test", text: "Hello!")
_ = try await relay.publish(subject: "test", object: chatMessage)
print("Published chat message")

// Wait for messages to be stored
print("Waiting for messages to be stored...")
try await Task.sleep(nanoseconds: 2_000_000_000)

print("Getting message history...")
let messages = try await relay.getMessageHistory(stream: "test")
print("Retrieved \(messages.count) messages from history")

// Set up a JSON message handler for chat messages
let chatHandler = JSONMessageHandler<ChatMessage> { message in
    print("Received chat message from \(message.sender): \(message.text)")
}

// Process the history with the handler
let historyHandler = JSONHistoryHandler<ChatMessage> { messages in
    print("Received \(messages.count) chat messages from history")
    for message in messages {
        print("History: \(message.sender) said: \(message.text)")
    }
}

historyHandler.handleHistory(messages)

// Set up a request handler for chat messages
let requestHandler = RequestHandler<ChatMessage, String>(relay: relay) { message in
    return "Received message from \(message.sender)"
}

// Test the request handler with history
try await requestHandler.handleHistory(stream: "test") { messages in
    print("Request handler received \(messages.count) chat messages")
    for message in messages {
        print("Request handler: \(message.sender) said: \(message.text)")
    }
}

print("Message history request completed")

print("Test running for 30 seconds...")
try await Task.sleep(nanoseconds: 30_000_000_000)

print("Disconnecting...")
try await relay.disconnect()
print("Disconnected successfully")
