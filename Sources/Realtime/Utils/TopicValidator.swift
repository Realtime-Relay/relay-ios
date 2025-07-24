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
        _ topic: String?, forPublishing: Bool = false, isInternalPublish: Bool = false,
        isDebug: Bool = false
    ) throws {
        let reservedSystemTopics = [SystemEvent.connected.rawValue,
                                    SystemEvent.disconnected.rawValue,
                                    SystemEvent.reconnect.rawValue,
                                    SystemEvent.reconnected.rawValue,
                                    SystemEvent.reconnecting.rawValue,
                                    SystemEvent.reconn_failed.rawValue,
                                    SystemEvent.messageResend.rawValue
        ] as [String]
        
        // 1️⃣ Non‑nil, non‑empty string
        guard let topic, !topic.isEmpty else {
            throw TopicValidationError.invalidFormat("Invalid Topic")
        }

        // 2️⃣ Not in the reserved system list
        if reservedSystemTopics.contains(topic) {
            throw TopicValidationError.invalidFormat("Invalid Topic. Cannot be system topic")
        }

        // 3️⃣ Regex check — same pattern as the Node version
        let pattern = #"^(?!.*\$)(?:[A-Za-z0-9_*~-]+(?:\.[A-Za-z0-9_*~-]+)*(?:\.>)?|>)$"#

        guard topic.range(of: pattern,
                          options: [.regularExpression, .anchored]) != nil,
              !topic.contains(" ")                       // explicit space check
        else {
            throw TopicValidationError.invalidFormat("Invalid Topic")
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
