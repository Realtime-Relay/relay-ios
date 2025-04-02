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
    let state: StreamState
}

struct StreamConfig: Codable {
    let name: String
    let subjects: [String]
    let retention: String
    let maxConsumers: Int
    let maxMsgsPerSubject: Int
    let maxMsgs: Int
    let maxAge: Int
    let maxBytes: Int
}

struct StreamState: Codable {
    let messages: Int
    let bytes: Int
    let firstSequence: Int
    let lastSequence: Int
    let consumerCount: Int
}

struct JetStreamMessage: Codable {
    let subject: String
    let data: Data
    let headers: [String: String]?
}
