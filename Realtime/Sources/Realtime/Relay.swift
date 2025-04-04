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
    private var clientId: String
    
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
        self.clientId = UUID().uuidString
        
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
    
    /// Publish a message to a topic
    /// - Parameters:
    ///   - topic: The topic to publish to
    ///   - message: The message to publish (String, number, or JSON)
    /// - Throws: TopicValidationError if topic is invalid
    /// - Throws: RelayError.invalidPayload if message is invalid
    public func publish(topic: String, message: Any) async throws -> Bool {
        try validateAuth()
        
        // Validate topic
        try TopicValidator.validate(topic)
        
        // Validate message type
        if (try? JSONSerialization.data(withJSONObject: message)) == nil {
            throw RelayError.invalidPayload
        }
        
        // Create the final message format
        let finalMessage: [String: Any] = [
            "client_id": clientId,
            "id": UUID().uuidString,
            "room": topic,
            "message": message,
            "start": Int(Date().timeIntervalSince1970)
        ]
        
        let finalData = try JSONSerialization.data(withJSONObject: finalMessage)
        let finalTopic = NatsConstants.Topics.formatTopic(topic)
        
        try await natsConnection.publish(finalData, subject: finalTopic)
        
        if isDebug {
            print("Published message to topic: \(topic)")
        }
        
        return true
    }
    
    /// Subscribe to a topic
    /// - Parameters:
    ///   - topic: The topic to subscribe to
    /// - Returns: A Subscription that can be used to receive messages
    public func subscribe(topic: String) async throws -> Subscription {
        try validateAuth()
        try TopicValidator.validate(topic)
        
        let finalTopic = NatsConstants.Topics.formatTopic(topic)
        let natsSubscription = try await natsConnection.subscribe(subject: finalTopic)
        
        if isDebug {
            print("Subscribed to topic: \(topic)")
        }
        
        return Subscription(from: natsSubscription)
    }
}
