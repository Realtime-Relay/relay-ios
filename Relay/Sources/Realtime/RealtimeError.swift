import Foundation

public enum RealtimeError: Error {
    case invalidConfiguration(String)
    case invalidMessage(String)
    case invalidTopic(String)
    case invalidResponse
    case subscribeFailed(String)
    case invalidDate(String)
    case timeout(String)
    case connectionFailed
    case invalidCredentials
    case notConnected
    case subscriptionFailed
    case publishFailed
    case unsubscribeFailed
    case closeFailed
    
    public var localizedDescription: String {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .invalidMessage(let message):
            return "Invalid message: \(message)"
        case .invalidTopic(let message):
            return "Invalid topic: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .subscribeFailed(let message):
            return "Failed to subscribe: \(message)"
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        case .timeout(let message):
            return "Timeout: \(message)"
        case .connectionFailed:
            return "Connection failed"
        case .invalidCredentials:
            return "Invalid credentials"
        case .notConnected:
            return "Not connected"
        case .subscriptionFailed:
            return "Subscription failed"
        case .publishFailed:
            return "Publish failed"
        case .unsubscribeFailed:
            return "Unsubscribe failed"
        case .closeFailed:
            return "Close failed"
        }
    }
} 