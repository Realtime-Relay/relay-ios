//
//  main.swift
//  Relay
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation
import Relay

// MARK: - Example Message Model
struct ChatMessage: Codable, Sendable {
    let id: String
    let content: String
    let timestamp: Date
    let sender: String
}

// MARK: - Relay Service
actor RelayService {
    // MARK: - Properties
    private let relay: Relay
    private var subscriptions: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    init(servers: [URL], apiKey: String, secret: String) {
        self.relay = Relay(servers: servers, apiKey: apiKey, secret: secret)
    }
    
    // MARK: - Connection Management
    func connect() async throws {
        try await relay.connect()
        print("Successfully connected to NATS server")
        
//        // Create the chat stream if it doesn't exist
//        do {
//            try await relay.createStream(name: "chat", subjects: ["chat"])
//            print("Created chat stream")
//        } catch {
//            // Ignore error if stream already exists
//            print("Stream creation error (may already exist): \(error)")
//        }
    }
    
    func disconnect() async throws {
        // Cancel all active subscriptions
        for task in subscriptions.values {
            task.cancel()
        }
        subscriptions.removeAll()
        
        try await relay.disconnect()
        print("Disconnected from NATS server")
    }
    
    // MARK: - Message Publishing
    func publishString<S: StringProtocol & Sendable>(_ message: S, to subject: String) async throws {
        let sendableMessage = String(message)
        try await relay.publish(subject: subject, message: sendableMessage)
        print("Published string message: \(sendableMessage)")
    }
    
    func publish<T: Encodable & Sendable>(_ message: T, to subject: String) async throws {
        try await relay.publish(subject: subject, object: message)
        print("Published object to \(subject)")
    }
    
    // MARK: - Message Subscription
    func subscribe<T: Decodable & Sendable>(
        to subject: String,
        messageHandler: @escaping @Sendable (T) -> Void
    ) async throws {
        // Cancel existing subscription if any
        subscriptions[subject]?.cancel()
        
        let task = Task {
            do {
                let subscription = try await relay.subscribe(subject: subject) { (message: T) in
                    messageHandler(message)
                }
                print("Subscribed to \(subject)")
                
                // Keep subscription alive until cancelled
                try await Task.sleep(nanoseconds: UInt64.max)
                try? await subscription.unsubscribe()
            } catch {
                print("Subscription error: \(error)")
            }
        }
        
        subscriptions[subject] = task
    }
    
    // MARK: - Message History
    func getHistory<T: Decodable & Sendable>(
        from stream: String,
        limit: Int = 100,
        completion: @escaping @Sendable ([T]) -> Void
    ) async throws {
        try await relay.getMessageHistory(
            stream: stream,
            handler: completion,
            limit: limit
        )
    }
}

// MARK: - View Model
@MainActor
class RelayViewModel {
    // MARK: - Properties
    private let service: RelayService
    private var testTask: Task<Void, Never>?
    
    // MARK: - Published Properties
    @Published private(set) var receivedMessages: [ChatMessage] = []
    @Published private(set) var historyMessages: [ChatMessage] = []
    @Published private(set) var isConnected = false
    @Published private(set) var error: Error?
    
    // MARK: - Initialization
    init(servers: [URL], apiKey: String, secret: String) {
        self.service = RelayService(servers: servers, apiKey: apiKey, secret: secret)
    }
    
    // MARK: - Test Methods
    func startTest() {
        testTask?.cancel()
        testTask = Task {
            do {
                // 1. Connect to NATS
                try await service.connect()
                isConnected = true
                
                // 2. Subscribe to messages
                try await service.subscribe(to: "test") { [weak self] (message: ChatMessage) in
                    Task { @MainActor in
                        self?.receivedMessages.append(message)
                        print("Received: \(message.content) from \(message.sender)")
                    }
                }
                
                // 3. Get message history
                try await service.getHistory(from: "test") { [weak self] (messages: [ChatMessage]) in
                    Task { @MainActor in
                        self?.historyMessages = messages
                        print("Retrieved \(messages.count) messages from history")
                        for message in messages {
                            print("History: \(message.content) from \(message.sender)")
                        }
                    }
                }
                
                // 4. Publish test messages
                let testMessage = "Hello, NATS!"
                try await service.publishString(testMessage, to: "test")
                
                let chatMessage = ChatMessage(
                    id: UUID().uuidString,
                    content: "Hello from Relay!",
                    timestamp: Date(),
                    sender: "User123"
                )
                try await service.publish(chatMessage, to: "test")
                
                // 5. Keep test running for 30 seconds
                try await Task.sleep(nanoseconds: 30_000_000_000)
                
            } catch {
                self.error = error
                print("Test error: \(error)")
            }
            
            // 6. Cleanup
            do {
                try await service.disconnect()
                isConnected = false
            } catch {
                self.error = error
                print("Disconnect error: \(error)")
            }
        }
    }
    
    func stopTest() {
        testTask?.cancel()
        testTask = nil
        
        Task {
            try? await service.disconnect()
            await MainActor.run {
                isConnected = false
            }
        }
    }
}

// MARK: - Example Usage
let viewModel = RelayViewModel(
    servers: [
        URL(string: "nats://api.relay-x.io:4221")!,
        URL(string: "nats://api.relay-x.io:4222")!,
        URL(string: "nats://api.relay-x.io:4223")!,
        URL(string: "nats://api.relay-x.io:4224")!,
        URL(string: "nats://api.relay-x.io:4225")!,
        URL(string: "nats://api.relay-x.io:4226")!
    ],
    apiKey: "eyJ0eXAiOiJKV16NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA", // This is the JWT token
    secret: "SUAO4" // This is the NKey (secret)
)

// Start the test
viewModel.startTest()

// Keep the program running
RunLoop.main.run()
