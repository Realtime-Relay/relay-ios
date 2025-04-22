import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let sender: String
    let text: String
    let timestamp: String
    let isFromCurrentUser: Bool
    
    init(sender: String, text: String, timestamp: String, isFromCurrentUser: Bool = false) {
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
} 