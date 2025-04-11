// The Swift Programming Language
// https://docs.swift.org/swift-book

import Dispatch
import Foundation
@preconcurrency import JetStream
@preconcurrency import Nats
import SwiftMsgpack

@preconcurrency public final class Realtime: @unchecked Sendable {
    // MARK: - Properties

    private var jetStream: JetStreamContext?
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
        // Don't initialize jetStream here as we need a connected client

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
        // Don't initialize jetStream here as we need a connected client
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
            throw RelayError.invalidCredentials(
                "Both API key and secret are missing. Please provide both credentials.")
        } else if apiKey == nil {
            throw RelayError.invalidCredentials(
                "API key is missing. Please provide a valid API key.")
        } else if secret == nil {
            throw RelayError.invalidCredentials("Secret is missing. Please provide a valid secret.")
        } else if apiKey!.isEmpty && secret!.isEmpty {
            throw RelayError.invalidCredentials(
                "Both API key and secret are empty. Please provide valid credentials.")
        } else if apiKey!.isEmpty {
            throw RelayError.invalidCredentials("API key is empty. Please provide a valid API key.")
        } else if secret!.isEmpty {
            throw RelayError.invalidCredentials("Secret is empty. Please provide a valid secret.")
        }
    }

    /// Connect to the NATS server
    public func connect() async throws {
        try validateCredentials(apiKey: apiKey, secret: secret)

        if self.isDebug {
            print("🔄 Connecting and retrieving namespace...")
        }

        // Connect to NATS server first
        try await natsConnection.connect()
        self.isConnected = true

        // Initialize JetStream after connection
        self.jetStream = JetStreamContext(client: natsConnection)

        if self.isDebug {
            print("✅ Connected to NATS server")
            print("✅ JetStream context initialized")
        }

        // Get namespace - this is required for operation
        let namespace = try await getNamespace()
        guard !namespace.isEmpty else {
            throw RelayError.invalidNamespace("Namespace cannot be empty")
        }
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
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
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

            guard
                let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let data = json["data"] as? [String: Any],
                let namespace = data["namespace"] as? String
            else {
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

        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available - must be connected first")
        }

        // Format stream name as namespace_stream
        let streamName = "\(currentNamespace)_stream"

        if isDebug {
            print("\n🔄 Stream Management:")
            print("   Topic: \(topic)")
            print("   Namespace: \(currentNamespace)")
            print("   Stream Name: \(streamName)")
        }

        // Format the subject for this topic
        let formattedSubject = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)

        if isDebug {
            print("   Formatted Subject: \(formattedSubject)")
        }

        do {
            if isDebug {
                print("   Checking for existing stream...")
            }

            // Try to get existing stream
            let stream = try await js.getStream(name: streamName)

            if isDebug {
                print("   ✅ Stream exists")
                print("   Current subjects: \(stream?.info.config.subjects ?? [])")
            }

            // Get current subjects
            var subjects = stream?.info.config.subjects ?? []

            // Add new subject if not exists
            if !subjects.contains(formattedSubject) {
                if isDebug {
                    print("   Adding new subject to stream...")
                }

                subjects.append(formattedSubject)

                // Update stream with new subjects
                let config = StreamConfig(
                    name: streamName,
                    subjects: subjects,
                    retention: .limits,
                    maxConsumers: -1,
                    maxMsgs: -1,
                    maxBytes: -1,
                    discard: .old,
                    maxAge: NanoTimeInterval(0),
                    storage: .file,
                    replicas: 3
                )

                try await js.updateStream(cfg: config)

                if isDebug {
                    print("   ✅ Stream updated with new subject")
                    print("   Updated subjects: \(subjects)")
                }
            } else if isDebug {
                print("   ℹ️ Subject already exists in stream")
            }
        } catch {
            if isDebug {
                print("   ❌ Stream not found, creating new one...")
            }

            // Stream doesn't exist, create new one
            let config = StreamConfig(
                name: streamName,
                subjects: [formattedSubject],
                retention: .limits,
                maxConsumers: -1,
                maxMsgs: -1,
                maxBytes: -1,
                discard: .old,
                maxAge: NanoTimeInterval(0),
                storage: .file,
                replicas: 3
            )

            try await js.createStream(cfg: config)

            if isDebug {
                print("   ✅ New stream created")
                print("   Initial subjects: \([formattedSubject])")
            }
        }

        // Add to existing streams cache
        existingStreams.insert(streamName)

        if isDebug {
            print("   📝 Added to existing streams cache")
            print("   Current cached streams: \(existingStreams)")
            print("✅ Stream management completed\n")
        }
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

        // Clear JetStream context
        self.jetStream = nil

        try await natsConnection.close()
        self.isConnected = false

        if isDebug {
            print("Disconnected from NATS server")
            print("JetStream context cleared")
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

        // Create message content
        let messageContent: RealtimeMessage.MessageContent
        if let string = message as? String {
            messageContent = .string(string)
        } else if let integer = message as? Int {
            messageContent = .integer(integer)
        } else if let json = message as? [String: Any] {
            let jsonData = try JSONSerialization.data(withJSONObject: json)
            messageContent = .json(jsonData)
        } else {
            throw RelayError.invalidPayload(
                "Message must be a valid JSON object, string, or integer")
        }

        // Create the final message
        let finalMessage = RealtimeMessage(
            clientId: clientId,
            id: UUID().uuidString,
            room: topic,
            message: messageContent,
            start: Int(Date().timeIntervalSince1970)
        )

        // If not connected, store message locally
        if !isConnected {
            let messageDict: [String: Any] = [
                "client_id": finalMessage.clientId,
                "id": finalMessage.id,
                "room": finalMessage.room,
                "message": message,
                "start": finalMessage.start,
            ]

            messageStorage.storeMessage(topic: topic, message: messageDict)

            if isDebug {
                print("💾 Stored message locally (offline): \(messageDict)")
            }
            return true
        }

        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available - must be connected first")
        }

        // Ensure stream exists
        try await ensureStreamExists(for: topic)

        // Encode the message with MessagePack
        let encoder = MsgPackEncoder()
        let encodedMessage: Data
        do {
            encodedMessage = try encoder.encode(finalMessage)
        } catch {
            throw RelayError.invalidPayload("Failed to encode message with MessagePack: \(error)")
        }

        // Format topic with namespace
        let finalTopic = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)

        // Publish using JetStream
        do {
            let ackFuture = try await js.publish(finalTopic, message: encodedMessage)
            let ack = try await ackFuture.wait()

            if isDebug {
                print("Published message to topic: \(finalTopic)")
                print("Message payload: \(finalMessage)")
                print("JetStream ACK: \(ack)")
            }
            return true
        } catch {
            if isDebug {
                print("Failed to publish message: \(error)")
            }
            return false
        }
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
                    messageStorage.updateMessageStatus(
                        topic: message.topic, messageId: messageId, resent: true)
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

        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available - must be connected first")
        }

        // Ensure stream exists
        try await ensureStreamExists(for: topic)

        let finalTopic = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)

        // Create subscription if it doesn't exist
        if subscriptions[topic] == nil {
            do {
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
                                // Decode the MessagePack data
                                let decoder = MsgPackDecoder()
                                let decodedMessage = try decoder.decode(
                                    RealtimeMessage.self, from: data)

                                // Convert to dictionary for listener
                                let messageDict: [String: Any] = [
                                    "client_id": decodedMessage.clientId,
                                    "id": decodedMessage.id,
                                    "room": decodedMessage.room,
                                    "message": try {
                                        switch decodedMessage.message {
                                        case .string(let string):
                                            return string
                                        case .integer(let integer):
                                            return integer
                                        case .json(let data):
                                            return try JSONSerialization.jsonObject(with: data)
                                        }
                                    }(),
                                    "start": decodedMessage.start,
                                ]

                                // Notify the listener
                                if let listener = self.messageListeners[topic] {
                                    listener.onMessage(messageDict)

                                    if self.isDebug {
                                        print("\n📨 [\(topic)] Received message via listener:")
                                        print("   From: \(decodedMessage.clientId)")
                                        print("   Content: \(messageDict["message"] ?? "none")")
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
                        // Clean up resources on error
                        self.subscriptions.removeValue(forKey: topic)
                        self.messageTasks.removeValue(forKey: topic)
                    }
                }

                // Store task reference
                messageTasks[topic] = task

                if isDebug {
                    print("✅ Subscribed to topic: \(topic)")
                }
            } catch {
                // Clean up on subscription failure
                messageListeners.removeValue(forKey: topic)
                throw RelayError.subscriptionFailed(
                    "Failed to subscribe to topic \(topic): \(error)")
            }
        }
    }

    /// Unsubscribe from a topic and clean up associated resources
    /// - Parameter topic: The topic to unsubscribe from
    /// - Returns: true if successfully unsubscribed, false otherwise
    /// - Throws: TopicValidationError if topic is invalid
    public func off(topic: String) async throws -> Bool {
        try TopicValidator.validate(topic)

        var success = false

        // Cancel and remove message handling task
        if let task = messageTasks[topic] {
            task.cancel()
            messageTasks.removeValue(forKey: topic)
            success = true
        }

        // Remove message listener
        messageListeners.removeValue(forKey: topic)

        // Unsubscribe from NATS and remove subscription
        if let subscription = subscriptions[topic] {
            do {
                try await subscription.unsubscribe()
                subscriptions.removeValue(forKey: topic)
                success = true

                if isDebug {
                    print("✅ Unsubscribed from topic: \(topic)")
                }
            } catch {
                if isDebug {
                    print("Error unsubscribing from topic \(topic): \(error)")
                }
                throw RelayError.unsubscribeFailed(
                    "Failed to unsubscribe from topic \(topic): \(error)")
            }
        }

        return success
    }

    /// Get a list of past messages between a start time and an optional end time
    /// - Parameters:
    ///   - topic: The topic to get messages from
    ///   - startDate: The start date for message retrieval (required)
    ///   - endDate: The end date for message retrieval (optional)
    /// - Returns: An array of messages matching the criteria
    /// - Throws: TopicValidationError if topic is invalid
    /// - Throws: RelayError.invalidDate if dates are invalid
    public func history(topic: String, startDate: Date, endDate: Date? = nil) async throws
        -> [[String: Any]]
    {
        // IOS-FUNC-08-2: Validate topic
        try TopicValidator.validate(topic)

        // IOS-FUNC-08-3: Validate start date
        guard startDate != Date.distantPast else {
            throw RelayError.invalidDate("Start date cannot be null or invalid")
        }

        // IOS-FUNC-08-4: Validate end date if provided
        if let endDate = endDate {
            guard endDate > startDate else {
                throw RelayError.invalidDate("End date must be after start date")
            }
        }

        // IOS-FUNC-08-5: Return empty array if not connected
        guard isConnected else {
            return []
        }

        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available - must be connected first")
        }

        // IOS-FUNC-05-10 & IOS-FUNC-08-6: Format stream name and topic
        let streamName = "\(currentNamespace)_stream"
        let formattedTopic = NatsConstants.Topics.formatTopic(topic, namespace: currentNamespace)

        if isDebug {
            print("Using stream name for history: \(streamName)")
            print("Formatted topic: \(formattedTopic)")
        }

        // Ensure stream exists before proceeding
        try await ensureStreamExists(for: topic)

        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        // IOS-FUNC-08-7: Use JetStream to get messages
        // Create a consumer config for message retrieval
        let consumerName = "temp_consumer_\(UUID().uuidString)"
        let consumerConfig = ConsumerConfig(
            name: consumerName,
            durable: nil,
            deliverPolicy: .all,
            ackPolicy: .none,
            filterSubject: formattedTopic,  // This is the actual topic we published to
            replayPolicy: .instant
        )

        if isDebug {
            print("Creating consumer with config: \(consumerConfig)")
            print("Using formatted topic for filtering: \(formattedTopic)")
        }

        // Create consumer and fetch messages
        var messages: [[String: Any]] = []
        do {
            let consumer = try await js.createConsumer(stream: streamName, cfg: consumerConfig)

            // Fetch messages in batches
            let fetchResult = try await consumer.fetch(batch: 100, expires: 5)

            for try await msg in fetchResult {
                // Access the message payload correctly
                guard let payload = msg.payload else {
                    if isDebug {
                        print("Message payload is nil")
                    }
                    continue
                }

                // Decode MessagePack data
                let decoder = MsgPackDecoder()
                if let decodedMessage = try? decoder.decode(RealtimeMessage.self, from: payload) {
                    // Convert message timestamp to Date for comparison
                    let messageDate = Date(
                        timeIntervalSince1970: TimeInterval(decodedMessage.start))

                    // Check if message is within the requested time range
                    let isAfterStart = messageDate >= startDate
                    let isBeforeEnd = endDate.map { messageDate <= $0 } ?? true

                    if isAfterStart && isBeforeEnd {
                        // Convert message to dictionary format
                        let messageDict: [String: Any] = [
                            "client_id": decodedMessage.clientId,
                            "id": decodedMessage.id,
                            "room": decodedMessage.room,
                            "message": try {
                                switch decodedMessage.message {
                                case .string(let str): return str
                                case .integer(let int): return int
                                case .json(let data):
                                    return try JSONSerialization.jsonObject(with: data)
                                }
                            }(),
                            "start": decodedMessage.start,
                        ]
                        messages.append(messageDict)

                        if isDebug {
                            print("Added message: \(messageDict)")
                        }
                    }
                }
            }

            // Clean up the consumer
            try await js.deleteConsumer(stream: streamName, name: consumerName)

        } catch {
            if isDebug {
                print("Error fetching messages: \(error)")
            }
            // IOS-FUNC-08-10: Return empty array if no messages found
            return []
        }

        if isDebug {
            print("Retrieved \(messages.count) messages")
        }

        return messages
    }

    /// Subscribe to all pending topics that were initialized before connection
    private func subscribeToTopics() async throws {
        guard !pendingTopics.isEmpty else { return }

        var errors: [Error] = []

        for topic in pendingTopics {
            do {
                guard let currentNamespace = namespace else {
                    throw RelayError.invalidNamespace(
                        "Namespace not available - must be connected first")
                }

                // Ensure stream exists
                try await ensureStreamExists(for: topic)

                let finalTopic = NatsConstants.Topics.formatTopic(
                    topic, namespace: currentNamespace)

                // Create subscription if it doesn't exist
                if subscriptions[topic] == nil {
                    do {
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
                                        // Decode the MessagePack data
                                        let decoder = MsgPackDecoder()
                                        let decodedMessage = try decoder.decode(
                                            RealtimeMessage.self, from: data)

                                        // Convert to dictionary for listener
                                        let messageDict: [String: Any] = [
                                            "client_id": decodedMessage.clientId,
                                            "id": decodedMessage.id,
                                            "room": decodedMessage.room,
                                            "message": try {
                                                switch decodedMessage.message {
                                                case .string(let string):
                                                    return string
                                                case .integer(let integer):
                                                    return integer
                                                case .json(let data):
                                                    return try JSONSerialization.jsonObject(
                                                        with: data)
                                                }
                                            }(),
                                            "start": decodedMessage.start,
                                        ]

                                        // Notify the listener
                                        if let listener = self.messageListeners[topic] {
                                            listener.onMessage(messageDict)

                                            if self.isDebug {
                                                print(
                                                    "\n📨 [\(topic)] Received message via listener:")
                                                print("   From: \(decodedMessage.clientId)")
                                                print(
                                                    "   Content: \(messageDict["message"] ?? "none")"
                                                )
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
                                // Clean up resources on error
                                self.subscriptions.removeValue(forKey: topic)
                                self.messageTasks.removeValue(forKey: topic)
                            }
                        }

                        // Store task reference
                        messageTasks[topic] = task

                        if isDebug {
                            print("✅ Subscribed to pending topic: \(topic)")
                        }
                    } catch {
                        errors.append(error)
                        if isDebug {
                            print("Error subscribing to topic \(topic): \(error)")
                        }
                        // Clean up on subscription failure
                        messageListeners.removeValue(forKey: topic)
                    }
                }
            } catch {
                errors.append(error)
                if isDebug {
                    print("Error processing topic \(topic): \(error)")
                }
            }
        }

        // Clear pending topics after processing
        pendingTopics.removeAll()

        // Throw if any errors occurred
        if !errors.isEmpty {
            throw RelayError.subscriptionFailed("Failed to subscribe to some topics: \(errors)")
        }
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
            "num_replicas": 1,
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
