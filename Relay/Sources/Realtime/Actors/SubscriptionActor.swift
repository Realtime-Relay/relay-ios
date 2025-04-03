import Foundation
import Nats

actor SubscriptionActor {
    // MARK: - Properties
    
    private let natsConnection: NatsClient
    private let namespace: String?
    private let debug: Bool
    private var activeSubscriptions: [String: Task<Void, Never>] = [:]
    private var eventSubscriptions: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    init(natsConnection: NatsClient, namespace: String?, debug: Bool) {
        self.natsConnection = natsConnection
        self.namespace = namespace
        self.debug = debug
    }
    
    // MARK: - Public Methods
    
    func subscribe(topic: String, listener: @escaping (Any) -> Void) async throws {
        // Validate topic
        try validateTopic(topic)
        
        let finalTopic = "\(namespace ?? "default").stream.\(topic)"
        
        if debug {
            print("Subscribing to topic: \(finalTopic)")
        }
        
        // Cancel existing subscription if any
        if let existingTask = activeSubscriptions[finalTopic] {
            existingTask.cancel()
            activeSubscriptions.removeValue(forKey: finalTopic)
        }
        
        do {
            // Subscribe to the topic with timeout
            let subscription = try await withTimeout(seconds: 5) { [self] in
                try await natsConnection.subscribe(subject: finalTopic)
            }
            
            let task = Task {
                do {
                    for try await message in subscription {
                        if Task.isCancelled {
                            if debug {
                                print("Subscription task cancelled for topic: \(finalTopic)")
                            }
                            break
                        }
                        
                        if let data = message.payload,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let messagePayload = json["message"] {
                            if debug {
                                print("Received message: \(messagePayload)")
                            }
                            await MainActor.run {
                                listener(messagePayload)
                            }
                        }
                    }
                } catch {
                    if debug {
                        print("Subscription error for topic \(finalTopic): \(error)")
                    }
                }
            }
            
            activeSubscriptions[finalTopic] = task
            
            if debug {
                print("Successfully subscribed to topic: \(finalTopic)")
            }
        } catch {
            if debug {
                print("Failed to subscribe to topic: \(error)")
            }
            throw RealtimeError.subscribeFailed("Failed to subscribe to topic: \(error)")
        }
    }
    
    func unsubscribe(topic: String) async throws -> Bool {
        let finalTopic = "\(namespace ?? "default").stream.\(topic)"
        
        if debug {
            print("Starting unsubscribe process for topic: \(finalTopic)")
            print("Current active subscriptions: \(activeSubscriptions.keys)")
        }
        
        // Find and cancel subscription
        if let task = activeSubscriptions[finalTopic] {
            if debug {
                print("Found subscription task for topic: \(finalTopic)")
                print("Task is cancelled: \(task.isCancelled)")
            }
            
            task.cancel()
            activeSubscriptions.removeValue(forKey: finalTopic)
            
            if debug {
                print("Cancelled task and removed from active subscriptions")
                print("Remaining active subscriptions: \(activeSubscriptions.keys)")
            }
            
            // Wait for unsubscribe to take effect
            if debug {
                print("Waiting for unsubscribe to take effect...")
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Verify subscription is cancelled
            if task.isCancelled {
                if debug {
                    print("Successfully unsubscribed from topic: \(finalTopic)")
                }
                return true
            } else {
                if debug {
                    print("Failed to cancel subscription for topic: \(finalTopic)")
                    print("Task status after cancellation: \(task.isCancelled)")
                }
                return false
            }
        }
        
        if debug {
            print("No active subscription found for topic: \(finalTopic)")
            print("Current active subscriptions: \(activeSubscriptions.keys)")
        }
        return false
    }
    
    func subscribeToConnectionEvents() async throws {
        let events = ["CONNECTED", "DISCONNECTED", "RECONNECTING", "RECONNECTED"]
        
        for event in events {
            let subscription = try await natsConnection.subscribe(subject: event)
            let task = Task {
                do {
                    for try await _ in subscription {
                        if self.debug {
                            print("Connection event: \(event)")
                        }
                        
                        if event == "RECONNECTED" {
                            try? await self.resubscribeToTopics()
                        }
                    }
                } catch {
                    if debug {
                        print("Connection event subscription error: \(error)")
                    }
                }
            }
            eventSubscriptions[event] = task
        }
    }
    
    func cancelAllSubscriptions() async {
        // Cancel all event subscriptions
        for task in eventSubscriptions.values {
            task.cancel()
        }
        eventSubscriptions.removeAll()
        
        // Cancel all topic subscriptions
        for task in activeSubscriptions.values {
            task.cancel()
        }
        activeSubscriptions.removeAll()
        
        if debug {
            print("Cancelled all subscriptions")
        }
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
    
    private func resubscribeToTopics() async throws {
        // Re-establish all active subscriptions
        for (topic, _) in activeSubscriptions {
            try await subscribe(topic: topic) { _ in }
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
} 