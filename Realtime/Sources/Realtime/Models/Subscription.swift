import Foundation
@preconcurrency import Nats

/// A subscription to a NATS subject
@preconcurrency public struct Subscription: AsyncSequence, Sendable {
    public typealias Element = Message
    private let natsSubscription: NatsSubscription
    
    init(from natsSubscription: NatsSubscription) {
        self.natsSubscription = natsSubscription
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(subscription: self)
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var natsIterator: NatsSubscription.AsyncIterator
        
        init(subscription: Subscription) {
            self.natsIterator = subscription.natsSubscription.makeAsyncIterator()
        }
        
        public mutating func next() async throws -> Message? {
            guard let natsMessage = try await natsIterator.next() else {
                return nil
            }
            return Message(from: natsMessage)
        }
    }
    
    /// Unsubscribe from the subject
    public func unsubscribe() async throws {
        try await natsSubscription.unsubscribe()
    }
}

/// A subscription to a NATS subject
//public class Subscription {
//    private let natsSubscription: NatsSubscription
//    private let queue = DispatchQueue(label: "com.relay.subscription", qos: .userInitiated)
//    
//    init(from natsSubscription: NatsSubscription) {
//        self.natsSubscription = natsSubscription
//    }
//    
//    /// Start receiving messages
//    /// - Parameter messageHandler: Handler for received messages
//    public func startReceiving(messageHandler: @escaping (Message) -> Void) {
//        queue.async { [weak self] in
//            guard let self = self else { return }
//            Task {
//                do {
//                    for try await message in self.natsSubscription {
//                        messageHandler(Message(from: message))
//                    }
//                } catch {
//                    print("Error receiving message: \(error)")
//                }
//            }
//        }
//    }
//    
//    /// Unsubscribe from the subject
//    /// - Parameter completion: Completion handler with optional error
//    public func unsubscribe(completion: @escaping (Error?) -> Void) {
//        queue.async { [weak self] in
//            guard let self = self else { return }
//            do {
//                try await self.natsSubscription.unsubscribe()
//                completion(nil)
//            } catch {
//                completion(error)
//            }
//        }
//    }
//} 
