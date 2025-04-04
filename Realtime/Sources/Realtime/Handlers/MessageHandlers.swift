import Foundation

/// Protocol for handling messages
public protocol MessageHandling: Sendable {
    associatedtype T: Codable & Sendable
    
    /// Handle a message
    /// - Parameter message: The message to handle
    func handleMessage(_ message: Message)
}

/// Protocol for handling message history
public protocol HistoryHandling: Sendable {
    associatedtype T: Codable & Sendable
    
    /// Handle a message history
    /// - Parameter messages: The messages to handle
    func handleHistory(_ messages: [Message])
}

/// Default implementation of MessageHandling that decodes messages as JSON
public struct JSONMessageHandler<T: Codable & Sendable>: MessageHandling {
    private let handler: @Sendable (T) -> Void
    
    /// Initialize a new JSON message handler
    /// - Parameter handler: Closure to handle the decoded message
    public init(handler: @escaping @Sendable (T) -> Void) {
        self.handler = handler
    }
    
    public func handleMessage(_ message: Message) {
        if let decoded = try? JSONDecoder().decode(T.self, from: message.payload) {
            handler(decoded)
        }
    }
}

/// Default implementation of HistoryHandling that decodes messages as JSON
public struct JSONHistoryHandler<T: Codable & Sendable>: HistoryHandling {
    private let handler: @Sendable ([T]) -> Void
    
    /// Initialize a new JSON history handler
    /// - Parameter handler: Closure to handle the array of decoded messages
    public init(handler: @escaping @Sendable ([T]) -> Void) {
        self.handler = handler
    }
    
    public func handleHistory(_ messages: [Message]) {
        let decoded = messages.compactMap { message -> T? in
            return try? JSONDecoder().decode(T.self, from: message.payload)
        }
        
        if !decoded.isEmpty {
            handler(decoded)
        }
    }
}

/// A handler for messages that require a response
public struct RequestHandler<T: Codable & Sendable, R: Codable & Sendable>: Sendable {
    private let handler: @Sendable (T) async throws -> R
    private let realtime: Realtime
    
    /// Initialize a new request handler
    /// - Parameters:
    ///   - realtime: The Realtime instance to use for message handling
    ///   - handler: The closure to call when a request is received
    public init(realtime: Realtime, handler: @escaping @Sendable (T) async throws -> R) {
        self.realtime = realtime
        self.handler = handler
    }
    
    /// Handle a subscription
    /// - Parameters:
    ///   - subscription: The subscription to handle
    ///   - handler: The closure to call when a message is received
    public func handleSubscription(
        _ subscription: AsyncStream<Message>,
        handler: @escaping @Sendable (T) -> Void
    ) {
        Task {
            for try await message in subscription {
                let decoded = try? JSONDecoder().decode(T.self, from: message.payload)
                if let decoded = decoded {
                    handler(decoded)
                }
            }
        }
    }
    
    /// Handle a message history
    /// - Parameters:
    ///   - stream: The stream to get history from
    ///   - limit: The maximum number of messages to get
    ///   - handler: The closure to call when messages are received
    public func handleHistory(
        stream: String,
        limit: Int = 100,
        handler: @escaping @Sendable ([T]) -> Void
    ) async throws {
        let messages = try await realtime.getMessageHistory(stream: stream, limit: limit)
        let decoded = messages.compactMap { message -> T? in
            let decoded = try? JSONDecoder().decode(T.self, from: message.payload)
            return decoded
        }
        
        if !decoded.isEmpty {
            handler(decoded)
        }
    }
} 