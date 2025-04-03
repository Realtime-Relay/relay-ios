// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@preconcurrency import Nats

public actor Realtime {
    // MARK: - Properties
    
    internal let realtimeActor: RealtimeActor
    internal let subscriptionActor: SubscriptionActor
    internal var debug: Bool
    
    // MARK: - Initialization
    
    /// Initialize a new Realtime instance
    /// - Parameters:
    ///   - staging: Boolean indicating if staging environment should be used
    ///   - opts: Dictionary containing configuration options
    /// - Throws: RealtimeError if initialization fails
    public init(staging: Bool, opts: [String: Any]) async throws {
        self.debug = opts["debug"] as? Bool ?? false
        
        // Initialize actors
        self.realtimeActor = try RealtimeActor(staging: staging, opts: opts)
        
        // Get the NATS connection and namespace from the realtime actor
        let natsConnection = await realtimeActor.getNatsConnection()
        let namespace = await realtimeActor.getNamespace()
        
        // Initialize subscription actor with the obtained values
        self.subscriptionActor = SubscriptionActor(
            natsConnection: natsConnection,
            namespace: namespace,
            debug: debug
        )
    }
    
    // MARK: - Public Methods
    
    /// Connect to the NATS server
    public func connect() async throws {
        if debug {
            print("Starting connection process...")
        }
        
        // Connect using realtime actor
        try await realtimeActor.connect()
        
        // Subscribe to connection events using subscription actor
//        try await subscriptionActor.subscribeToConnectionEvents()
        
        if debug {
            print("Connection process completed")
        }
    }
    
    /// Publish a message to a topic
    /// - Parameters:
    ///   - topic: The topic to publish to
    ///   - message: The message to publish
    /// - Returns: Boolean indicating if the message was published successfully
    public func publish(topic: String, message: Any) async throws -> Bool {
        if debug {
            print("Starting publish to topic: \(topic)")
        }
        
        // Publish using realtime actor
        let result = try await realtimeActor.publish(topic: topic, message: message)
        
        if debug {
            print("Publish completed with result: \(result)")
        }
        
        return result
    }
    
    /// Subscribe to a topic
    /// - Parameters:
    ///   - topic: The topic to subscribe to
    ///   - listener: Closure to handle received messages
    public func on(topic: String, listener: @escaping (Any) -> Void) async throws {
        if debug {
            print("Starting subscription to topic: \(topic)")
        }
        
        // Subscribe using subscription actor
        try await subscriptionActor.subscribe(topic: topic, listener: listener)
        
        if debug {
            print("Subscription completed")
        }
    }
    
    /// Unsubscribe from a topic
    /// - Parameter topic: The topic to unsubscribe from
    /// - Returns: Boolean indicating if unsubscribed successfully
    public func off(topic: String) async throws -> Bool {
        if debug {
            print("Starting unsubscribe from topic: \(topic)")
        }
        
        // Unsubscribe using subscription actor
        let result = try await subscriptionActor.unsubscribe(topic: topic)
        
        if debug {
            print("Unsubscribe completed with result: \(result)")
        }
        
        return result
    }
    
    /// Disconnect from the NATS server
    public func close() async throws {
        if debug {
            print("Starting close process...")
        }
        
        // Cancel all subscriptions first
        await subscriptionActor.cancelAllSubscriptions()
        
        // Close connection using realtime actor
        try await realtimeActor.close()
        
        if debug {
            print("Close process completed")
        }
    }
} 
