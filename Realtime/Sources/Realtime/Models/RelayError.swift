import Foundation

public enum RelayError: LocalizedError {
    case invalidCredentials(String)
    case invalidResponse
    case invalidOptions(String)
    case invalidPayload
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let message):
            return "Invalid credentials: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidOptions(let message):
            return "Invalid options: \(message)"
        case .invalidPayload:
            return "Invalid payload"
        }
    }
} 