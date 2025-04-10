//
//  RealtimeMessage.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//
import Foundation

/// Message structure for encoding/decoding
struct RealtimeMessage: Codable {
    let clientId: String
    let id: String
    let room: String
    let message: MessageContent
    let start: Int
    
    enum MessageContent: Codable {
        case string(String)
        case integer(Int)
        case json(Data)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let integer = try? container.decode(Int.self) {
                self = .integer(integer)
            } else if let data = try? container.decode(Data.self) {
                self = .json(data)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid message content")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let string):
                try container.encode(string)
            case .integer(let integer):
                try container.encode(integer)
            case .json(let data):
                try container.encode(data)
            }
        }
    }
}
