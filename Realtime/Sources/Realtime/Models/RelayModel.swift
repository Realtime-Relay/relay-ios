//
//  File.swift
//  Relay
//
//  Created by Shaxzod on 02/04/25.
//

import Foundation


// MARK: - JetStream Response Models
struct StreamInfo: Codable {
    let config: StreamConfig
    let created: String
    let state: StreamState
}

struct StreamConfig: Codable {
    let name: String
    let subjects: [String]
    let retention: String
    let maxConsumers: Int
    let maxMsgsPerSubject: Int
    let maxMsgs: Int
    let maxBytes: Int
    let maxAge: Int64
    let storage: String
    let discard: String
    let numReplicas: Int
    
    private enum CodingKeys: String, CodingKey {
        case name, subjects, retention, storage, discard
        case maxConsumers = "max_consumers"
        case maxMsgsPerSubject = "max_msgs_per_subject"
        case maxMsgs = "max_msgs"
        case maxBytes = "max_bytes"
        case maxAge = "max_age"
        case numReplicas = "num_replicas"
    }
}

struct StreamState: Codable {
    let messages: Int
    let bytes: Int
    let firstSeq: Int
    let lastSeq: Int
    let consumer_count: Int
    
    private enum CodingKeys: String, CodingKey {
        case messages, bytes
        case firstSeq = "first_seq"
        case lastSeq = "last_seq"
        case consumer_count
    }
}

//struct JetStreamMessage: Codable {
//    let subject: String
//    let data: Data
//    let headers: [String: String]?
//}
