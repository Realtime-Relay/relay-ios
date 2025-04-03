//
//  RelayActor.swift
//  Relay
//
//  Created by Shaxzod on 02/04/25.
//

@preconcurrency import Nats
import Foundation


actor RelayActor {
    let natsConnection: NatsClient
    private var isConnected = false
    private var activeSubscriptions: [String: Task<Void, Never>] = [:]
    
    init(natsConnection: NatsClient) {
        self.natsConnection = natsConnection
    }
    
    // MARK: - Connection Management
    func connect() async throws {
        try await natsConnection.connect()
        isConnected = true
    }
    
    func disconnect() async throws {
        try await natsConnection.close()
        isConnected = false
        cancelAllSubscriptions()
    }
    
    // MARK: - Publishing
    func publish(subject: String, payload: Data) async throws {
        try await natsConnection.publish(payload, subject: subject)
    }
    
    // MARK: - Subscriptions
    func subscribe(subject: String, handler: @Sendable @escaping (Message) -> Void) async throws {
        let subscription = try await natsConnection.subscribe(subject: subject)
        
        let task = Task {
            do {
                for try await message in subscription {
                    await MainActor.run {
                        handler(Message(from: message))
                    }
                }
            } catch {
                print("Subscription error: \(error)")
            }
        }
        
        activeSubscriptions[subject] = task
    }
    
    // MARK: - Requests
    func request(subject: String, payload: Data, timeout: TimeInterval) async throws -> Message {
        let response = try await natsConnection.request(payload, subject: subject, timeout: timeout)
        return Message(from: response)
    }
    
    // MARK: - Private
    private func cancelAllSubscriptions() {
        activeSubscriptions.values.forEach { $0.cancel() }
        activeSubscriptions.removeAll()
    }
}
