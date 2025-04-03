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
    private var credentialsPath: URL?
    
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
        
        // Create temporary credentials file with correct NATS format
        let credentialsContent = """
        -----BEGIN NATS USER JWT-----
        \(apiKey)
        ------END NATS USER JWT------

        ************************* IMPORTANT *************************
        NKEY Seed printed below can be used to sign and prove identity.
        NKEYs are sensitive and should be treated as secrets.

        -----BEGIN USER NKEY SEED-----
        \(secret)
        ------END USER NKEY SEED------

        *************************************************************
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let credentialsPath = tempDir.appendingPathComponent("relay_credentials.creds")
        self.credentialsPath = credentialsPath
        
        do {
            try credentialsContent.write(to: credentialsPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create credentials file: \(error)")
        }
        
        // Configure NATS connection with credentials file
        let options = NatsClientOptions()
            .urls(servers)
            .credentialsFile(credentialsPath)
        
        self.natsConnection = options.build()
    }
    
    deinit {
        // Clean up credentials file
        if let path = credentialsPath {
            try? FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize the connection (like Python's init())
    public func initialize() async throws {
        // No-op for now, but matches Python's init() pattern
    }
    
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
        
        // Clean up credentials file after disconnecting
        if let path = credentialsPath {
            try? FileManager.default.removeItem(at: path)
            credentialsPath = nil
        }
    }
    
    /// Publish a message to a subject
    /// - Parameters:
    ///   - subject: The subject to publish to
    ///   - payload: The message payload
    public func publish(subject: String, payload: Data) async throws -> Bool {
        try await natsConnection.publish(payload, subject: subject)
        return true
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
    public func publish(subject: String, message: String) async throws -> Bool {
        try await publish(subject: subject, payload: Data(message.utf8))
        return true
    }
    
    /// Publish a JSON encodable object
    /// - Parameters:
    ///   - subject: The subject to publish to
    ///   - object: The object to encode and publish
    public func publish<T: Encodable>(subject: String, object: T) async throws -> Bool {
        let data = try JSONEncoder().encode(object)
        try await publish(subject: subject, payload: data)
        return true
    }
}
