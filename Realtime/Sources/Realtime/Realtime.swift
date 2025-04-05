// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@preconcurrency import Nats
import Dispatch
//import NatsClient

/// Protocol for receiving messages from the Realtime service
public protocol MessageListener {
    func onMessage(_ message: [String: Any])
}

@preconcurrency public final class Realtime: @unchecked Sendable {
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
    private var existingStreams: Set<String> = []
    private let messageStorage: MessageStorage
    
    private var messageListeners: [String: MessageListener] = [:]
    private var subscriptions: [String: NatsSubscription] = [:]
    private var messageTasks: [String: Task<Void, Never>] = [:]
    
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
        self.messageStorage = MessageStorage()
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
        
        // Set up connection status monitoring
        natsConnection.on([.disconnected]) { [weak self] _ in
            self?.isConnected = false
            print("🔴 Disconnected from NATS server")
        }
        
        natsConnection.on([.connected]) { [weak self] _ in
            self?.isConnected = true
            print("🟢 Connected to NATS server")
            Task { @Sendable [weak self] in
                await self?.resendStoredMessages()
            }
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
        
        // Add to existing streams
        existingStreams.insert(name)
    }
    
    /// Ensure a stream exists for the given topic
    /// - Parameter topic: The topic to ensure a stream exists for
    private func ensureStreamExists(for topic: String) async throws {
        // Extract stream name from topic
        let streamName = "stream_\(topic.replacingOccurrences(of: ".", with: "_"))"
        
        // Check if stream already exists
        if existingStreams.contains(streamName) {
            return
        }
        
        // Create stream if it doesn't exist
        try await createStream(name: streamName, subjects: [NatsConstants.Topics.formatTopic(topic)])
    }
    
    /// Disconnect from the NATS server
    public func disconnect() async throws {
        try validateAuth()
        
        // Cancel all message handling tasks
        for task in messageTasks.values {
            task.cancel()
        }
        messageTasks.removeAll()
        
        try await natsConnection.close()
        isConnected = false
        
        if isDebug {
            print("Disconnected from NATS server")
        }
    }
    
    /// Publish a message to a topic using JetStream
    /// - Parameters:
    ///   - topic: The topic to publish to
    ///   - message: The message to publish (String, number, or JSON)
    /// - Throws: TopicValidationError if topic is invalid
    /// - Throws: RelayError.invalidPayload if message is invalid
    public func publish(topic: String, message: Any) async throws -> Bool {
        try validateAuth()
        
        // Validate topic
        try TopicValidator.validate(topic)
        
        // If not connected, store message locally
        if !isConnected {
            let finalMessage: [String: Any] = [
                "client_id": clientId,
                "id": UUID().uuidString,
                "room": topic,
                "message": message,
                "start": Int(Date().timeIntervalSince1970)
            ]
            messageStorage.storeMessage(topic: topic, message: finalMessage)
            if isDebug {
                print("💾 Stored message locally (offline): \(finalMessage)")
            }
            return true
        }
        
        // Ensure stream exists
        try await ensureStreamExists(for: topic)
        
        // Validate message type
        if (try? JSONSerialization.data(withJSONObject: message)) == nil {
            throw RelayError.invalidPayload
        }
        
        // Create the final message format with UTC timestamp and client ID
        let finalMessage: [String: Any] = [
            "client_id": clientId,
            "id": UUID().uuidString,
            "room": topic,
            "message": message,
            "start": Int(Date().timeIntervalSince1970)
        ]
        
        let finalData = try JSONSerialization.data(withJSONObject: finalMessage)
        
        // Format topic as: namespace_stream_topic
        let finalTopic = NatsConstants.Topics.formatTopic(topic)
        
        // Publish directly to the formatted topic
        try await natsConnection.publish(finalData, subject: finalTopic)
        
        if isDebug {
            print("Published message to topic: \(finalTopic)")
            if let str = String(data: finalData, encoding: .utf8) {
                print("Message payload: \(str)")
            }
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
        
        // Ensure stream exists
        try await ensureStreamExists(for: topic)
        
        let finalTopic = NatsConstants.Topics.formatTopic(topic)
        let natsSubscription = try await natsConnection.subscribe(subject: finalTopic)
        
        if isDebug {
            print("Subscribed to topic: \(topic)")
        }
        
        return Subscription(from: natsSubscription)
    }
    
    private func resendStoredMessages() async {
        let storedMessages = messageStorage.getStoredMessages()
        guard !storedMessages.isEmpty else { return }
        
        if isDebug {
            print("📤 Resending \(storedMessages.count) stored messages...")
        }
        
        for storedMessage in storedMessages {
            do {
                // Extract the original message from the stored message
                if let originalMessage = storedMessage.message["message"] {
                    _ = try await publish(topic: storedMessage.topic, message: originalMessage)
                    if isDebug {
                        print("✅ Resent message to topic: \(storedMessage.topic)")
                    }
                }
            } catch {
                if isDebug {
                    print("❌ Failed to resend message to topic \(storedMessage.topic): \(error)")
                }
                // Keep the message in storage if resend fails
                continue
            }
        }
        
        // Clear successfully resent messages
        messageStorage.clearStoredMessages()
    }
    
    /// Subscribe to a topic with a message listener
    /// - Parameters:
    ///   - topic: The topic to subscribe to
    ///   - listener: The message listener interface
    /// - Throws: TopicValidationError if topic is invalid
    public func on(topic: String, listener: MessageListener) async throws {
        try validateAuth()
        try TopicValidator.validate(topic)
        
        // Store the listener
        messageListeners[topic] = listener
        
        // If not connected, return early
        guard isConnected else { return }
        
        // Ensure stream exists
        try await ensureStreamExists(for: topic)
        
        let finalTopic = NatsConstants.Topics.formatTopic(topic)
        
        // Create subscription if it doesn't exist
        if subscriptions[topic] == nil {
            let subscription = try await natsConnection.subscribe(subject: finalTopic)
            subscriptions[topic] = subscription
            
            // Start message handling task
            let task = Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    for try await message in subscription {
                        // Parse message
                        guard let data = message.payload,
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }
                        
                        // Check if message should be delivered
                        if let clientId = json["client_id"] as? String,
                           let room = json["room"] as? String,
                           clientId != self.clientId,
                           room == topic,
                           let listener = self.messageListeners[topic] {
                            
                            // Deliver message to listener
                            listener.onMessage(json)
                        }
                    }
                } catch {
                    if self.isDebug {
                        print("Error handling messages for topic \(topic): \(error)")
                    }
                }
            }
            
            // Store task reference
            messageTasks[topic] = task
            subscriptions[topic] = subscription
        }
    }
    
    /// Unsubscribe from a topic and clean up associated resources
    /// - Parameter topic: The topic to unsubscribe from
    /// - Returns: true if successfully unsubscribed, false otherwise
    /// - Throws: TopicValidationError if topic is invalid
    public func off(topic: String) async throws -> Bool {
        try validateAuth()
        try TopicValidator.validate(topic)
        
        // Cancel and remove message handling task
        if let task = messageTasks[topic] {
            task.cancel()
            messageTasks.removeValue(forKey: topic)
        }
        
        // Remove message listener
        messageListeners.removeValue(forKey: topic)
        
        // Unsubscribe from NATS and remove subscription
        if let subscription = subscriptions[topic] {
            try await subscription.unsubscribe()
            subscriptions.removeValue(forKey: topic)
            
            if isDebug {
                print("Unsubscribed from topic: \(topic)")
            }
            return true
        }
        
        return false
    }
    
    /// Get a list of past messages between a start time and an optional end time
    /// - Parameters:
    ///   - topic: The topic to get messages from
    ///   - startDate: The start date for message retrieval (required)
    ///   - endDate: The end date for message retrieval (optional)
    /// - Returns: An array of messages matching the criteria
    /// - Throws: TopicValidationError if topic is invalid
    /// - Throws: RelayError.invalidDate if dates are invalid
    public func history(topic: String, startDate: Date, endDate: Date? = nil) async throws -> [[String: Any]] {
        try validateAuth()
        try TopicValidator.validate(topic)
        
        // Validate start date
        guard startDate != Date.distantPast else {
            throw RelayError.invalidDate("Start date cannot be null or invalid")
        }
        
        // Validate end date if provided
        if let endDate = endDate {
            guard endDate > startDate else {
                throw RelayError.invalidDate("End date must be after start date")
            }
        }
        
        // Return empty array if not connected
        guard isConnected else {
            return []
        }
        
        // Format the final topic and stream name
        let finalTopic = NatsConstants.Topics.formatTopic(topic)
        let streamName = "stream_\(topic.replacingOccurrences(of: ".", with: "_"))"
        
        // Convert dates to timestamps
        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = endDate.map { Int($0.timeIntervalSince1970) }
        
        var messages: [[String: Any]] = []
        
        // Create a consumer with delivery policy by start time
        let consumerConfig: [String: Any] = [
            "deliver_policy": "all",
            "ack_policy": "explicit",  // Required for pull mode
            "max_deliver": 1,
            "filter_subject": finalTopic,
            "num_replicas": 1,
            "max_waiting": 1,  // Only one client will be pulling
            "max_batch": 100,  // Get up to 100 messages at once
            "max_expires": 5000000000  // 5 seconds in nanoseconds
        ]
        
        let createRequest: [String: Any] = [
            "stream_name": streamName,
            "config": consumerConfig
        ]
        
        if isDebug {
            print("Creating consumer with config: \(createRequest)")
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: createRequest)
        let createResponse = try await natsConnection.request(
            jsonData,
            subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.CREATE.\(streamName)",
            timeout: 5.0
        )
        
        if isDebug {
            if let data = createResponse.payload,
               let str = String(data: data, encoding: .utf8) {
                print("Consumer creation response: \(str)")
            }
        }
        
        guard let data = createResponse.payload,
              let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let consumerName = responseDict["name"] as? String else {
            if isDebug {
                print("Failed to create consumer or get consumer name")
            }
            return []
        }
        
        if isDebug {
            print("Created consumer: \(consumerName)")
        }
        
        // Fetch messages using the consumer
        let batchRequest: [String: Any] = [
            "batch": 100,
            "no_wait": false,  // Wait for messages
            "expires": 5000000000  // 5 seconds in nanoseconds
        ]
        
        let batchData = try JSONSerialization.data(withJSONObject: batchRequest)
        
        while true {
            do {
                let response = try await natsConnection.request(
                    batchData,
                    subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.MSG.NEXT.\(streamName).\(consumerName)",
                    timeout: 5.0
                )
                
                if isDebug {
                    if let data = response.payload,
                       let str = String(data: data, encoding: .utf8) {
                        print("Message response: \(str)")
                    }
                }
                
                guard let messageData = response.payload,
                      let messageDict = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                      let timestamp = messageDict["start"] as? Int else {
                    break
                }
                
                // Check if message timestamp is within range
                if timestamp >= startTimestamp && (endTimestamp == nil || timestamp <= endTimestamp!) {
                    messages.append(messageDict)
                }
                
                // Acknowledge the message
                let ackSubject = "\(NatsConstants.JetStream.apiPrefix).CONSUMER.ACK.\(streamName).\(consumerName)"
                try await natsConnection.publish(Data(), subject: ackSubject)
                
            } catch {
                if isDebug {
                    print("Error fetching message: \(error)")
                }
                break
            }
        }
        
        _ = try await natsConnection.request(
            Data(),
            subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.DELETE.\(streamName).\(consumerName)"
        )
        
        if isDebug {
            print("Retrieved \(messages.count) messages")
        }
        
        return messages
    }
}
