// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@preconcurrency import Nats
import Dispatch
//import NatsClient

/// SDK Topics for internal events
public enum SDKTopic {
    public static let CONNECTED = "sdk.connected"
    public static let DISCONNECTED = "sdk.disconnected"
    public static let RECONNECTING = "sdk.reconnecting"
    public static let RECONNECTED = "sdk.reconnected"
}

/// Connection event arguments
public enum ConnectionEvent: String {
    case RECONNECTING
    case RECONNECTED
    case DISCONNECTED
}

/// Protocol for receiving messages from the Realtime service
public protocol MessageListener {
    func onMessage(_ message: [String: Any])
}

@preconcurrency public final class Realtime: @unchecked Sendable {
    // MARK: - Properties
    
    var natsConnection: NatsClient
    private var servers: [URL] = []
    private var apiKey: String?
    private var secret: String?
    private var isConnected = false
    private var credentialsPath: URL?
    private var isDebug: Bool = false
    private var clientId: String
    private var existingStreams: Set<String> = []
    private var messageStorage: MessageStorage
    private var namespace: String?
    private var isStaging: Bool = false
    private var pendingTopics: Set<String> = []
    
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
        self.isStaging = staging
        self.messageStorage = MessageStorage()
        
        // Configure server URLs based on staging flag
        let baseUrl = staging ? "0.0.0.0" : "api.relay-x.io"
        self.servers = (4221...4226).map { port in
            URL(string: "nats://\(baseUrl):\(port)")!
        }
        
        // Configure NATS connection with required settings
        let options = NatsClientOptions()
            .urls(servers)
            .maxReconnects(1200)
            .reconnectWait(1000)
        
        self.natsConnection = options.build()
    }
    
    deinit {
        // Clean up credentials file
        if let path = credentialsPath {
            try? FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Public Methods
    
    /// Set authentication credentials
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
            .maxReconnects(1200)
            .reconnectWait(1000)
        
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
        if self.isDebug {
            print("🔄 Connecting and retrieving namespace...")
        }
        
        // Connect to NATS server first
        try await natsConnection.connect()
        self.isConnected = true
        
        if self.isDebug {
            print("✅ Connected to NATS server")
        }
        
        // Get namespace
        let namespace = try await getNamespace()
        self.namespace = namespace
        
        if self.isDebug {
            print("✅ Retrieved namespace: \(namespace)")
        }
        
        // Subscribe to SDK topics
        try await subscribeToTopics()
        
        // Resend any stored messages after successful connection
        await resendStoredMessages()
        
        if self.isDebug {
            print("✅ Connected and ready")
        }
    }
    
    /// Get the namespace for the current user
    private func getNamespace() async throws -> String {
        guard let apiKey = self.apiKey else {
            throw RelayError.invalidCredentials("API key not set")
        }
        
        if self.isDebug {
            print("Requesting namespace with API key")
        }
        
        // Try to connect for up to 5 seconds
        for _ in 0..<50 {
            if isConnected {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        guard isConnected else {
            throw RelayError.notConnected("Failed to connect to NATS server")
        }
        
        // Create request payload
        let request = [
            "api_key": apiKey
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: request)
        
        do {
            // Request namespace from service
            let response = try await natsConnection.request(
                requestData,
                subject: "account.user.get_namespace",
                timeout: 5.0
            )
            
            guard let responseData = response.payload,
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let namespace = json["namespace"] as? String else {
                throw RelayError.invalidPayload
            }
            
            return namespace
        } catch {
            if self.isDebug {
                print("Failed to get namespace: \(error)")
            }
            // For now, return a default namespace for testing
            // In production, this should be handled differently
            return "default"
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
        
        // If not connected, add to pending topics
        guard isConnected else {
            pendingTopics.insert(topic)
            return
        }
        
        // Handle SDK reconnection event
        if topic == SDKTopic.RECONNECTED {
            await resendStoredMessages()
        }
        
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
                        guard let data = message.payload else {
                            if self.isDebug {
                                print("Message payload is nil")
                            }
                            continue
                        }
                        
                        do {
                            let payload = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                            
                            if let payload = payload,
                               let listener = self.messageListeners[topic] {
                                let callbackMessage = Message(
                                    id: payload["id"] as? String ?? "",
                                    timestamp: payload["timestamp"] as? Int64 ?? 0,
                                    content: payload["content"] as? String ?? "",
                                    clientId: payload["client_id"] as? String ?? ""
                                )
                                
                                listener.onMessage(callbackMessage.toDictionary())
                            } else if self.isDebug {
                                print("Invalid message payload format or no listener found")
                            }
                        } catch {
                            if self.isDebug {
                                print("Error processing message: \(error)")
                            }
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
            "batch": 10,  // Reduced batch size for testing
            "no_wait": true  // Don't wait for messages if none available
        ]
        
        let batchData = try JSONSerialization.data(withJSONObject: batchRequest)
        
        // Try to fetch messages multiple times
        for _ in 0..<10 {  // Maximum 10 batches
            do {
                let response = try await natsConnection.request(
                    batchData,
                    subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.MSG.NEXT.\(streamName).\(consumerName)",
                    timeout: 1.0  // Reduced timeout since we're not waiting
                )
                
                if isDebug {
                    if let data = response.payload,
                       let str = String(data: data, encoding: .utf8) {
                        print("Message response: \(str)")
                    }
                }
                
                guard let messageData = response.payload,
                      let messageDict = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
                    continue
                }
                
                // Get timestamp from either start or message.timestamp
                var timestamp: Int?
                if let start = messageDict["start"] as? Int {
                    timestamp = start
                } else if let message = messageDict["message"] as? [String: Any],
                          let messageTimestamp = message["timestamp"] as? TimeInterval {
                    timestamp = Int(messageTimestamp)
                }
                
                guard let timestamp = timestamp else {
                    continue
                }
                
                // Check if message timestamp is within range
                if timestamp >= startTimestamp && (endTimestamp == nil || timestamp <= endTimestamp!) {
                    messages.append(messageDict)
                }
                
                // Acknowledge the message
                if let headers = response.headers,
                   let replyTo = try? headers[NatsHeaderName("Nats-Reply-To")]?.description {
                    try await natsConnection.publish(Data(), subject: replyTo)
                }
                
            } catch {
                if isDebug {
                    print("Error fetching message: \(error)")
                }
                break
            }
        }
        
        // Delete the consumer
        _ = try await natsConnection.request(
            Data(),
            subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.DELETE.\(streamName).\(consumerName)"
        )
        
        if isDebug {
            print("Retrieved \(messages.count) messages")
        }
        
        return messages
    }
    
    /// Subscribe to all pending topics that were initialized before connection
    private func subscribeToTopics() async throws {
        guard !pendingTopics.isEmpty else { return }
        
        for topic in pendingTopics {
            do {
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
                                guard let data = message.payload else {
                                    if self.isDebug {
                                        print("Message payload is nil")
                                    }
                                    continue
                                }
                                
                                do {
                                    let payload = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                                    
                                    if let payload = payload,
                                       let listener = self.messageListeners[topic] {
                                        let callbackMessage = Message(
                                            id: payload["id"] as? String ?? "",
                                            timestamp: payload["timestamp"] as? Int64 ?? 0,
                                            content: payload["content"] as? String ?? "",
                                            clientId: payload["client_id"] as? String ?? ""
                                        )
                                        
                                        listener.onMessage(callbackMessage.toDictionary())
                                    } else if self.isDebug {
                                        print("Invalid message payload format or no listener found")
                                    }
                                } catch {
                                    if self.isDebug {
                                        print("Error processing message: \(error)")
                                    }
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
                }
            } catch {
                if isDebug {
                    print("Error subscribing to topic \(topic): \(error)")
                }
            }
        }
        
        // Clear pending topics after processing
        pendingTopics.removeAll()
    }
}
