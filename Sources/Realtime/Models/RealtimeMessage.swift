//
//  RealtimeMessage.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//
import Foundation

/// Message structure for encoding/decoding
struct RealtimeMessage: Codable {
    let client_Id: String
    let id: String
    let room: String
    let message: MessageContent
    let start: Int
    
    enum CodingKeys: String, CodingKey {
        case client_Id = "client_id"
        case id
        case room
        case message
        case start
    }
    
    init(client_Id: String, id: String, room: String, message: MessageContent, start: Int) {
        self.client_Id = client_Id
        self.id = id
        self.room = room
        self.message = message
        self.start = start
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle client_id as either String or Int
        if let clientIdString = try? container.decode(String.self, forKey: .client_Id) {
            self.client_Id = clientIdString
        } else if let clientIdInt = try? container.decode(Int.self, forKey: .client_Id) {
            self.client_Id = String(clientIdInt)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .client_Id,
                in: container,
                debugDescription: "client_id must be either a String or Int"
            )
        }
        
        self.id = try container.decode(String.self, forKey: .id)
        self.room = try container.decode(String.self, forKey: .room)
        self.message = try container.decode(MessageContent.self, forKey: .message)
        self.start = try container.decode(Int.self, forKey: .start)
    }

    enum MessageContent: Codable {
        case string(String)
        case number(Double)
        case json(Data)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let number = try? container.decode(Double.self) {
                self = .number(number)
            } else if let data = try? container.decode(Data.self) {
                self = .json(data)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Invalid message content")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let string):
                try container.encode(string)
            case .number(let number):
                try container.encode(number)
            case .json(let data):
                try container.encode(data)
            }
        }
    }
}
