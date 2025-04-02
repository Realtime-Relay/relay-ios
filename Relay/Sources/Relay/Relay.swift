// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import Nats

/// The main Relay client for interacting with NATS
public class Relay {
    let natsConnection: NatsClient
    private let queue = DispatchQueue(label: "com.relay.nats", qos: .userInitiated)
    private let actor: RelayActor
    
    public init(server: String, apiKey: String, apiSecret: String) {
        guard let url = URL(string: server) else {
            fatalError("Invalid server URL")
        }
        let options = NatsClientOptions()
            .urls([url])
            .token(apiSecret)
            .maxReconnects(5)
        self.natsConnection = options.build()
        self.actor = RelayActor(natsConnection: natsConnection)
    }
    
    // MARK: - Connection Management
    public func connect(completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Instance deallocated"]))
                return
            }
            
            Task {
                do {
                    try await self.actor.connect()
                    await MainActor.run {
                        completion(nil)
                    }
                } catch {
                    await MainActor.run {
                        completion(error)
                    }
                }
            }
        }
    }
    
    public func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            Task {
                try? await self.actor.disconnect()
            }
        }
    }
    
    // MARK: - Publishing
    public func publish(subject: String, payload: String, headers: [String: String]? = nil, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Instance deallocated"]))
                return
            }
            
            guard let data = payload.data(using: .utf8) else {
                completion(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid payload"]))
                return
            }
            
            Task {
                do {
                    try await self.actor.publish(subject: subject, payload: data)
                    await MainActor.run {
                        completion(nil)
                    }
                } catch {
                    await MainActor.run {
                        completion(error)
                    }
                }
            }
        }
    }
    
    public func publishJSON<T: Encodable & Sendable>(subject: String, json: T, headers: [String: String]? = nil, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Instance deallocated"]))
                return
            }
            
            Task {
                do {
                    let data = try JSONEncoder().encode(json)
                    try await self.actor.publish(subject: subject, payload: data)
                    await MainActor.run {
                        completion(nil)
                    }
                } catch {
                    await MainActor.run {
                        completion(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Subscriptions
    public func subscribe(subject: String, messageHandler: @escaping @Sendable (Message) -> Void, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Instance deallocated"]))
                return
            }
            
            Task {
                do {
                    try await self.actor.subscribe(subject: subject, handler: messageHandler)
                    await MainActor.run {
                        completion(nil)
                    }
                } catch {
                    await MainActor.run {
                        completion(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Requests
    public func request(subject: String, payload: String, timeout: TimeInterval = 5, completion: @escaping @Sendable (Result<Message, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Instance deallocated"])))
                return
            }
            
            guard let data = payload.data(using: .utf8) else {
                completion(.failure(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid payload"])))
                return
            }
            
            Task {
                do {
                    let response = try await self.actor.request(subject: subject, payload: data, timeout: timeout)
                    await MainActor.run {
                        completion(.success(response))
                    }
                } catch {
                    await MainActor.run {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    public func requestJSON<T: Encodable & Sendable, R: Decodable & Sendable>(subject: String, json: T, timeout: TimeInterval = 5, completion: @escaping @Sendable (Result<R, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "Relay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Instance deallocated"])))
                return
            }
            
            Task {
                do {
                    let requestData = try JSONEncoder().encode(json)
                    let response = try await self.actor.request(subject: subject, payload: requestData, timeout: timeout)
                    let decoded = try JSONDecoder().decode(R.self, from: response.payload ?? Data())
                    await MainActor.run {
                        completion(.success(decoded))
                    }
                } catch {
                    await MainActor.run {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}
