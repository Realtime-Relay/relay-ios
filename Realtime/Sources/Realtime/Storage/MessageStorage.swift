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
    
    init(topic: String, message: [String: Any]) {
        self.topic = topic
        self.message = message
        self.timestamp = Date()
    }
    
    // Custom encoding/decoding for Dictionary
    enum CodingKeys: String, CodingKey {
        case topic, message, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topic = try container.decode(String.self, forKey: .topic)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode message as Data first, then convert to Dictionary
        let messageData = try container.decode(Data.self, forKey: .message)
        message = try JSONSerialization.jsonObject(with: messageData) as? [String: Any] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topic, forKey: .topic)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Convert message Dictionary to Data for storage
        let messageData = try JSONSerialization.data(withJSONObject: message)
        try container.encode(messageData, forKey: .message)
    }
}