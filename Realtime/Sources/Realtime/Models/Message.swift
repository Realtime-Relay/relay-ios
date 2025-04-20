//
//  File.swift
//  Relay
//
//  Created by Shaxzod on 02/04/25.
//


import Foundation
import Nats

/// A message received from or sent to NATS
public struct Message: Sendable {
    /// The subject the message was published to
    public let subject: String
    
    /// The message payload as Data
    public let payload: Data
    
    /// The timestamp of the message (Unix timestamp in milliseconds)
    public let timestamp: Int64
    
    /// The sequence number of the message
    public let sequence: UInt64?
    
    /// Optional reply subject for request-reply pattern
    public let replySubject: String?
    
    /// Message headers
    public let headers: [String: String]?
    
    /// Message status code
    public let status: Status
    
    /// Optional status description
    public let description: String?
    
    /// The message ID
    public let id: String
    
    /// The content of the message
    public let content: String
    
    /// The client ID that sent the message
    public let clientId: String
    
    /// Initialize a new Message
    public init(
        subject: String,
        payload: Data = Data(),
        sequence: UInt64? = nil,
        replySubject: String? = nil,
        headers: [String: String]? = nil,
        status: Status = .ok,
        description: String? = nil,
        id: String = "",
        timestamp: Int64 = 0,
        content: String = "",
        clientId: String = ""
    ) {
        self.subject = subject
        self.payload = payload
        self.sequence = sequence
        self.replySubject = replySubject
        self.headers = headers
        self.status = status
        self.description = description
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.clientId = clientId
    }
    
    /// Initialize from a NatsMessage
    init(from natsMessage: NatsMessage) {
        self.subject = natsMessage.subject
        self.payload = natsMessage.payload ?? Data()
        
        // Try to parse payload as JSON
        if let data = natsMessage.payload,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.id = json["id"] as? String ?? ""
            self.timestamp = json["timestamp"] as? Int64 ?? 0
            self.content = json["content"] as? String ?? ""
            self.clientId = json["client_id"] as? String ?? ""
        } else {
            self.id = ""
            self.timestamp = 0
            self.content = ""
            self.clientId = ""
        }
        
        // Extract sequence from headers if available
        if let headers = natsMessage.headers,
           let natsMessageId = try? headers[NatsHeaderName("Nats-Msg-Id")],
           let sequence = UInt64(String(describing: natsMessageId)) {
            self.sequence = sequence
        } else {
            self.sequence = nil
        }
        
        self.replySubject = natsMessage.replySubject
        self.status = .ok
        self.description = nil
        
        // We don't need to store headers since we only use them for sequence
        self.headers = nil
    }
    
    /// Initialize with individual fields
    init(id: String, timestamp: Int64, content: String, clientId: String) {
        self.subject = ""  // Empty subject for messages created from payload
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.clientId = clientId
        self.replySubject = nil
        
        // Create payload from fields
        self.payload = (try? JSONSerialization.data(withJSONObject: [
            "id": id,
            "timestamp": timestamp,
            "content": content,
            "client_id": clientId
        ])) ?? Data()
        
        self.sequence = nil
        self.headers = nil
        self.status = .ok
        self.description = nil
    }
    
    /// Convert message to dictionary format
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "timestamp": timestamp,
            "content": content,
            "client_id": clientId
        ]
    }
}

// MARK: - Status
public extension Message {
    /// Message status codes
    enum Status: Sendable {
        case ok
        case notFound
        case error
        case unknown(Int)
        
        init(from status: StatusCode?) {
            switch status {
            case .ok:
                self = .ok
            case .notFound:
                self = .notFound
            case .badRequest:
                self = .error
            default:
                self = .unknown(0)
            }
        }
    }
}

// MARK: - Convenience Initializers
public extension Message {
    /// Initialize with a string payload
    init(
        subject: String,
        string: String,
        replySubject: String? = nil,
        headers: [String: String]? = nil,
        status: Status = .ok,
        description: String? = nil
    ) {
        self.init(
            subject: subject,
            payload: string.data(using: .utf8) ?? Data(),
            sequence: nil,
            replySubject: replySubject,
            headers: headers,
            status: status,
            description: description,
            id: "",
            timestamp: 0,
            content: string,
            clientId: ""
        )
    }
    
    /// Initialize with a JSON-encodable payload
    init<T: Encodable>(
        subject: String,
        json: T,
        replySubject: String? = nil,
        headers: [String: String]? = nil,
        status: Status = .ok,
        description: String? = nil
    ) throws {
        self.init(
            subject: subject,
            payload: try JSONEncoder().encode(json),
            sequence: nil,
            replySubject: replySubject,
            headers: headers,
            status: status,
            description: description,
            id: "",
            timestamp: 0,
            content: "",
            clientId: ""
        )
    }
}
// MARK: - Convenience Accessors
public extension Message {
    /// Get the payload as a string
    var string: String? {
        return String(data: payload, encoding: .utf8)
    }
    
    /// Get the payload as a JSON-decoded object
    func json<T: Decodable>() throws -> T {
        return try JSONDecoder().decode(T.self, from: payload)
    }
}

