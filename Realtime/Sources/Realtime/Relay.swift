// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@preconcurrency import Nats

public actor Realtime {
    // MARK: - Properties
    
    var natsConnection: NatsClient
    private let servers: [URL] = [
        URL(string: "nats://api.relay-x.io:4221")!,
        URL(string: "nats://api.relay-x.io:4222")!,
        URL(string: "nats://api.relay-x.io:4223")!,
        URL(string: "nats://api.relay-x.io:4224")!,
        URL(string: "nats://api.relay-x.io:4225")!,
        URL(string: "nats://api.relay-x.io:4226")!
    ]
    private var apiKey: String?
    private var secret: String?
    private var isConnected = false
    private var credentialsPath: URL?
    private var isDebug: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize a new Realtime instance with configuration
    /// - Parameters:
    ///   - staging: Whether to use staging environment
    ///   - opts: Configuration options including debug mode
    /// - Throws: RelayError.invalidOptions if options are not provided
    public init(staging: Bool, opts: [String: Any]) throws {
        guard !opts.isEmpty else {
            throw RelayError.invalidOptions("Options must be provided")
        }
        
        self.isDebug = opts["debug"] as? Bool ?? false
        
        // Configure NATS connection
        let options = NatsClientOptions()
            .urls(servers)
        
        self.natsConnection = options.build()
    }
    
    deinit {
        // Clean up credentials file
        if let path = credentialsPath {
            try? FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Public Methods
    
    /// Set the API key and secret for authentication
    /// - Parameters:
    ///   - apiKey: Your API key for authentication
    ///   - secret: Your secret key for authentication
    /// - Throws: RelayError.invalidCredentials if apiKey or secret is empty
    public func setAuth(apiKey: String, secret: String) throws {
        guard !apiKey.isEmpty else {
            throw RelayError.invalidCredentials("API key cannot be empty")
        }
        
        guard !secret.isEmpty else {
            throw RelayError.invalidCredentials("Secret key cannot be empty")
        }
        
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
        
        // Update NATS connection with credentials
        let options = NatsClientOptions()
            .urls(servers)
            .credentialsFile(credentialsPath)
        
        // Rebuild connection with new credentials
        self.natsConnection = options.build()
    }
    
    private func validateAuth() throws {
        guard apiKey != nil && secret != nil else {
            throw RelayError.invalidCredentials("API key and secret must be set before performing operations")
        }
    }
    
    /// Connect to the NATS server
    public func connect() async throws {
        try validateAuth()
        try await natsConnection.connect()
        isConnected = true
        if isDebug {
            print("Connected to NATS server")
        }
    }
    
    /// Create a JetStream stream
    /// - Parameters:
    ///   - name: Name of the stream
    ///   - subjects: Array of subjects to capture
    public func createStream(name: String, subjects: [String]) async throws {
        try validateAuth()
        let config: [String: Any] = [
            "name": name,
            "subjects": subjects,
            "retention": "workqueue",
            "max_consumers": -1,
            "max_msgs": -1,
            "max_bytes": -1,
            "max_age": 0,
            "storage": "memory",
            "discard": "old"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config)
        let response = try await natsConnection.request(
            jsonData,
            subject: "\(NatsConstants.JetStream.apiPrefix).STREAM.CREATE.\(name)"
        )
        
        if isDebug {
            if let data = response.payload,
               let str = String(data: data, encoding: .utf8) {
                print("Stream creation response: \(str)")
            }
        }
    }
    
    /// Disconnect from the NATS server
    public func disconnect() async throws {
        try validateAuth()
        try await natsConnection.close()
        isConnected = false
        
        if isDebug {
            print("Disconnected from NATS server")
        }
        
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
        try validateAuth()
        try await natsConnection.publish(payload, subject: subject)
        if isDebug {
            print("Published message to subject: \(subject)")
        }
        return true
    }
    
    /// Subscribe to a subject
    /// - Parameters:
    ///   - subject: The subject to subscribe to
    /// - Returns: A Subscription that can be used to receive messages
    public func subscribe(subject: String) async throws -> Subscription {
        try validateAuth()
        let natsSubscription = try await natsConnection.subscribe(subject: subject)
        if isDebug {
            print("Subscribed to subject: \(subject)")
        }
        return Subscription(from: natsSubscription)
    }
    
    // MARK: - Convenience Methods
    
    /// Publish a string message
    /// - Parameters:
    ///   - subject: The subject to publish to
    ///   - message: The string message to publish
    public func publish(subject: String, message: String) async throws -> Bool {
        try validateAuth()
        _ = try await publish(subject: subject, payload: Data(message.utf8))
        return true
    }
    
    /// Publish a JSON encodable object
    /// - Parameters:
    ///   - subject: The subject to publish to
    ///   - object: The object to encode and publish
    public func publish<T: Encodable>(subject: String, object: T) async throws -> Bool {
        try validateAuth()
        let data = try JSONEncoder().encode(object)
        _ = try await publish(subject: subject, payload: data)
        return true
    }
}
