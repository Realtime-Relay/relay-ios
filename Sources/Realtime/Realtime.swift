// The Swift Programming Language
// https://docs.swift.org/swift-book

import Dispatch
import Foundation
@preconcurrency import JetStream
@preconcurrency import Nats
import SwiftMsgpack

@preconcurrency public final class Realtime: @unchecked Sendable {
    // MARK: - Properties

    var jetStream: JetStreamContext?
    var natsConnection: NatsClient
    private var servers: [URL] = []
    private let apiKey: String
    private let secret: String
    public var isConnected = false
    private var credentialsPath: URL?
    private var isDebug: Bool = false
    private var client_Id: String
    private var messageStorage: MessageStorage
    private var namespace: String?
    private var isStaging: Bool = false
    private var pendingTopics: Set<String> = []
    private var hash: String?

    private let listenerManager: ListenerManager
    private var messageTasks: [String: Task<Void, Never>] = [:]
    private var activeConsumers: Set<String> = []  // Track active consumers

    private var isResendingMessages = false
    private var wasDisconnected = false  // Only used for reconnection logic
    private var wasUnexpectedDisconnect = false  // Only used for message resend logic
    private var wasManualDisconnect = false  // Only used for message storage cleanup

    // Latency tracking properties
    private var latencyHistory: [[String: Any]] = []
    private var lastLatencyLogTime: Date = Date()
    private var latencyLogTimer: Timer?
    private let maxLatencyHistorySize = 100
    private let latencyLogInterval: TimeInterval = 30 // 30 seconds

    // MARK: - Initialization

    /// Initialize a new Realtime instance with authentication
    /// - Parameters:
    ///   - apiKey: The API key for authentication
    ///   - secret: The secret key for authentication
    /// - Throws: RelayError.invalidCredentials if credentials are invalid
    public init(apiKey: String, secret: String) throws {
        self.apiKey = apiKey
        self.secret = secret
        self.client_Id = "ios_\(UUID().uuidString)"
        self.messageStorage = MessageStorage()
        self.listenerManager = ListenerManager()

        // Configure NATS connection with required settings
        let options = NatsClientOptions()
            .maxReconnects(1200)
            .reconnectWait(1000)
            .token(apiKey)

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
        self.servers = (4221...4223).map { port in
            URL(string: "tls://\(baseUrl):\(port)")!
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
            if isDebug {
                print("Failed to create credentials file: \(error)")
            }
        }

        let options = NatsClientOptions()
            .urls(servers)
            .credentialsFile(credentialsPath)
            .maxReconnects(1200)
            .reconnectWait(1000)
            .token(apiKey)

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

        // Subscribe to topics
        try await subscribeToTopics()

        // Set connection status
        isConnected = true

        // Execute CONNECTED event listener if it exists
        if let connectedListener = listenerManager.getListener(for: SystemEvent.connected.rawValue) {
            connectedListener.onMessage([:])
            
            if isDebug {
                print("✅ Executed CONNECTED event listener")
            }
        }

        // Set up NATS event handlers
        natsConnection.on([.closed, .connected, .disconnected, .error, .lameDuckMode, .suspended]) {
            [weak self] natsEvent in
            guard let self = self else { return }

            Task {
                await self.handleNatsEvent(natsEvent)
            }
        }

        if self.isDebug {
            print("✅ Connected and ready")
        }
    }

    /// Close the NATS connection
    public func close() async throws {
        guard isConnected else {
            if isDebug {
                print("⚠️ Already disconnected")
            }
            return
        }

        // Set manual disconnect flag
        wasManualDisconnect = true
        
        // Send any remaining latency data before closing
        if !latencyHistory.isEmpty {
            await sendLatencyData()
        }

        // Cancel all message handling tasks
        for task in messageTasks.values {
            task.cancel()
        }
        messageTasks.removeAll()

        // Clean up all consumers
        try await cleanupAllConsumers()
        
        // Execute DISCONNECTED event listener if it exists
        if let disconnectedListener = listenerManager.getListener(for: SystemEvent.disconnected.rawValue) {
            disconnectedListener.onMessage([:])
            
            if isDebug {
                print("✅ Executed DISCONNECTED event listener")
            }
        }

        // Clear JetStream context
        jetStream = nil

        // Close NATS connection
        try await natsConnection.close()

        // Set connection status
        isConnected = false

        if isDebug {
            print("✅ Disconnected from NATS server")
            print("✅ JetStream context cleared")
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
        try TopicValidator.validate(topic)

        // Prevent publishing to system topics
        if SystemEvent.reservedTopics.contains(topic) {
            throw RelayError.invalidTopic("Cannot publish to system topic: \(topic)")
        }

        // Check for null message
        if let msg = (message as? String), msg.isEmpty {
            throw RelayError.invalidPayload("Message cannot be null")
        }

        // Create message content
        let messageContent: RealtimeMessage.MessageContent
        if let string = message as? String {
            messageContent = .string(string)
        } else if let number = message as? NSNumber {
            messageContent = .number(number.doubleValue)
        } else if let json = message as? [String: Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys, .prettyPrinted])
                messageContent = .json(jsonData)
            } catch {
                if isDebug {
                    print("❌ JSON serialization error: \(error)")
                }
                throw RelayError.invalidPayload("Failed to serialize JSON: \(error)")
            }
        } else {
            throw RelayError.invalidPayload(
                "Message must be a valid JSON object, string, or number")
        }

        // Create the final message
        let finalMessage = RealtimeMessage(
            client_Id: client_Id,
            id: UUID().uuidString,
            room: topic,
            message: messageContent,
            start: Int(Date().timeIntervalSince1970 * 1000) // Convert to milliseconds
        )

        // If not connected, store message locally
        if !isConnected {
            let messageDict: [String: Any] = [
                "client_id": finalMessage.client_id,
                "id": finalMessage.id,
                "room": finalMessage.room,
                "message": message,
                "start": finalMessage.start,
            ]

            messageStorage.storeMessage(topic: topic, message: messageDict)

            if isDebug {
                print("💾 Stored message locally (offline): \(messageDict)")
            }
            return false
        }

        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        // Format topic with hash
        let finalTopic = try formatTopic(topic)
      
        // Encode the message with MessagePack
        let encoder = MsgPackEncoder()
        let encodedMessage: Data
        do {
            encodedMessage = try encoder.encode(finalMessage)
        } catch {
            throw RelayError.invalidPayload("Failed to encode message with MessagePack: \(error)")
        }

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

    /// Subscribe to a topic with a message listener
    /// - Parameters:
    ///   - topic: The topic to subscribe to
    ///   - listener: The message listener interface
    /// - Throws: TopicValidationError if topic is invalid
    @discardableResult
    public func on(topic: String, listener: MessageListener) async throws -> Bool {
        // Check if listener already exists for this topic 
        if listenerManager.hasListener(for: topic) {
            if isDebug {
                print("⚠️ Listener already exists for topic: \(topic)")
            }
            return false
        }

        let isSystemTopic = SystemEvent.reservedTopics.contains(topic)

        // For system topics, just register the listener and return
        if isSystemTopic {
            listenerManager.addListener(listener, for: topic)
            if isDebug {
                print("✅ Registered listener for system topic: \(topic)")
            }
            return true
        }

        // For custom topics, validate the topic name
        try TopicValidator.validate(topic)

        guard isConnected else {
            pendingTopics.insert(topic)
            return false
        }

        // Format topic with hash
        let finalTopic = try formatTopic(topic)

        // Check if consumer already exists
        if messageTasks[topic] != nil {
            if isDebug {
                print("⚠️ Consumer already exists for topic: \(topic)")
            }
            return false
        }

        // Create or update consumer
        let consumer = try await createOrUpdateConsumer(for: topic, finalTopic: finalTopic)

        // Store the listener using the manager
        listenerManager.addListener(listener, for: topic)

        // Start message handling task
        handleJetStreamMessages(
            topic: topic,
            finalTopic: finalTopic,
            consumer: consumer
        )

        if isDebug {
            print("✅ Created/Updated JetStream consumer for topic: \(topic)")
            print("✅ Listener registered for topic: \(topic)")
            print("✅ Message handling task started for topic: \(topic)")
        }

        return true
    }

    /// Unsubscribe from a topic and clean up associated resources
    /// - Parameter topic: The topic to unsubscribe from
    /// - Returns: true if successfully unsubscribed, false otherwise
    /// - Throws: TopicValidationError if topic is invalid
    public func off(topic: String) async throws -> Bool {
        let isSystemTopic = SystemEvent.reservedTopics.contains(topic)
        
        // For system topics, just remove the listener
        if isSystemTopic {
            listenerManager.removeListener(for: topic)
            if isDebug {
                print("✅ Unsubscribed from system topic: \(topic)")
            }
            return true
        }
        
        // For custom topics, validate and handle JetStream cleanup
        try TopicValidator.validate(topic)

        var success = false

        // Cancel and remove message handling task
        if let task = messageTasks[topic] {
            task.cancel()
            messageTasks.removeValue(forKey: topic)
            success = true
        }

        // Remove message listener using the manager
        listenerManager.removeListener(for: topic)

        // Delete consumer for this topic
        try await deleteConsumer(for: topic)

        if isDebug {
            print("✅ Unsubscribed from topic: \(topic)")
        }

        return success
    }

    /// Get a list of past messages between a start time and an optional end time
    /// - Parameters:
    ///   - topic: The topic to get messages from
    ///   - start: The start date for message retrieval (required)
    ///   - end: The end date for message retrieval (optional)
    ///   - limit: The maximum number of messages to fetch (optional)
    /// - Returns: An array of message dictionaries
    /// - Throws: TopicValidationError if topic is invalid
    /// - Throws: RelayError.invalidDateRange if dates are invalid
    public func history(
        topic: String,
        start: Date,
        end: Date? = nil,
        limit: Int? = nil
    ) async throws -> [[String: Any]] {
        // Validate topic
        try TopicValidator.validate(topic)

        // Validate dates
        guard start <= Date() else {
            throw RelayError.invalidDate("Start date cannot be in the future")
        }

        if let end = end {
            guard start <= end else {
                throw RelayError.invalidDate("Start date must be before end date")
            }
        }

        // Check connection status
        guard isConnected else {
            throw RelayError.notConnected("Cannot retrieve history when not connected")
        }

        // Get JetStream context
        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        // Format topic with hash
        let formattedTopic = try formatTopic(topic)

        if isDebug {
            print("\n🔍 History Request Details:")
            print("  Topic: \(topic)")
            print("  Formatted Topic: \(formattedTopic)")
            print("  Start Date: \(start)")
            print("  End Date: \(end?.description ?? "nil")")
            print("  Limit: \(limit?.description ?? "nil")")
        }

        // Create unique consumer name for this history request
        let consumerName = "history_\(UUID().uuidString)"

        // Convert dates to milliseconds for JetStream
        let startMillis = Int(start.timeIntervalSince1970 * 1000)
        let endMillis = end.map { Int($0.timeIntervalSince1970 * 1000) }

        // Create consumer configuration
        let consumerConfig = ConsumerConfig(
            name: consumerName,
            deliverPolicy: .byStartTime,
            optStartTime: ISO8601DateFormatter().string(from: start),
            ackPolicy: .explicit,
            filterSubject: formattedTopic,
            replayPolicy: .instant
        )

        var messages: [[String: Any]] = []
        let batchSize = limit ?? 2_000_000

        do {
            // Create consumer
            let consumer = try await js.createConsumer(
                stream: "\(namespace ?? "")_stream", cfg: consumerConfig)

            if isDebug {
                print("\n📥 Fetching messages with batch size: \(batchSize)")
                print("  Start Time (ms): \(startMillis)")
                if let end = endMillis {
                    print("  End Time (ms): \(end)")
                }
            }

            // Fetch messages with batch size and timeout
            let fetchResult = try await consumer.fetch(batch: batchSize, expires: 5)

            for try await msg in fetchResult {
                if let payload = msg.payload {
                    if isDebug {
                        print("\n📦 Raw Message Payload:")
                        print("  Size: \(payload.count) bytes")
                        if let payloadString = String(data: payload, encoding: .utf8) {
                            print("  Content: \(payloadString)")
                        }
                    }

                    let decoder = MsgPackDecoder()
                    
                    do {
                        let decodedMessage = try decoder.decode(RealtimeMessage.self, from: payload)
                        
                        if isDebug {
                            print("\n🔍 Decoded Message Details:")
                            print("  Client ID: \(decodedMessage.client_id)")
                            print("  Message ID: \(decodedMessage.id)")
                            print("  Room: \(decodedMessage.room)")
                            print("  Start Time (ms): \(decodedMessage.start)")
                            print("  Message Type: \(type(of: decodedMessage.message))")
                            
                            // Print message content based on type
                            switch decodedMessage.message {
                            case .string(let str):
                                print("  Content (String): \(str)")
                            case .number(let num):
                                print("  Content (Number): \(num)")
                            case .json(let data):
                                if let json = try? JSONSerialization.jsonObject(with: data) {
                                    print("  Content (JSON): \(json)")
                                }
                            }
                        }

                        // Check end date if specified
                        if let end = endMillis, decodedMessage.start > end {
                            if isDebug {
                                print("  ⏭️ Skipping message - after end date")
                                print("    Message Time: \(decodedMessage.start)")
                                print("    End Time: \(end)")
                            }
                            break
                        }

                        // Convert message to dictionary format
                        let messageDict: [String: Any] = [
                            "client_id": decodedMessage.client_id,
                            "id": decodedMessage.id,
                            "room": decodedMessage.room,
                            "message": try {
                                switch decodedMessage.message {
                                case .string(let str): return str
                                case .number(let number): return number
                                case .json(let data):
                                    return try JSONSerialization.jsonObject(with: data)
                                }
                            }(),
                            "start": decodedMessage.start,
                        ]

                        if isDebug {
                            print("\n📝 Final Message Dictionary:")
                            print("  \(messageDict)")
                        }

                        messages.append(messageDict)
                        try await msg.ack()
                    } catch {
                        if isDebug {
                            print("\n❌ Error decoding message:")
                            print("  Error: \(error)")
                            print("  Payload: \(payload)")
                        }
                        continue
                    }
                }

                // Break if we've reached the limit
                if let limit = limit, messages.count >= limit {
                    if isDebug {
                        print("\n⏹️ Reached message limit: \(limit)")
                    }
                    break
                }
            }

            // Clean up the consumer after use
            try? await js.deleteConsumer(stream: "\(namespace ?? "")_stream", name: consumerName)

            if isDebug {
                print("\n✅ Retrieved \(messages.count) messages from history")
            }

        } catch {
            if isDebug {
                print("\n❌ Error fetching message history:")
                print("  Error: \(error)")
            }
            throw RelayError.invalidPayload("Failed to fetch message history: \(error)")
        }

        return messages
    }

    // MARK: - Privates

    /// Handle incoming JetStream messages for a topic
    /// - Parameters:
    ///   - topic: The topic being subscribed to
    ///   - finalTopic: The formatted topic with namespace
    ///   - consumer: The JetStream consumer
    private func handleJetStreamMessages(
        topic: String,
        finalTopic: String,
        consumer: Consumer
    ) {
        let task = Task {
            do {
                // Subscribe to the topic using NATS client's native subscription
                let subscription = try await natsConnection.subscribe(subject: finalTopic)
                
                // Process messages from the subscription
                for try await message in subscription {
                    guard let data = message.payload else {
                        if self.isDebug {
                            print("Message payload is nil")
                        }
                        continue
                    }

                    // Capture the exact moment the message is received
                    let messageReceivedTimeMillis = Int(Date().timeIntervalSince1970 * 1000)
            
                    do {
                        // Decode the MessagePack data
                        let decoder = MsgPackDecoder()
                        let decodedMessage = try decoder.decode(
                            RealtimeMessage.self, from: data)

                        // Check if message should be processed
                        guard decodedMessage.client_id != self.client_Id else {
                            if self.isDebug {
                                print("Skipping message from self: \(decodedMessage.id)")
                            }
                            continue
                        }

                        // Extract only the message content
                        let messageContent: Any
                        switch decodedMessage.message {
                        case .string(let string):
                            messageContent = string
                        case .number(let number):
                            messageContent = number
                        case .json(let data):
                            messageContent = try JSONSerialization.jsonObject(with: data)
                        }

                        // Get the listener before processing
                        guard let listener = self.listenerManager.getListener(for: topic) else {
                            if self.isDebug {
                                print("⚠️ No listener found for topic: \(topic)")
                            }
                            continue
                        }

                        // Notify the listener with just the message content on main thread
                        await MainActor.run {
                            listener.onMessage(messageContent)
                        }
                        
                        // Calculate and log latency after message delivery, using the captured receive time
                        await self.logLatency(messageStartTime: decodedMessage.start, messageReceivedTime: messageReceivedTimeMillis)
                        
                        if self.isDebug {
                            print("📥 Delivered message to listener: \(messageContent)")
                        }
                    } catch {
                        if self.isDebug {
                            print("Error processing message for topic \(topic): \(error)")
                        }
                    }
                }
            } catch {
                if self.isDebug {
                    print("Error handling messages for topic \(topic): \(error)")
                }
                // Clean up resources on error
                self.messageTasks.removeValue(forKey: topic)
                self.listenerManager.removeListener(for: topic)
            }
        }

        // Store task reference
        messageTasks[topic] = task

        if isDebug {
            print("✅ Message handling task started for topic: \(topic)")
        }
    }

    /// Subscribe to all pending topics that were initialized before connection
    private func subscribeToTopics() async throws {
        guard !pendingTopics.isEmpty else { return }

        var errors: [Error] = []

        for topic in pendingTopics {
            do {
                // Format topic with hash
                let finalTopic = try formatTopic(topic)

                // Skip if consumer already exists
                if messageTasks[topic] != nil {
                    if isDebug {
                        print("⚠️ Consumer already exists for topic: \(topic)")
                    }
                    continue
                }

                do {
                    guard let js = jetStream else {
                        throw RelayError.notConnected("JetStream context not initialized")
                    }

                    // Create a consumer configuration with proper settings
                    let consumerConfig = ConsumerConfig(
                        name: "\(topic)_consumer_\(UUID().uuidString)",
                        deliverPolicy: .new,
                        ackPolicy: .explicit,
                        filterSubject: finalTopic,
                        replayPolicy: .instant
                    )

                    // Create the consumer
                    let consumer = try await js.createConsumer(
                        stream: finalTopic,
                        cfg: consumerConfig
                    )

                    // Start message handling task
                    handleJetStreamMessages(
                        topic: topic,
                        finalTopic: finalTopic,
                        consumer: consumer
                    )

                    if isDebug {
                        print("✅ Subscribed to pending topic: \(topic)")
                    }
                } catch {
                    // Only add to errors if it's not a "consumer already exists" error
                    if !error.localizedDescription.contains("consumer already exists") {
                        errors.append(error)
                        if isDebug {
                            print("Error subscribing to topic \(topic): \(error)")
                        }
                        // Clean up on subscription failure
                        listenerManager.removeListener(for: topic)
                    } else if isDebug {
                        print("⚠️ Consumer already exists for topic: \(topic)")
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

        // Only throw if we have non-consumer-exists errors
        let nonConsumerErrors = errors.filter { !$0.localizedDescription.contains("consumer already exists") }
        if !nonConsumerErrors.isEmpty {
            throw RelayError.subscriptionFailed("Failed to subscribe to some topics: \(nonConsumerErrors)")
        }
    }

    func resendStoredMessages() async {
        guard !isResendingMessages else { return }
        isResendingMessages = true
        
        defer {
            isResendingMessages = false
        }
        
        let storedMessages = messageStorage.getStoredMessages()
        if storedMessages.isEmpty {
            if isDebug {
                print("ℹ️ No stored messages to resend")
            }
            return
        }
        
        // Notify listeners that we're about to resend messages
        if let listener = listenerManager.getListener(for: SystemEvent.messageResend.rawValue) {
            listener.onMessage(["count": storedMessages.count])
        }
        
        for message in storedMessages {
            var retryCount = 0
            let maxRetries = 3
            
            while retryCount < maxRetries {
                if let rawMessage = message.message["message"] as? [String: Any] {
                    do {
                        let success = try await publish(
                            topic: message.topic,
                            message: rawMessage
                        )
                        
                        if success {
                            if isDebug {
                                print("✅ Successfully resent message to topic: \(message.topic)")
                            }
                            // Remove the message from storage on successful resend
                            messageStorage.removeMessage(topic: message.topic, messageId: message.message["id"] as? String ?? "")
                            break // Exit retry loop on success
                        }
                        
                        retryCount += 1
                        if retryCount < maxRetries {
                            if isDebug {
                                print("⚠️ Failed to resend message, attempt \(retryCount)/\(maxRetries)")
                            }
                            try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay between retries
                        }
                    } catch {
                        if isDebug {
                            print("❌ Error during message resend: \(error)")
                        }
                        retryCount += 1
                    }
                } else {
                    if isDebug {
                        print("❌ Invalid message format in storage")
                    }
                    break
                }
            }
            
            if retryCount >= maxRetries {
                messageStorage.updateMessageStatus(
                    topic: message.topic,
                    messageId: message.message["id"] as? String ?? "",
                    resent: false
                )
                if isDebug {
                    print("❌ Failed to resend message after \(maxRetries) attempts")
                }
            }
            
            // Add a small delay between messages
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            } catch {
                if isDebug {
                    print("⚠️ Error during delay between messages: \(error)")
                }
            }
        }
    }

    // Get the namespace for the current user
    private func getNamespace() async throws -> String {
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
                let namespace = data["namespace"] as? String,
                let hash = data["hash"] as? String
            else {
                throw RelayError.invalidPayload("Invalid response format or missing namespace/hash")
            }

            if namespace.isEmpty || hash.isEmpty {
                throw RelayError.invalidNamespace("Namespace and hash cannot be empty")
            }

            // Store both namespace and hash
            self.namespace = namespace
            self.hash = hash

            return namespace
        } catch {
            if self.isDebug {
                print("Failed to get namespace: \(error)")
            }
            throw RelayError.invalidNamespace("Failed to retrieve namespace: \(error)")
        }
    }

    // Helper method to format topic with hash
    private func formatTopic(_ topic: String) throws -> String {
        guard let hash = self.hash else {
            throw RelayError.invalidNamespace("Hash not available - must be connected first")
        }
        return "\(hash).\(topic)"
    }

    private func onReconnected() async throws {
        // Only proceed if this was an unexpected disconnect
        guard wasUnexpectedDisconnect else { return }

        if isDebug {
            print("✅ Reconnected to NATS server")
            print("✅ Handling unexpected disconnect...")
        }

        // Wait for connection to be fully established
        for _ in 0..<50 { // Wait up to 5 seconds
            if isConnected {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }

        guard isConnected else {
            if isDebug {
                print("❌ Failed to establish connection for resending messages")
            }
            return
        }

        // Initialize JetStream after connection
        self.jetStream = JetStreamContext(client: natsConnection)

        // Get namespace if needed
        if namespace == nil {
            _ = try await getNamespace()
        }

        // Subscribe to topics again
        try await subscribeToTopics()

        if isDebug {
            print("✅ Successfully completed reconnection process")
        }
    }

    private func handleNatsEvent(_ event: NatsEvent) async {
        switch event {
        case .connected:
            isConnected = true
            if isDebug {
                print("✅ NATS Event: Connected")
            }
            
            // Reset manual disconnect flag on successful connection
            wasManualDisconnect = false
            
            // Check if this is a reconnection after a disconnect
            if wasDisconnected {
                if isDebug {
                    print("✅ NATS Event: Reconnected after disconnect")
                }

                // Execute RECONNECTED event listener
                if let reconnectedListener = listenerManager.getListener(for: SystemEvent.reconnected.rawValue) {
                    reconnectedListener.onMessage([:])
                }

                do {
                    try await onReconnected()
                } catch {
                    if isDebug {
                        print("❌ Error during reconnection: \(error)")
                    }
                }
                wasDisconnected = false  // Reset disconnect flag
            }

            // Only resend messages if this was an unexpected disconnect // remove this while testing 
           if wasUnexpectedDisconnect {
                await resendStoredMessages()
               wasUnexpectedDisconnect = false
           }

        case .disconnected:
            isConnected = false
            wasDisconnected = true
            wasUnexpectedDisconnect = true  // Mark as unexpected for message resend
            if isDebug {
                print("⚠️ NATS Event: Unexpected disconnection")
            }
            // Notify listeners about disconnection
            if let listener = listenerManager.getListener(for: SystemEvent.disconnected.rawValue) {
                listener.onMessage([:])
            }

        case .closed:
            isConnected = false
            wasDisconnected = true
            if isDebug {
                print("⚠️ NATS Event: Connection closed")
            }
            // Notify listeners about closure
            if let listener = listenerManager.getListener(for: SystemEvent.disconnected.rawValue) {
                listener.onMessage([:])
            }

            // Only clear stored messages if this was a manual disconnect
            if wasManualDisconnect {
                messageStorage.clearStoredMessages()
            }

        case .suspended:
            isConnected = false
            wasDisconnected = true
            wasUnexpectedDisconnect = true  // Mark as unexpected for message resend
            if isDebug {
                print("⚠️ NATS Event: Connection suspended")
            }
            // Notify listeners about suspension
            if let listener = listenerManager.getListener(for: SystemEvent.disconnected.rawValue) {
                listener.onMessage([:])
            }

        case .lameDuckMode:
            isConnected = false
            wasDisconnected = true
            wasUnexpectedDisconnect = true  // Mark as unexpected for message resend
            if isDebug {
                print("🦆 NATS Event: Server in lame duck mode")
                print("⚠️ Server-initiated shutdown detected")
            }
            // Notify listeners about lame duck mode
            if let listener = listenerManager.getListener(for: SystemEvent.disconnected.rawValue) {
                listener.onMessage([:])
            }

        case .error(let error):
            if isDebug {
                print("❌ NATS Event: Error occurred - \(error)")
            }
        }
    }

    private func getConsumerName(for topic: String) -> String {
        return "\(topic)_consumer"
    }

    private func getConsumer(for topic: String) async throws -> Consumer? {
        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available - must be connected first")
        }

        let streamName = "\(currentNamespace)_stream"
        let consumerName = getConsumerName(for: topic)

        return try? await js.getConsumer(stream: streamName, name: consumerName)
    }

    private func createOrUpdateConsumer(for topic: String, finalTopic: String) async throws -> Consumer {
        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available - must be connected first")
        }

        let streamName = "\(currentNamespace)_stream"
        let consumerName = getConsumerName(for: topic)

        let consumerConfig = ConsumerConfig(
            name: consumerName,
            deliverPolicy: .all,
            maxDeliver: 3,
            filterSubject: finalTopic,
            replayPolicy: .instant
        )

        let consumer = try await js.createOrUpdateConsumer(stream: streamName, cfg: consumerConfig)
        activeConsumers.insert(topic)  // Add to active consumers
        if isDebug {
            print("✅ Created/Updated consumer for topic: \(topic) with deliverPolicy: .all")
        }
        return consumer
    }

    /// Delete a consumer for a specific topic
    /// - Parameter topic: The topic to delete the consumer for
    private func deleteConsumer(for topic: String) async throws {
        // Skip if consumer is not in active consumers
        guard activeConsumers.contains(topic) else {
            if isDebug {
                print("ℹ️ Consumer not tracked for topic: \(topic) - skipping deletion")
            }
            return
        }

        guard let js = jetStream else {
            throw RelayError.notConnected("JetStream context not initialized")
        }

        guard let currentNamespace = namespace else {
            throw RelayError.invalidNamespace("Namespace not available - must be connected first")
        }

        let streamName = "\(currentNamespace)_stream"
        let consumerName = getConsumerName(for: topic)

        do {
            // First check if consumer exists
            if let _ = try await js.getConsumer(stream: streamName, name: consumerName) {
                try await js.deleteConsumer(stream: streamName, name: consumerName)
                activeConsumers.remove(topic)  // Remove from active consumers
                if isDebug {
                    print("✅ Deleted consumer for topic: \(topic)")
                }
            } else if isDebug {
                print("ℹ️ Consumer not found for topic: \(topic) - skipping deletion")
            }
        } catch {
            if isDebug {
                print("⚠️ Failed to delete consumer for topic \(topic): \(error)")
            }
        }
    }

    /// Clean up all consumers
    private func cleanupAllConsumers() async throws {
        let topicsToCleanup = activeConsumers
        for topic in topicsToCleanup {
            try await deleteConsumer(for: topic)
        }
    }

    /// Log latency for incoming messages
    /// - Parameters:
    ///   - messageStartTime: The timestamp when the message was sent (in milliseconds)
    ///   - messageReceivedTime: The timestamp when the message was received (in milliseconds)
    private func logLatency(messageStartTime: Int, messageReceivedTime: Int) async {
        // Calculate latency (current time - message start time)
        let latency = messageReceivedTime - messageStartTime
        
        // Create latency entry
        let latencyEntry: [String: Any] = [
            "latency": latency,
            "timestamp": messageReceivedTime
        ]
        
        // Add to history
        latencyHistory.append(latencyEntry)
        
        // Check if we need to send the latency data
        let shouldSendLatencyData = latencyHistory.count >= maxLatencyHistorySize || 
                                   Date().timeIntervalSince(lastLatencyLogTime) >= latencyLogInterval
        
        if shouldSendLatencyData {
            await sendLatencyData()
        }
    }
    
    /// Send latency data to the backend
    private func sendLatencyData() async {
        // Get timezone in the format "Continent/Country"
        let timezone = TimeZone.current.identifier
        
        // Create payload
        let payload: [String: Any] = [
            "timezone": timezone,
            "history": latencyHistory
        ]
        
        do {
            // Convert payload to JSON data
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            
            // Publish to accounts.user.log_latency
            _ = try await natsConnection.request(
                payloadData,
                subject: "accounts.user.log_latency",
                timeout: 5.0
            )
            
            if isDebug {
                print("✅ Sent latency data to backend")
            }
            
            // Reset history and update last log time
            latencyHistory.removeAll()
            lastLatencyLogTime = Date()
        } catch {
            if isDebug {
                print("❌ Failed to send latency data: \(error)")
            }
        }
    }
}
