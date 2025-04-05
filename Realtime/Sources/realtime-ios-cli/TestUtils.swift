import Foundation
import Realtime
import SwiftMsgpack

// Message listener implementation
public class TestMessageListener: MessageListener {
    public let name: String
    public var receivedMessages: [[String: Any]] = []
    
    public init(name: String) {
        self.name = name
    }
    
    public func onMessage(_ message: [String: Any]) {
        print("\n📨 [\(name)] Received message via listener:")
        if let messageContent = message["message"] {
            print("   Content: \(messageContent)")
        }
        if let clientId = message["client_id"] {
            print("   From: \(clientId)")
        }
        if let timestamp = message["start"] {
            print("   Timestamp: \(timestamp)")
        }
        receivedMessages.append(message)
    }
}

// Message struct for testing
public struct TestMessage: Codable {
    public let room: String
    public let message: String
    public let timestamp: Date
    
    public init(room: String, message: String) {
        self.room = room
        self.message = message
        self.timestamp = Date()
    }
} 