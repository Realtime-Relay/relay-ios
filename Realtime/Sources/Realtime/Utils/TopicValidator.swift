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
    case systemTopicPublish

    public var errorDescription: String? {
        switch self {
        case .emptyTopic:
            return "Topic cannot be empty"
        case .containsSpaces:
            return "Topic cannot contain spaces"
        case .containsStar:
            return "Topic cannot contain '*' character"
        case .systemTopicPublish:
            return "Cannot publish to system topics"
        }
    }
}

public struct TopicValidator {
    public static func validate(
        _ topic: String, forPublishing: Bool = false, isInternalPublish: Bool = false
    ) throws {
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

        // Only check system topics for publishing from outside the SDK
        if forPublishing && !isInternalPublish && SystemEvent.reservedTopics.contains(topic) {
            throw TopicValidationError.systemTopicPublish
        }
    }
}
