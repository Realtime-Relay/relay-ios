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
                try await service.subscribe(to: "chat") { [weak self] (message: ChatMessage) in
                    Task { @MainActor in
                        self?.receivedMessages.append(message)
                        print("Received: \(message.content) from \(message.sender)")
                    }
                }
                
                // 3. Get message history
                try await service.getHistory(from: "chat") { [weak self] (messages: [ChatMessage]) in
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
                try await service.publishString(testMessage, to: "chat")
                
                let chatMessage = ChatMessage(
                    id: UUID().uuidString,
                    content: "Hello from Relay!",
                    timestamp: Date(),
                    sender: "User123"
                )
                try await service.publish(chatMessage, to: "chat")
                
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
        
    ],
    apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
    secret: ""
)

// Start the test
viewModel.startTest()

// Keep the program running
RunLoop.main.run()
