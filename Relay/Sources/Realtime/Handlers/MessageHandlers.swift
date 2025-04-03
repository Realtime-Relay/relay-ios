import Foundation
@preconcurrency import Nats

/// A protocol for handling messages
public protocol MessageHandler: Sendable {
    /// The type of message this handler can handle
    associatedtype Message: Codable & Sendable
    
    /// Handle a message
    /// - Parameter message: The message to handle
    /// - Returns: A boolean indicating if the message was handled successfully
    func handle(_ message: Message) async throws -> Bool
}

/// A protocol for handling requests
public protocol RequestHandler: Sendable {
    /// The type of request this handler can handle
    associatedtype Request: Codable & Sendable
    /// The type of response this handler will return
    associatedtype Response: Codable & Sendable
    
    /// Handle a request
    /// - Parameter request: The request to handle
    /// - Returns: The response to the request
    func handle(_ request: Request) async throws -> Response
}

/// A default implementation of MessageHandler
public struct DefaultMessageHandler<T: Codable & Sendable>: MessageHandler {
    private let handler: @Sendable (T) async throws -> Bool
    private let realtime: Realtime
    
    /// Initialize a new message handler
    /// - Parameters:
    ///   - realtime: The Realtime instance to use for message handling
    ///   - handler: The closure to call when a message is received
    public init(realtime: Realtime, handler: @escaping @Sendable (T) async throws -> Bool) {
        self.realtime = realtime
        self.handler = handler
    }
    
    public func handle(_ message: T) async throws -> Bool {
        try await handler(message)
    }
}

/// A default implementation of RequestHandler
public struct DefaultRequestHandler<T: Codable & Sendable, R: Codable & Sendable>: RequestHandler {
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
    
    public func handle(_ request: T) async throws -> R {
        try await handler(request)
    }
}

/// Protocol for handling message history
public protocol HistoryHandling: Sendable {
    associatedtype T: Codable & Sendable
    
    /// Handle a message history
    /// - Parameter messages: The messages to handle
    func handleHistory(_ messages: [Message])
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