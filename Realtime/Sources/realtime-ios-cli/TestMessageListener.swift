import Foundation
import Realtime

class TestMessageListener: MessageListener {
    private let name: String
    private let handler: (([String: Any]) -> Void)?
    var lastMessage: [String: Any]?
    
    init(name: String, handler: @escaping ([String: Any]) -> Void) {
        self.name = name
        self.handler = handler
    }
    
    init(name: String) {
        self.name = name
        self.handler = nil
    }
    
    func onMessage(_ message: [String: Any]) {
        lastMessage = message
        print("\n📨 [\(name)] Received message: \(message)")
        handler?(message)
    }
} 