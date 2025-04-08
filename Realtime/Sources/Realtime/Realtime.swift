// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@preconcurrency import Nats
import Dispatch
import SwiftMsgpack

/// System events for internal SDK events
public enum SystemEvent: String, CaseIterable {
    case connected = "sdk.connected"
    case disconnected = "sdk.disconnected"
    case reconnecting = "sdk.reconnecting"
    case reconnected = "sdk.reconnected"
    case messageResend = "sdk.message_resend"
    
    /// Reserved system topics that cannot be used by clients
    static var reservedTopics: Set<String> {
        return Set(SystemEvent.allCases.map { $0.rawValue })
    }
}

/// Protocol for receiving messages from the Realtime service
public protocol MessageListener {
    func onMessage(_ message: [String: Any])
}

@preconcurrency public final class Realtime: @unchecked Sendable {
    // MARK: - Properties
    
    var natsConnection: NatsClient
    private var servers: [URL] = []
    private let apiKey: String
    private let secret: String
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
    
    private var streamSubjects: [String: Set<String>] = [:]
    private let streamName: String = "default_stream"
    private let topicPrefix: String = "relay_stream"
    
    // MARK: - Initialization
    
    /// Initialize a new Realtime instance with authentication
    /// - Parameters:
    ///   - apiKey: The API key for authentication
    ///   - secret: The secret key for authentication
    /// - Throws: RelayError.invalidCredentials if credentials are invalid
    public init(apiKey: String, secret: String) throws {
        self.apiKey = apiKey
        self.secret = secret
        self.clientId = "ios_\(UUID().uuidString)"
        self.messageStorage = MessageStorage()
        
        // Configure NATS connection with required settings
        let options = NatsClientOptions()
            .maxReconnects(1200)
            .reconnectWait(1000)
        
        self.natsConnection = options.build()
        
        try validateCredentials(apiKey: apiKey, secret: secret)
    }
    
    /// Prepare the Realtime instance with configuration
    /// - Parameters:
    ///   - staging: Whether to use staging environment
    ///   - opts: Configuration options including debug mode
    /// - Throws: RelayError.invalidOptions if options are invalid
    public func prepare(staging: Bool, opts: [String: Any]) throws {
        guard !opts.isEmpty else {
            throw RelayError.invalidOptions("Options must be provided")
        }
        
        self.isDebug = opts["debug"] as? Bool ?? false
        self.isStaging = staging
        
        // Configure server URLs based on staging flag
        let baseUrl = staging ? "0.0.0.0" : "api.relay-x.io"
        self.servers = (4221...4226).map { port in
            URL(string: "nats://\(baseUrl):\(port)")!
        }
        
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
    
    deinit {
        // Clean up credentials file
        if let path = credentialsPath {
            try? FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Public Methods
    
    private func validateCredentials(apiKey: String?, secret: String?) throws {
        if apiKey == nil && secret == nil {
            throw RelayError.invalidCredentials("Both API key and secret are missing. Please provide both credentials.")
        } else if apiKey == nil {
            throw RelayError.invalidCredentials("API key is missing. Please provide a valid API key.")
        } else if secret == nil {
            throw RelayError.invalidCredentials("Secret is missing. Please provide a valid secret.")
        } else if apiKey!.isEmpty && secret!.isEmpty {
            throw RelayError.invalidCredentials("Both API key and secret are empty. Please provide valid credentials.")
        } else if apiKey!.isEmpty {
            throw RelayError.invalidCredentials("API key is empty. Please provide a valid API key.")
        } else if secret!.isEmpty {
            throw RelayError.invalidCredentials("Secret is empty. Please provide a valid secret.")
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
        try await resendStoredMessages()
        
        if self.isDebug {
            print("✅ Connected and ready")
        }
    }
    
    /// Get the namespace for the current user
    private func getNamespace() async throws -> String {
        guard !self.apiKey.isEmpty else {
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
            // Request namespace from service with correct subject
            let response = try await natsConnection.request(
                requestData,
                subject: "accounts.user.get_namespace",
                timeout: 5.0
            )
            
            guard let responseData = response.payload else {
                throw RelayError.invalidPayload("Response payload is missing")
            }
            
            if self.isDebug {
                if let responseStr = String(data: responseData, encoding: .utf8) {
                    print("Namespace response: \(responseStr)")
                }
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let data = json["data"] as? [String: Any],
                  let namespace = data["namespace"] as? String else {
                throw RelayError.invalidPayload("Invalid response format or missing namespace")
            }
            
            if namespace.isEmpty {
                throw RelayError.invalidNamespace("Namespace cannot be empty")
            }
            
            return namespace
        } catch {
            if self.isDebug {
                print("Failed to get namespace: \(error)")
            }
            throw RelayError.invalidNamespace("Failed to retrieve namespace: \(error)")
        }
    }
    
    /// Create or get a JetStream stream
    private func createOrGetStream(for topic: String) async throws {
        guard isConnected else {
            throw RelayError.notConnected("Not connected to NATS server")
        }
        
        // Get namespace if not set
        if namespace == nil {
            namespace = try await getNamespace()
        }
        
        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available")
        }
        
        // Format stream name as namespace_stream
        let streamName = "\(currentNamespace)_stream"
        
        if isDebug {
            print("Checking stream existence: \(streamName)")
        }
        
        // Format the subject for this topic
        let formattedSubject = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)
        
        // If stream exists in our cache, check if we need to add the subject
        if existingStreams.contains(streamName) {
            // Get stream info to check subjects
            let streamInfoRequest: [String: Any] = ["name": streamName]
            let streamInfoResponse = try await natsConnection.request(
                try JSONSerialization.data(withJSONObject: streamInfoRequest),
                subject: "\(NatsConstants.JetStream.apiPrefix).STREAM.INFO.\(streamName)",
                timeout: 5.0
            )
            
            if let data = streamInfoResponse.payload,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let config = json["config"] as? [String: Any],
               var subjects = config["subjects"] as? [String] {
                
                // Check if our subject is already included
                if !subjects.contains(formattedSubject) {
                    // Add the new subject and ensure uniqueness
                    subjects.append(formattedSubject)
                    subjects = Array(Set(subjects)) // Make subjects unique
                    
                    // Update stream config with new subjects
                    let updateConfig: [String: Any] = [
                        "name": streamName,
            "subjects": subjects,
                        "retention": "limits",
                        "max_consumers": -1,
                        "max_msgs": -1,
                        "max_bytes": -1,
                        "max_age": 0,
                        "storage": "file",
                        "discard": "old",
                        "num_replicas": 3  // Updated to 3 replicas
                    ]
                    
                    // Update the stream
                    let updateResponse = try await natsConnection.request(
                        try JSONSerialization.data(withJSONObject: updateConfig),
                        subject: "\(NatsConstants.JetStream.apiPrefix).STREAM.UPDATE.\(streamName)"
                    )
                    
                    if isDebug {
                        if let data = updateResponse.payload,
                           let str = String(data: data, encoding: .utf8) {
                            print("Stream update response: \(str)")
                        }
                    }
                }
            }
            return
        }
        
        // Create new stream with initial subject
        let createConfig: [String: Any] = [
            "name": streamName,
            "subjects": [formattedSubject],
            "retention": "limits",
            "max_consumers": -1,
            "max_msgs": -1,
            "max_bytes": -1,
            "max_age": 0,
            "storage": "file",
            "discard": "old",
            "num_replicas": 3  // Set to 3 replicas for new streams
        ]
        
        let createResponse = try await natsConnection.request(
            try JSONSerialization.data(withJSONObject: createConfig),
            subject: "\(NatsConstants.JetStream.apiPrefix).STREAM.CREATE.\(streamName)"
        )
        
        if isDebug {
            if let data = createResponse.payload,
               let str = String(data: data, encoding: .utf8) {
                print("Stream creation response: \(str)")
            }
        }
        
        // Add to existing streams
        existingStreams.insert(streamName)
    }
    
    /// Update references to ensureStreamExists to use createOrGetStream
    private func ensureStreamExists(for topic: String) async throws {
        try await createOrGetStream(for: topic)
    }
    
    /// Disconnect from the NATS server
    public func disconnect() async throws {
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
    ///   - message: The message to publish (String, number, JSON object)
    /// - Throws: TopicValidationError if topic is invalid
    /// - Throws: RelayError.invalidPayload if message is invalid
    public func publish(topic: String, message: Any) async throws -> Bool {
        // Validate topic for publishing
        try TopicValidator.validate(topic, forPublishing: true)
        
        // Encode the message with MessagePack
        let encoder = MsgPackEncoder()
        let encodedMessage: Data
        do {
            if let intMessage = message as? Int {
                encodedMessage = try encoder.encode(intMessage)
            } else if let jsonData = try? JSONSerialization.data(withJSONObject: message) {
                encodedMessage = try encoder.encode(jsonData)
            } else if let stringMessage = message as? String {
                encodedMessage = try encoder.encode(stringMessage)
            } else {
                throw RelayError.invalidPayload("Message must be a valid JSON object, string, or integer")
            }
        } catch {
            throw RelayError.invalidPayload("Failed to encode message with MessagePack: \(error)")
        }
        
        // If not connected, store message locally
        if !isConnected {
            let finalMessage: [String: Any] = [
                "client_id": clientId,
                "id": UUID().uuidString,
                "room": topic,
                "message": encodedMessage.base64EncodedString(),
                "start": Int(Date().timeIntervalSince1970)
            ]
            messageStorage.storeMessage(topic: topic, message: finalMessage)
            if isDebug {
                print("💾 Stored message locally (offline): \(finalMessage)")
            }
            return true
        }
        
        // Get namespace if not set
        if namespace == nil {
            namespace = try await getNamespace()
        }
        
        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available")
        }
        
        // Ensure stream exists
        try await ensureStreamExists(for: topic)
        
        // Create the final message format
        let finalMessage: [String: Any] = [
            "client_id": clientId,
            "id": UUID().uuidString,
            "room": topic,
            "message": encodedMessage.base64EncodedString(),
            "start": Int(Date().timeIntervalSince1970)
        ]
        
        let finalData = try JSONSerialization.data(withJSONObject: finalMessage)
        
        // Format topic with namespace
        let finalTopic = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)
        
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
    
    func resendStoredMessages() async throws {
        let storedMessages = messageStorage.getStoredMessages()
        if storedMessages.isEmpty { return }
        
        print("📤 Resending \(storedMessages.count) stored messages...")
        
        for message in storedMessages {
            if let messageId = message.message["id"] as? String {
                // Try to publish the message
                let success = try await publish(topic: message.topic, message: message.message)
                if success {
                    print("✅ Resent message to topic: \(message.topic)")
                    messageStorage.updateMessageStatus(topic: message.topic, messageId: messageId, resent: true)
                }
            }
        }
        
        // Get final message statuses and notify listeners
        let messageStatuses = messageStorage.getMessageStatuses()
        if !messageStatuses.isEmpty {
            let statusMessage: [String: Any] = ["messages": messageStatuses]
            if let listener = messageListeners[SystemEvent.messageResend.rawValue] {
                listener.onMessage(statusMessage)
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
        try TopicValidator.validate(topic)
        
        // Store the listener
        messageListeners[topic] = listener
        
        // If not connected, add to pending topics
        guard isConnected else {
            pendingTopics.insert(topic)
            return
        }
        
        // Get namespace if not set
        if namespace == nil {
            namespace = try await getNamespace()
        }
        
        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available")
        }
        
        // Ensure stream exists
        try await ensureStreamExists(for: topic)
        
        let finalTopic = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)
        
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
                            // Parse the JSON wrapper
                            guard let payload = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                                  let listener = self.messageListeners[topic] else {
                                if self.isDebug {
                                    print("Invalid message format or no listener found")
                                }
                                continue
                            }
                            
                            // Extract and decode the MessagePack content
                            guard let base64Message = payload["message"] as? String,
                                  let messageData = Data(base64Encoded: base64Message) else {
                                if self.isDebug {
                                    print("Invalid message format: missing or invalid message content")
                                }
                                continue
                            }
                            
                            // Decode the MessagePack data
                            let decoder = MsgPackDecoder()
                            let messageContent: Any
                            
                            do {
                                // First try to decode as JSON data
                                if let jsonData = try? decoder.decode(Data.self, from: messageData),
                                   let jsonContent = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                    messageContent = jsonContent
                                }
                                // Then try as a string
                                else if let stringContent = try? decoder.decode(String.self, from: messageData) {
                                    messageContent = stringContent
                                }
                                // Then try as an integer
                                else if let intContent = try? decoder.decode(Int.self, from: messageData) {
                                    messageContent = intContent
                                }
                                else {
                                    throw RelayError.invalidPayload("Unknown MessagePack content type")
                                }
                            } catch {
                                if self.isDebug {
                                    print("Failed to decode MessagePack content: \(error)")
                                }
                                continue
                            }
                            
                            // Create the final message dictionary
                            let messageDict: [String: Any] = [
                                "id": payload["id"] as? String ?? "",
                                "client_id": payload["client_id"] as? String ?? "",
                                "timestamp": payload["start"] as? Int ?? 0,
                                "message": messageContent
                            ]
                            
                            // Notify the listener
                            listener.onMessage(messageDict)
                            
                            if self.isDebug {
                                print("\n📨 [\(topic)] Received message via listener:")
                                print("   From: \(messageDict["client_id"] ?? "unknown")")
                                print("   Content: \(messageContent)")
                                
                                if let content = messageContent as? [String: Any] {
                                    print("\n📦 Decoded Message Content:")
                                    print("   Type: \(content["type"] ?? "unknown")")
                                    print("   Content: \(content["content"] ?? "none")")
                                    if let timestamp = content["timestamp"] {
                                        print("   Timestamp: \(timestamp)")
                                    }
                                }
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
        // Validate topic
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

        // Get namespace if not set
        if namespace == nil {
            namespace = try await getNamespace()
        }
        
        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available")
        }

        // Format stream name as namespace_stream
        let streamName = "\(currentNamespace)_stream"
        
        if isDebug {
            print("Using stream name for history: \(streamName)")
        }

        // Ensure stream exists before proceeding
        try await ensureStreamExists(for: topic)

        // Create consumer configuration with minimal settings
        let consumerConfig: [String: Any] = [
            "stream_name": streamName,
            "config": [
                "name": "history_\(UUID().uuidString)",
                "filter_subject": NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace),
                "deliver_policy": "all",
                "ack_policy": "none",  // Changed back to none for simplicity
                "max_deliver": 1,
                "num_replicas": 1
            ]
        ]
        
        if isDebug {
            print("Creating consumer with config:", String(data: try JSONSerialization.data(withJSONObject: consumerConfig), encoding: .utf8) ?? "")
        }
        
        // Create consumer
        let createResponse = try await natsConnection.request(
            try JSONSerialization.data(withJSONObject: consumerConfig),
            subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.CREATE.\(streamName)",
            timeout: 10.0
        )
        
        if isDebug {
            if let data = createResponse.payload,
               let str = String(data: data, encoding: .utf8) {
                print("Consumer creation response:", str)
            }
        }
        
        guard let payload = createResponse.payload,
              let response = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let name = response["name"] as? String else {
            throw RelayError.invalidResponse
        }
        
        // Request messages in batches
        var messages: [[String: Any]] = []
        var hasMore = true
        var batchCount = 1
        
        while hasMore && batchCount <= 10 { // Limit to 10 batches to prevent infinite loops
            let batchRequest: [String: Any] = [
                "batch": 10,  // Reduced batch size
                "no_wait": true
            ]
            
            let batchData = try JSONSerialization.data(withJSONObject: batchRequest)
            
            if isDebug {
                print("Requesting batch \(batchCount) with config:", String(data: batchData, encoding: .utf8) ?? "")
            }
            
            do {
                let response = try await natsConnection.request(
                    batchData,
                    subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.MSG.NEXT.\(streamName).\(name)",
                    timeout: 2.0  // Reduced timeout for faster failure
                )
                
                if let data = response.payload {
                    if isDebug {
                        print("Batch response data:", String(data: data, encoding: .utf8) ?? "no data")
                    }
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check if this is a "no messages" response
                        if let description = json["description"] as? String,
                           description.contains("no messages") {
                            if isDebug {
                                print("No more messages available")
                            }
                            hasMore = false
                            continue
                        }
                        
                        // Check message timestamp
                        if let timestamp = json["start"] as? Int {
                            let messageDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                            let isAfterStart = messageDate >= startDate
                            let isBeforeEnd = endDate.map { messageDate <= $0 } ?? true
                            
                            if isAfterStart && isBeforeEnd {
                                messages.append(json)
                                if isDebug {
                                    print("Added message with timestamp:", timestamp)
                                }
                            }
                        }
                    }
                } else {
                    if isDebug {
                        print("No payload in batch response")
                    }
                    hasMore = false
                }
            } catch {
                if isDebug {
                    print("Error requesting batch: \(error)")
                }
                hasMore = false
            }
            
            batchCount += 1
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds delay
        }
        
        // Delete the consumer
        do {
            let deleteResponse = try await natsConnection.request(
                Data(),
                subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.DELETE.\(streamName).\(name)",
                timeout: 5.0
            )
            
            if isDebug {
                if let data = deleteResponse.payload,
                   let str = String(data: data, encoding: .utf8) {
                    print("Successfully deleted consumer: \(name)")
                    print("Delete response:", str)
                }
            }
        } catch {
            if isDebug {
                print("Error deleting consumer: \(error)")
            }
        }
        
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
                // Get namespace if not set
                if namespace == nil {
                    namespace = try await getNamespace()
                }
                
                guard let currentNamespace = namespace else {
                    throw RelayError.invalidNamespace("Namespace not available")
                }
                
                // Ensure stream exists
                try await ensureStreamExists(for: topic)
                
                let finalTopic = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)
                
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
                                    // Parse the JSON wrapper
                                    guard let payload = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                                          let listener = self.messageListeners[topic] else {
                                        if self.isDebug {
                                            print("Invalid message format or no listener found")
                                        }
                                        continue
                                    }
                                    
                                    // Extract and decode the MessagePack content
                                    guard let base64Message = payload["message"] as? String,
                                          let messageData = Data(base64Encoded: base64Message) else {
                                        if self.isDebug {
                                            print("Invalid message format: missing or invalid message content")
                                        }
                                        continue
                                    }
                                    
                                    // Decode the MessagePack data
                                    let decoder = MsgPackDecoder()
                                    let messageContent: Any
                                    
                                    do {
                                        // First try to decode as JSON data
                                        if let jsonData = try? decoder.decode(Data.self, from: messageData),
                                           let jsonContent = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                            messageContent = jsonContent
                                        }
                                        // Then try as a string
                                        else if let stringContent = try? decoder.decode(String.self, from: messageData) {
                                            messageContent = stringContent
                                        }
                                        // Then try as an integer
                                        else if let intContent = try? decoder.decode(Int.self, from: messageData) {
                                            messageContent = intContent
                                        }
                                        else {
                                            throw RelayError.invalidPayload("Unknown MessagePack content type")
                                        }
                                    } catch {
                                        if self.isDebug {
                                            print("Failed to decode MessagePack content: \(error)")
                                        }
                                        continue
                                    }
                                    
                                    // Create the final message dictionary
                                    let messageDict: [String: Any] = [
                                        "id": payload["id"] as? String ?? "",
                                        "client_id": payload["client_id"] as? String ?? "",
                                        "timestamp": payload["start"] as? Int ?? 0,
                                        "message": messageContent
                                    ]
                                    
                                    // Notify the listener
                                    listener.onMessage(messageDict)
                                    
                                    if self.isDebug {
                                        print("\n📨 [\(topic)] Received message via listener:")
                                        print("   From: \(messageDict["client_id"] ?? "unknown")")
                                        print("   Content: \(messageContent)")
                                        
                                        if let content = messageContent as? [String: Any] {
                                            print("\n📦 Decoded Message Content:")
                                            print("   Type: \(content["type"] ?? "unknown")")
                                            print("   Content: \(content["content"] ?? "none")")
                                            if let timestamp = content["timestamp"] {
                                                print("   Timestamp: \(timestamp)")
                                            }
                                        }
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
    
    private func ensureStreamExists() async throws {
        guard isConnected else {
            throw RelayError.notConnected("Not connected to NATS server")
        }
        
        let streamConfig: [String: Any] = [
            "name": streamName,
            "subjects": ["\(topicPrefix).>"],
            "retention": "limits",
            "max_consumers": -1,
            "max_msgs": 1_000_000,
            "max_bytes": 1_000_000_000,
            "max_age": 86400_000_000_000,  // 24 hours in nanoseconds
            "max_msg_size": 1_000_000,
            "storage": "file",
            "num_replicas": 1
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: streamConfig)
        
        // Try to create the stream first
        let createResponse = try? await natsConnection.request(
            jsonData,
            subject: "\(NatsConstants.JetStream.apiPrefix).STREAM.CREATE.\(streamName)",
            timeout: 5.0
        )
        
        if createResponse == nil {
            // If creation fails, try to update the stream
            _ = try? await natsConnection.request(
                jsonData,
                subject: "\(NatsConstants.JetStream.apiPrefix).STREAM.UPDATE.\(streamName)",
                timeout: 5.0
            )
        }
    }
}
