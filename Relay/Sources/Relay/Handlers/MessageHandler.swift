import Foundation

/// Protocol for handling messages received from NATS
public protocol MessageHandler: Sendable {
    /// Handle a single message
    /// - Parameter message: The message to handle
    func handleMessage(_ message: Message)
}

/// Protocol for handling message history
public protocol HistoryHandler: Sendable {
    /// Handle an array of messages from history
    /// - Parameter messages: Array of messages to handle
    func handleHistory(_ messages: [Message])
}

/// Default implementation of MessageHandler that decodes messages as JSON
public struct JSONMessageHandler<T: Decodable & Sendable>: MessageHandler {
    private let handler: @Sendable (T) -> Void
    
    /// Initialize a new JSON message handler
    /// - Parameter handler: Closure to handle the decoded message
    public init(handler: @escaping @Sendable (T) -> Void) {
        self.handler = handler
    }
    
    public func handleMessage(_ message: Message) {
        if let data = message.payload,
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            handler(decoded)
        }
    }
}

/// Default implementation of HistoryHandler that decodes messages as JSON
public struct JSONHistoryHandler<T: Decodable & Sendable>: HistoryHandler {
    private let handler: @Sendable ([T]) -> Void
    
    /// Initialize a new JSON history handler
    /// - Parameter handler: Closure to handle the array of decoded messages
    public init(handler: @escaping @Sendable ([T]) -> Void) {
        self.handler = handler
    }
    
    public func handleHistory(_ messages: [Message]) {
        let decoded = messages.compactMap { message -> T? in
            guard let data = message.payload else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
        handler(decoded)
    }
}

/// Convenience extension for Relay to handle messages
public extension Relay {
    /// Subscribe to messages with a JSON message handler
    /// - Parameters:
    ///   - subject: The subject to subscribe to
    ///   - handler: The message handler to use
    @discardableResult func subscribe<T: Decodable & Sendable>(
        subject: String,
        handler: @escaping @Sendable (T) -> Void
    ) async throws -> Subscription {
        let subscription = try await subscribe(subject: subject)
        
        // Start handling messages in a separate task
        Task {
            for try await message in subscription {
                if let data = message.payload,
                   let decoded = try? JSONDecoder().decode(T.self, from: data) {
                    handler(decoded)
                }
            }
        }
        
        return subscription
    }
    
    /// Get message history with a JSON history handler
    /// - Parameters:
    ///   - stream: Name of the stream
    ///   - handler: The history handler to use
    ///   - limit: Maximum number of messages to return
    func getMessageHistory<T: Decodable & Sendable>(
        stream: String,
        handler: @escaping @Sendable ([T]) -> Void,
        limit: Int = 100
    ) async throws {
        let messages = try await getMessageHistory(stream: stream, limit: limit)
        let decoded = messages.compactMap { message -> T? in
            guard let data = message.payload else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
        handler(decoded)
    }
} 
