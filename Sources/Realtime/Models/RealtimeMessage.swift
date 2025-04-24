//
//  RealtimeMessage.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//
import Foundation

/// Message structure for encoding/decoding
struct RealtimeMessage: Codable {
    let client_id: String
    let id: String
    let room: String
    let message: MessageContent
    let start: Int
    
    enum CodingKeys: String, CodingKey, CaseIterable {
        case client_id
        case id
        case room
        case message
        case start
    }
    
    init(client_Id: String, id: String, room: String, message: MessageContent, start: Int) {
        self.client_id = client_Id
        self.id = id
        self.room = room
        self.message = message
        self.start = start
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Debug: Print raw container contents
        print("\n🔍 Raw Container Contents:")
        for key in CodingKeys.allCases {
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                print("  \(key.rawValue): \(value)")
            }
        }
        
        // Handle client_id with more flexible decoding
        do {
            if let clientIdString = try? container.decode(String.self, forKey: .client_id) {
                self.client_id = clientIdString
                print("  Decoded client_id as String: \(clientIdString)")
            } else if let clientIdInt = try? container.decode(Int.self, forKey: .client_id) {
                self.client_id = String(clientIdInt)
                print("  Decoded client_id as Int: \(clientIdInt)")
            } else if let clientIdDouble = try? container.decode(Double.self, forKey: .client_id) {
                self.client_id = String(Int(clientIdDouble))
                print("  Decoded client_id as Double: \(clientIdDouble)")
            } else {
                // Try to get raw value
                let rawValue = try container.decodeIfPresent(String.self, forKey: .client_id) ?? "unknown"
                self.client_id = rawValue
                print("  Decoded client_id as raw value: \(rawValue)")
            }
        } catch {
            print("  ❌ Error decoding client_id: \(error)")
            throw error
        }
        
        do {
            self.id = try container.decode(String.self, forKey: .id)
            print("  Decoded id: \(self.id)")
        } catch {
            print("  ❌ Error decoding id: \(error)")
            throw error
        }
        
        do {
            self.room = try container.decode(String.self, forKey: .room)
            print("  Decoded room: \(self.room)")
        } catch {
            print("  ❌ Error decoding room: \(error)")
            throw error
        }
        
        do {
            self.message = try container.decode(MessageContent.self, forKey: .message)
            print("  Decoded message type: \(type(of: self.message))")
        } catch {
            print("  ❌ Error decoding message: \(error)")
            throw error
        }
        
        do {
            self.start = try container.decode(Int.self, forKey: .start)
            print("  Decoded start: \(self.start)")
        } catch {
            print("  ❌ Error decoding start: \(error)")
            throw error
        }
        
        print("  ✅ Successfully decoded all fields")
    }

    enum MessageContent: Codable {
        case string(String)
        case number(Double)
        case json(Data)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            // Debug: Print raw value type
            print("  🔍 Raw value type: \(type(of: try container.decode(Data.self)))")
            
            do {
                // First try to decode as binary data
                let data = try container.decode(Data.self)
                
                // Try to decode as JSON first
                if let json = try? JSONSerialization.jsonObject(with: data) {
                    self = .json(data)
                    print("    Message content type: JSON")
                    print("    Content: \(json)")
                    return
                }
                
                // Try to decode as string
                if let string = String(data: data, encoding: .utf8) {
                    self = .string(string)
                    print("    Message content type: String")
                    print("    Content: \(string)")
                    return
                }
                
                // If all else fails, store as raw data
                self = .json(data)
                print("    Message content type: Raw Data")
                print("    Size: \(data.count) bytes")
                
            } catch {
                // If binary decoding fails, try other types
                if let string = try? container.decode(String.self) {
                    self = .string(string)
                    print("    Message content type: String")
                    print("    Content: \(string)")
                } else if let number = try? container.decode(Double.self) {
                    self = .number(number)
                    print("    Message content type: Number")
                    print("    Content: \(number)")
                } else {
                    print("    ❌ Error decoding message content: \(error)")
                    throw error
                }
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
