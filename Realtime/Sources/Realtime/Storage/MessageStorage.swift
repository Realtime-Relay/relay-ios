//
//  MessageStorage.swift
//  Realtime
//
//  Created by Shaxzod on 04/04/25.
//


import Foundation

/// Stores messages locally when offline and handles resending them when reconnected
final class MessageStorage {
    private let storageKey = "relay_offline_messages"
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// Stores a message for later sending
    func storeMessage(topic: String, message: [String: Any]) {
        var storedMessages = getStoredMessages()
        storedMessages.append(StoredMessage(topic: topic, message: message))
        saveMessages(storedMessages)
    }
    
    /// Retrieves all stored messages
    func getStoredMessages() -> [StoredMessage] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([StoredMessage].self, from: data)) ?? []
    }
    
    /// Updates the resent status of a message
    func updateMessageStatus(topic: String, messageId: String, resent: Bool) {
        var storedMessages = getStoredMessages()
        if let index = storedMessages.firstIndex(where: { 
            $0.topic == topic && 
            ($0.message["id"] as? String == messageId)
        }) {
            storedMessages[index].resent = resent
            saveMessages(storedMessages)
        }
    }
    
    /// Get message statuses for MESSAGE_RESEND event
    func getMessageStatuses() -> [[String: Any]] {
        return getStoredMessages().map { message in
            [
                "topic": message.topic,
                "message": message.message,
                "resent": message.resent
            ]
        }
    }
    
    /// Removes all stored messages
    func clearStoredMessages() {
        userDefaults.removeObject(forKey: storageKey)
    }
    
    private func saveMessages(_ messages: [StoredMessage]) {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

/// Represents a message stored locally
struct StoredMessage: Codable {
    let topic: String
    let message: [String: Any]
    let timestamp: Date
    var resent: Bool
    
    init(topic: String, message: [String: Any]) {
        self.topic = topic
        self.message = message
        self.timestamp = Date()
        self.resent = false
    }
    
    // Custom encoding/decoding for Dictionary
    enum CodingKeys: String, CodingKey {
        case topic, message, timestamp, resent
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topic = try container.decode(String.self, forKey: .topic)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        resent = try container.decode(Bool.self, forKey: .resent)
        
        // Decode message as Data first, then convert to Dictionary
        let messageData = try container.decode(Data.self, forKey: .message)
        message = try JSONSerialization.jsonObject(with: messageData) as? [String: Any] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topic, forKey: .topic)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(resent, forKey: .resent)
        
        // Convert message Dictionary to Data for storage
        let messageData = try JSONSerialization.data(withJSONObject: message)
        try container.encode(messageData, forKey: .message)
    }
}