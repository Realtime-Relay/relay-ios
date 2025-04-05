//
//  File.swift
//  Relay
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation

public enum TopicValidationError: LocalizedError {
    case emptyTopic
    case containsSpaces
    case containsStar
    case systemTopic
    
    public var errorDescription: String? {
        switch self {
        case .emptyTopic:
            return "Topic cannot be empty"
        case .containsSpaces:
            return "Topic cannot contain spaces"
        case .containsStar:
            return "Topic cannot contain '*' character"
        case .systemTopic:
            return "Cannot publish to system topics"
        }
    }
}

public struct TopicValidator {
    private static let systemTopics: Set<String> = [
        "CONNECTED",
        "RECONNECT",
        "MESSAGE_RESEND",
        "DISCONNECTED",
        "RECONNECTING",
        "RECONNECTED",
        "RECONN_FAIL"
    ]
    
    public static func validate(_ topic: String) throws {
        // Check if topic is empty
        guard !topic.isEmpty else {
            throw TopicValidationError.emptyTopic
        }
        
        // Check for spaces
        guard !topic.contains(" ") else {
            throw TopicValidationError.containsSpaces
        }
        
        // Check for star character
        guard !topic.contains("*") else {
            throw TopicValidationError.containsStar
        }
        
        // Check if it's a system topic
        guard !systemTopics.contains(topic.uppercased()) else {
            throw TopicValidationError.systemTopic
        }
    }
} 
