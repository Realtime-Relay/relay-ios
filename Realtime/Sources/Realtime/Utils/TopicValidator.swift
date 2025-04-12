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
    case containsPeriod
    case systemTopicPublish
    case invalidFormat(String)

    public var errorDescription: String? {
        switch self {
        case .emptyTopic:
            return "Topic cannot be empty"
        case .containsSpaces:
            return "Topic cannot contain spaces"
        case .containsStar:
            return "Topic cannot contain '*' character"
        case .containsPeriod:
            return "Topic cannot contain '.' character"
        case .systemTopicPublish:
            return "Cannot publish to system topics"
        case .invalidFormat(let message):
            return message
        }
    }
}

public struct TopicValidator {
    public static func validate(
        _ topic: String, forPublishing: Bool = false, isInternalPublish: Bool = false,
        isDebug: Bool = false
    ) throws {
        // Check if topic is empty
        guard !topic.isEmpty else {
            if isDebug {
                print("❌ Invalid topic: empty")
            }
            throw TopicValidationError.emptyTopic
        }

        // Check for spaces
        guard !topic.contains(" ") else {
            if isDebug {
                print("❌ Invalid topic: contains spaces")
            }
            throw TopicValidationError.containsSpaces
        }

        // Check for star character
        guard !topic.contains("*") else {
            if isDebug {
                print("❌ Invalid topic: contains asterisk (*)")
            }
            throw TopicValidationError.containsStar
        }

        // Check for period character
        guard !topic.contains(".") else {
            if isDebug {
                print("❌ Invalid topic: contains period (.)")
            }
            throw TopicValidationError.containsPeriod
        }

        // Only check system topics for publishing from outside the SDK
        if forPublishing && !isInternalPublish && SystemEvent.reservedTopics.contains(topic) {
            if isDebug {
                print("❌ Invalid topic: cannot publish to system topics")
            }
            throw TopicValidationError.systemTopicPublish
        }
    }

    public static func formatTopic(_ topic: String, namespace: String, isDebug: Bool = false) throws
        -> String
    {
        // First validate the raw topic
        try validate(topic, isDebug: isDebug)

        // Format: namespace_stream_topic
        let formattedTopic = topic.components(separatedBy: ".").joined(separator: "_")
        let finalTopic = [namespace, "stream", formattedTopic].joined(separator: "_")

        if isDebug {
            print("✅ Formatted topic: \(finalTopic)")
        }

        return finalTopic
    }

    public static func extractRawTopic(from formattedTopic: String, isDebug: Bool = false) throws
        -> String
    {
        // Split the formatted topic and get the last component
        guard let rawTopic = formattedTopic.split(separator: "_").last else {
            if isDebug {
                print("❌ Invalid topic format: \(formattedTopic)")
            }
            throw TopicValidationError.invalidFormat("Invalid topic format: \(formattedTopic)")
        }

        // Convert underscores back to periods
        let extractedTopic = rawTopic.replacingOccurrences(of: "_", with: ".")

        if isDebug {
            print("✅ Extracted raw topic: \(extractedTopic)")
        }

        return extractedTopic
    }

    public static func formatRoom(_ room: String, isDebug: Bool = false) throws -> String {
        // First validate the room
        try validate(room, isDebug: isDebug)

        // Convert underscores to periods
        let formattedRoom = room.replacingOccurrences(of: "_", with: ".")

        if isDebug {
            print("✅ Formatted room: \(formattedRoom)")
        }

        return formattedRoom
    }
}
