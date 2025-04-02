// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@preconcurrency import Nats

public actor Relay {
    // MARK: - Properties
    
    let natsConnection: NatsClient
    private let servers: [URL]
    private let apiKey: String
    private let secret: String
    private var isConnected = false
    
    // MARK: - Initialization
    
    /// Initialize a new Relay instance
    /// - Parameters:
    ///   - servers: Array of NATS server URLs
    ///   - apiKey: Your API key for authentication
    ///   - secret: Your secret key for authentication
    public init(servers: [URL], apiKey: String, secret: String) {
        self.servers = servers
        self.apiKey = apiKey
        self.secret = secret
        
        // Configure NATS connection
        let options = NatsClientOptions()
            .urls(servers)
            .nkey(secret)
            .token(apiKey)
//            .maxReconnects(10)
        
        self.natsConnection = options.build()
    }
    
    // MARK: - Public Methods
    
    /// Connect to the NATS server
    public func connect() async throws {
        try await natsConnection.connect()
        isConnected = true
    }
    
    /// Create a JetStream stream
    /// - Parameters:
    ///   - name: Name of the stream
    ///   - subjects: Array of subjects to capture
//    public func createStream(name: String, subjects: [String]) async throws {
//        let config = [
//            "stream_name": name,
//            "subjects": subjects,
//            "retention": "workqueue",
//            "max_consumers": 128,
//            "max_msgs_per_subject": -1,
//            "max_msgs": -1,
//            "max_age": -1,
//            "max_bytes": -1
//        ]
//        
//        try await natsConnection.request(
//            try JSONEncoder().encode(config),
//            subject: "\(NatsConstants.JetStream.apiPrefix).STREAM.CREATE.\(name)"
//        )
//        print("Created stream: \(name)")
//    }
    
    /// Disconnect from the NATS server
    public func disconnect() async throws {
        try await natsConnection.close()
        isConnected = false
    }
    
    /// Publish a message to a subject
    /// - Parameters:
    ///   - subject: The subject to publish to
    ///   - payload: The message payload
    public func publish(subject: String, payload: Data) async throws {
        try await natsConnection.publish(payload, subject: subject)
    }
    
    /// Subscribe to a subject
    /// - Parameters:
    ///   - subject: The subject to subscribe to
    /// - Returns: A Subscription that can be used to receive messages
    public func subscribe(subject: String) async throws -> Subscription {
        let natsSubscription = try await natsConnection.subscribe(subject: subject)
        return Subscription(from: natsSubscription)
    }
    
    // MARK: - Convenience Methods
    
    /// Publish a string message
    /// - Parameters:
    ///   - subject: The subject to publish to
    ///   - message: The string message to publish
    public func publish(subject: String, message: String) async throws {
        try await publish(subject: subject, payload: Data(message.utf8))
    }
    
    /// Publish a JSON encodable object
    /// - Parameters:
    ///   - subject: The subject to publish to
    ///   - object: The object to encode and publish
    public func publish<T: Encodable>(subject: String, object: T) async throws {
        let data = try JSONEncoder().encode(object)
        try await publish(subject: subject, payload: data)
    }
}
