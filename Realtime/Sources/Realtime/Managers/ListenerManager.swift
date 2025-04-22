import Foundation

/// Thread-safe manager for handling message listeners with weak references
final class ListenerManager {
    // MARK: - Properties
    
    private let queue = DispatchQueue(label: "com.relay.listener-manager", attributes: .concurrent)
    private var listeners: [String: WeakListener] = [:]
    
    // MARK: - Types
    
    private class WeakListener {
        weak var value: MessageListener?
        
        init(_ value: MessageListener) {
            self.value = value
        }
    }
    
    // MARK: - Public Methods
    
    /// Add a listener for a specific topic
    /// - Parameters:
    ///   - listener: The message listener to add
    ///   - topic: The topic to subscribe to
    func addListener(_ listener: MessageListener, for topic: String) {
        queue.async(flags: .barrier) {
            self.listeners[topic] = WeakListener(listener)
        }
    }
    
    /// Remove a listener for a specific topic
    /// - Parameter topic: The topic to unsubscribe from
    func removeListener(for topic: String) {
        queue.async(flags: .barrier) {
            self.listeners.removeValue(forKey: topic)
        }
    }
    
    /// Get a listener for a specific topic
    /// - Parameter topic: The topic to get the listener for
    /// - Returns: The message listener if it exists and hasn't been deallocated
    func getListener(for topic: String) -> MessageListener? {
        queue.sync {
            return listeners[topic]?.value
        }
    }
    
    /// Check if a listener exists for a specific topic
    /// - Parameter topic: The topic to check
    /// - Returns: True if a valid listener exists
    func hasListener(for topic: String) -> Bool {
        queue.sync {
            return listeners[topic]?.value != nil
        }
    }
    
    /// Remove all listeners
    func removeAllListeners() {
        queue.async(flags: .barrier) {
            self.listeners.removeAll()
        }
    }
    
    /// Clean up any deallocated listeners
    func cleanupDeallocatedListeners() {
        queue.async(flags: .barrier) {
            self.listeners = self.listeners.filter { $0.value.value != nil }
        }
    }
    
    /// Get all active topics
    /// - Returns: Array of topics with active listeners
    func getActiveTopics() -> [String] {
        queue.sync {
            return listeners.compactMap { topic, listener in
                listener.value != nil ? topic : nil
            }
        }
    }
} 