import Foundation
import Nats

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
