import Foundation
import Nats

/// A message received from or sent to NATS
public struct Message: Sendable {
    /// The subject the message was published to
    public let subject: String
    
    /// The message payload as Data
    public let payload: Data?
    
    /// Optional reply subject for request-reply pattern
    public let replySubject: String?
    
    /// Message headers
    public let headers: [String: String]?
    
    /// Message status code
    public let status: Status
    
    /// Optional status description
    public let description: String?
    
    /// Initialize a new Message
    public init(
        subject: String,
        payload: Data? = nil,
        replySubject: String? = nil,
        headers: [String: String]? = nil,
        status: Status = .ok,
        description: String? = nil
    ) {
        self.subject = subject
        self.payload = payload
        self.replySubject = replySubject
        self.headers = headers
        self.status = status
        self.description = description
    }
    
    /// Initialize from a NatsMessage
    init(from natsMessage: NatsMessage) {
        self.subject = natsMessage.subject
        self.payload = natsMessage.payload
        self.replySubject = natsMessage.replySubject
        self.headers = nil// natsMessage.headers?.dictionary
        self.status = Status(from: natsMessage.status)
        self.description = natsMessage.description
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
            payload: string.data(using: .utf8),
            replySubject: replySubject,
            headers: headers,
            status: status,
            description: description
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
            replySubject: replySubject,
            headers: headers,
            status: status,
            description: description
        )
    }
}

// MARK: - Convenience Accessors
public extension Message {
    /// Get the payload as a string
    var string: String? {
        guard let data = payload else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Get the payload as a JSON-decoded object
    func json<T: Decodable>() throws -> T {
        guard let data = payload else {
            throw RelayError.invalidPayload
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
} 

public enum RelayError: Error {
    case invalidPayload
    case invalidResponse
}
