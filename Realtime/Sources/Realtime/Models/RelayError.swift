import Foundation

public enum RelayError: LocalizedError {
    case invalidCredentials(String)
    case invalidResponse
    case invalidOptions(String)
    case invalidPayload
    case notConnected(String)
    case invalidDate(String)
    case invalidNamespace(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let message):
            return "Invalid credentials: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidOptions(let message):
            return "Invalid options: \(message)"
        case .invalidPayload:
            return "Invalid message payload"
        case .notConnected(let message):
            return "Not connected: \(message)"
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        case .invalidNamespace(let message):
            return "Invalid namespace: \(message)"
        }
    }
} 