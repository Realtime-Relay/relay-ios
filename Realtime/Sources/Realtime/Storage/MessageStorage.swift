//
//  MessageStorage.swift
//  Realtime
//
//  Created by Shaxzod on 04/04/25.
//

import Foundation

/// Stores messages locally when offline and handles resending them when reconnected
public class MessageStorage {
    private let userDefaults = UserDefaults.standard
    private let storageKey = "relay_stored_messages"

    public init() {}

    /// Stores a message for later sending
    public func storeMessage(topic: String, message: [String: Any]) {
        var storedMessages = getStoredMessages()
        let storedMessage = StoredMessage(topic: topic, message: message)
        storedMessages.append(storedMessage)
        saveMessages(storedMessages)
    }

    /// Retrieves all stored messages
    public func getStoredMessages() -> [StoredMessage] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }

        do {
            let messages = try JSONDecoder().decode([StoredMessage].self, from: data)
            return messages
        } catch {
            print("Error decoding stored messages: \(error)")
            return []
        }
    }

    /// Updates the resent status of a message
    public func updateMessageStatus(topic: String, messageId: String, resent: Bool) {
        var storedMessages = getStoredMessages()
        if let index = storedMessages.firstIndex(where: {
            $0.topic == topic && $0.message["id"] as? String == messageId
        }) {
            storedMessages[index].message["resent"] = resent
            saveMessages(storedMessages)
        }
    }

    /// Get message statuses for MESSAGE_RESEND event
    func getMessageStatuses() -> [[String: Any]] {
        return getStoredMessages().map { message in
            [
                "topic": message.topic,
                "message": message.message,
                "resent": message.resent,
            ]
        }
    }

    /// Removes all stored messages
    public func clearStoredMessages() {
        userDefaults.removeObject(forKey: storageKey)
    }

    public func removeMessage(topic: String, messageId: String) {
        var storedMessages = getStoredMessages()
        storedMessages.removeAll { message in
            message.topic == topic && message.message["id"] as? String == messageId
        }
        saveMessages(storedMessages)
    }

    private func saveMessages(_ messages: [StoredMessage]) {
        do {
            let data = try JSONEncoder().encode(messages)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("Error saving messages: \(error)")
        }
    }
}

/// Represents a message stored locally
public struct StoredMessage: Codable {
    public let topic: String
    public var message: [String: Any]
    public var resent: Bool

    private enum CodingKeys: String, CodingKey {
        case topic
        case message
        case resent
    }

    public init(topic: String, message: [String: Any]) {
        self.topic = topic
        self.message = message
        self.resent = false
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topic = try container.decode(String.self, forKey: .topic)
        resent = try container.decode(Bool.self, forKey: .resent)

        let messageData = try container.decode(Data.self, forKey: .message)
        message = try JSONSerialization.jsonObject(with: messageData) as? [String: Any] ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topic, forKey: .topic)
        try container.encode(resent, forKey: .resent)

        let messageData = try JSONSerialization.data(withJSONObject: message)
        try container.encode(messageData, forKey: .message)
    }
}
