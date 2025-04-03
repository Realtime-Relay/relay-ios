import Foundation
import Nats

actor RealtimeActor {
    // MARK: - Properties
    
    private let natsConnection: NatsClient
    private let servers: [URL]
    private let apiKey: String
    private let secret: String
    private var credentialsPath: URL?
    private var namespace: String?
    private var debug: Bool
    internal private(set) var isConnected = false
    
    // MARK: - Initialization
    
    init(staging: Bool, opts: [String: Any]) throws {
        // Validate required options
        guard let apiKey = opts["apiKey"] as? String, !apiKey.isEmpty else {
            throw RealtimeError.invalidConfiguration("apiKey is required and must be non-empty")
        }
        guard let secretKey = opts["secretKey"] as? String, !secretKey.isEmpty else {
            throw RealtimeError.invalidConfiguration("secretKey is required and must be non-empty")
        }
        
        self.apiKey = apiKey
        self.secret = secretKey
        self.debug = opts["debug"] as? Bool ?? false
        
        // Configure servers with provided API server list or use defaults
        if let serverUrls = opts["servers"] as? [String] {
            self.servers = serverUrls.compactMap { URL(string: $0) }
        } else {
            self.servers = [
                URL(string: "nats://api.relay-x.io:4221")!,
                URL(string: "nats://api.relay-x.io:4222")!,
                URL(string: "nats://api.relay-x.io:4223")!,
                URL(string: "nats://api.relay-x.io:4224")!,
                URL(string: "nats://api.relay-x.io:4225")!,
                URL(string: "nats://api.relay-x.io:4226")!
            ]
        }
        
        // Create temporary credentials file
        let credentialsContent = """
        -----BEGIN NATS USER JWT-----
        \(apiKey)
        -----END NATS USER JWT-----

        ************************* IMPORTANT *************************
        NKEY Seed printed below can be used to sign and prove identity.
        NKEYs are sensitive and should be treated as secrets.

        -----BEGIN USER NKEY SEED-----
        \(secretKey)
        -----END USER NKEY SEED-----

        *************************************************************
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let credentialsPath = tempDir.appendingPathComponent("realtime_credentials.creds")
        self.credentialsPath = credentialsPath
        
        do {
            try credentialsContent.write(to: credentialsPath, atomically: true, encoding: .utf8)
            if debug {
                print("Created credentials file at: \(credentialsPath)")
            }
        } catch {
            throw RealtimeError.invalidConfiguration("Failed to create credentials file: \(error)")
        }
        
        // Configure NATS connection
        let options = NatsClientOptions()
            .urls(servers)
            .credentialsFile(credentialsPath)
            .reconnectWait(1000)
            .maxReconnects(1200)
        
        if debug {
            print("Configuring NATS connection with options:")
            print("- Servers: \(servers)")
            print("- Credentials file: \(credentialsPath)")
            print("- Reconnect wait: 1000ms")
            print("- Max reconnects: 1200")
        }
        
        self.natsConnection = options.build()
    }
    
    deinit {
        // Clean up credentials file
        if let path = credentialsPath {
            try? FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Public Methods
    
    func connect() async throws {
        if debug {
            print("Attempting to connect to NATS servers: \(servers)")
        }
        
        do {
            // Add timeout for connection attempt
            try await withTimeout(seconds: 10) { [self] in
                try await natsConnection.connect()
            }
            isConnected = true
            
            if debug {
                print("Successfully connected to NATS server")
            }
            
            // Get namespace after connection
            if debug {
                print("Attempting to get namespace...")
            }
            try await fetchNamespace()
            
            if debug {
                print("Successfully got namespace: \(namespace ?? "default")")
            }
            
            // Create or get stream
            if debug {
                print("Attempting to create or get stream...")
            }
            try await createOrGetStream()
            
            if debug {
                print("Successfully created/got stream")
            }
        } catch {
            if debug {
                print("Failed to connect to NATS server: \(error)")
                print("Error details: \(String(describing: error))")
            }
            throw error
        }
    }
    
    func publish(topic: String, message: Any) async throws -> Bool {
        if debug {
            print("Starting publish to topic: \(topic)")
        }
        
        // Validate topic
        try validateTopic(topic)
        
        // Validate message
        guard message is String || message is Int || message is Double || message is [String: Any] else {
            throw RealtimeError.invalidMessage("Message must be String, Number, or JSON object")
        }
        
        // Prepare message payload
        let payload: [String: Any] = [
            "client_id": UUID().uuidString,
            "id": UUID().uuidString,
            "room": topic,
            "message": message,
            "start": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let finalTopic = "\(namespace ?? "default").stream.\(topic)"
        
        if debug {
            print("Publishing message to topic: \(finalTopic)")
            print("Message payload: \(String(data: jsonData, encoding: .utf8) ?? "invalid JSON")")
        }
        
        // Publish with timeout
        try await withTimeout(seconds: 5) { [self] in
            try await natsConnection.publish(jsonData, subject: finalTopic)
        }
        
        if debug {
            print("Successfully published message to topic: \(finalTopic)")
        }
        
        return true
    }
    
    func close() async throws {
        if debug {
            print("Starting close process...")
        }
        
        // Close the NATS connection with timeout
        if debug {
            print("Closing NATS connection...")
        }
        
        try await withTimeout(seconds: 5) { [self] in
            try await natsConnection.close()
        }
        
        isConnected = false
        
        if debug {
            print("NATS connection closed")
        }
        
        // Clean up credentials file
        if let path = credentialsPath {
            try? FileManager.default.removeItem(at: path)
            credentialsPath = nil
            if debug {
                print("Cleaned up credentials file")
            }
        }
        
        if debug {
            print("Close process completed")
        }
    }
    
    func getNatsConnection() async -> NatsClient {
        return natsConnection
    }
    
    func getNamespace() async -> String? {
        return namespace
    }
    
    // MARK: - Private Methods
    
    private func validateTopic(_ topic: String) throws {
        guard !topic.isEmpty else {
            throw RealtimeError.invalidTopic("Topic cannot be empty")
        }
        
        guard !topic.contains(" ") && !topic.contains("*") else {
            throw RealtimeError.invalidTopic("Topic cannot contain spaces or '*' characters")
        }
        
        let reservedTopics = ["CONNECTED", "RECONNECT", "MESSAGE_RESEND", "DISCONNECTED", "RECONNECTING", "RECONNECTED", "RECONN_FAIL"]
        guard !reservedTopics.contains(topic) else {
            throw RealtimeError.invalidTopic("Topic cannot be a system-reserved topic")
        }
    }
    
    private func fetchNamespace() async throws {
        let payload = ["api_key": apiKey]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            if debug {
                print("Requesting namespace with API key: \(apiKey.prefix(8))...")
                print("Request payload: \(String(data: jsonData, encoding: .utf8) ?? "invalid JSON")")
            }
            
            let response = try await natsConnection.request(
                jsonData,
                subject: NatsConstants.JetStream.accountInfo,
                timeout: 10000 // 10 second timeout
            )
            
            if debug {
                print("Got response: \(String(data: response.payload ?? Data(), encoding: .utf8) ?? "no payload")")
            }
            
            guard let data = response.payload,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let namespace = json["namespace"] as? String else {
                if debug {
                    print("Failed to parse namespace response: \(String(describing: response.payload))")
                }
                throw RealtimeError.invalidResponse
            }
            
            if debug {
                print("Successfully got namespace: \(namespace)")
            }
            self.namespace = namespace
        } catch {
            if debug {
                print("Failed to get namespace: \(error)")
                print("Using default namespace")
            }
            // If we can't get the namespace, use a default one
            self.namespace = "default"
        }
    }
    
    private func createOrGetStream() async throws {
        let streamName = "\(namespace ?? "default").stream"
        let config: [String: Any] = [
            "name": streamName,
            "subjects": ["\(namespace ?? "default").stream.>"],
            "retention": "limits",
            "max_consumers": -1,
            "max_msgs": 1000,
            "max_bytes": 1024 * 1024, // 1MB
            "max_age": 3600, // 1 hour
            "storage": "memory",
            "discard": "old",
            "num_replicas": 1
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config)
        
        do {
            if debug {
                print("Attempting to create stream: \(streamName)")
                print("Stream config: \(String(data: jsonData, encoding: .utf8) ?? "invalid JSON")")
            }
            
            let response = try await natsConnection.request(
                jsonData,
                subject: NatsConstants.JetStream.Stream.create(stream: streamName),
                timeout: 10000 // 10 second timeout
            )
            
            if debug {
                print("Got response: \(String(data: response.payload ?? Data(), encoding: .utf8) ?? "no payload")")
            }
            
            if debug {
                print("Successfully created stream: \(streamName)")
            }
        } catch {
            if debug {
                print("Failed to create stream: \(error)")
                print("Attempting to use existing stream...")
            }
            
            // If stream creation fails, try to use existing stream
            let infoRequest = ["stream_name": streamName]
            let infoData = try JSONSerialization.data(withJSONObject: infoRequest)
            
            do {
                let response = try await natsConnection.request(
                    infoData,
                    subject: NatsConstants.JetStream.Stream.info(stream: streamName),
                    timeout: 10000 // 10 second timeout
                )
                
                if debug {
                    print("Got response: \(String(data: response.payload ?? Data(), encoding: .utf8) ?? "no payload")")
                }
                
                if debug {
                    print("Successfully found existing stream: \(streamName)")
                }
            } catch {
                if debug {
                    print("Failed to get stream info: \(error)")
                }
                throw error
            }
        }
    }
    
    // Add helper function for timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation task
            group.addTask {
                try await operation()
            }
            
            // Add the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw RealtimeError.timeout("Operation timed out after \(seconds) seconds")
            }
            
            // Wait for first task to complete
            do {
                // Get the first result
                let result = try await group.next()
                
                // Cancel all remaining tasks
                group.cancelAll()
                
                // Return the result if we have one
                if let result = result {
                    return result
                }
                
                // If we don't have a result, try the operation one more time
                return try await operation()
            } catch {
                // Cancel all tasks on error
                group.cancelAll()
                throw error
            }
        }
    }
    
    // Internal accessors
    func getCurrentNamespace() -> String {
        return namespace ?? "default"
    }
    
    func isDebugEnabled() -> Bool {
        return debug
    }
    
    func getNatsClient() -> NatsClient {
        return natsConnection
    }
} 
