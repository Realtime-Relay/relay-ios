import Foundation
@preconcurrency import Nats

extension Realtime {
    // MARK: - JetStream History
    
    /// Get message history from a stream
    /// - Parameters:
    ///   - stream: Name of the stream
    ///   - subject: Subject filter (optional)
    ///   - limit: Maximum number of messages to return
    ///   - batchSize: Number of messages to fetch in each batch (default: 50)
    /// - Returns: Array of messages
    public func getMessageHistory(
        stream: String,
        subject: String? = nil,
        limit: Int = 100,
        batchSize: Int = 50
    ) async throws -> [Message] {
        // First, get stream info to get the first and last sequence
        let streamInfoRequest: [String: Any] = [
            "name": stream
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: streamInfoRequest)
        let streamInfoResponse = try await natsConnection.request(
            jsonData,
            subject: NatsConstants.JetStream.Stream.info(stream: stream),
            timeout: 5.0
        )
        
        guard let infoData = streamInfoResponse.payload else {
            print("No payload in stream info response")
            throw RelayError.invalidResponse
        }
        
        // Try to decode error response first
        if let errorString = String(data: infoData, encoding: .utf8),
           errorString.contains("stream not found") {
            print("Stream '\(stream)' not found")
            return []
        }
        
        guard let streamInfo = try? JSONDecoder().decode(StreamInfo.self, from: infoData) else {
            print("Failed to decode stream info response: \(String(data: infoData, encoding: .utf8) ?? "no data")")
            throw RelayError.invalidResponse
        }
        
        // Calculate the sequence range to fetch
        let startSeq = max(1, streamInfo.state.firstSeq)
        let endSeq = min(streamInfo.state.lastSeq, startSeq + limit - 1)
        
        // Fetch messages in batches
        var messages: [Message] = []
        
        for batchStart in stride(from: startSeq, through: endSeq, by: batchSize) {
            let batchEnd = min(batchStart + batchSize - 1, endSeq)
            let batchMessages = try await fetchMessagesInRange(
                stream: stream,
                startSeq: batchStart,
                endSeq: batchEnd,
                subject: subject
            )
            messages.append(contentsOf: batchMessages)
            
            if messages.count >= limit {
                break
            }
        }
        
        return Array(messages.prefix(limit))
    }
    
    /// Fetch messages after a specific sequence number
    /// - Parameters:
    ///   - stream: Name of the stream
    ///   - sequence: Sequence number to start from
    ///   - limit: Maximum number of messages to return
    /// - Returns: Array of messages
    public func fetchMessagesAfter(
        stream: String,
        sequence: UInt64,
        limit: Int = 100
    ) async throws -> [Message] {
        let streamInfoRequest = ["name": stream]
        let streamInfoResponse = try await natsConnection.request(
            try JSONSerialization.data(withJSONObject: streamInfoRequest),
            subject: NatsConstants.JetStream.Stream.info(stream: stream)
        )
        
        guard let infoData = streamInfoResponse.payload,
              let streamInfo = try? JSONDecoder().decode(StreamInfo.self, from: infoData) else {
            throw RelayError.invalidResponse
        }
        
        let endSeq = min(streamInfo.state.lastSeq, Int(sequence) + limit - 1)
        return try await fetchMessagesInRange(
            stream: stream,
            startSeq: Int(sequence),
            endSeq: endSeq
        )
    }
    
    // MARK: - Private Helpers
    
    private func fetchMessagesInRange(
        stream: String,
        startSeq: Int,
        endSeq: Int,
        subject: String? = nil
    ) async throws -> [Message] {
        var messages: [Message] = []
        
        // Create a consumer
        let consumerConfig: [String: Any] = [
            "stream_name": stream,
            "deliver_policy": "all",
            "ack_policy": "explicit",
            "max_deliver": 1,
            "filter_subject": subject ?? ">",
            "num_replicas": 1
        ]
        
        let createRequest: [String: Any] = [
            "stream_name": stream,
            "config": consumerConfig
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: createRequest)
        let createResponse = try await natsConnection.request(
            jsonData,
            subject: NatsConstants.JetStream.Stream.consumer(stream: stream),
            timeout: 5.0
        )
        
        if let data = createResponse.payload {
            print("Consumer creation response: \(String(data: data, encoding: .utf8) ?? "no data")")
            
            // Parse consumer name from response
            if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = responseDict["name"] as? String {
                
                // Fetch messages using the consumer
                let batchRequest: [String: Any] = [
                    "batch": endSeq - startSeq + 1,
                    "no_wait": true
                ]
                
                let batchData = try JSONSerialization.data(withJSONObject: batchRequest)
                let response = try await natsConnection.request(
                    batchData,
                    subject: NatsConstants.JetStream.Stream.consumerNext(stream: stream, consumer: name),
                    timeout: 5.0
                )
                
                if let data = response.payload {
                    print("Batch response: \(String(data: data, encoding: .utf8) ?? "no data")")
                    let message = Message(
                        subject: response.subject,
                        payload: response.payload ?? Data(),
                        sequence: 0,
                        replySubject: response.replySubject,
                        headers: nil,
                        status: .ok,
                        description: nil,
                        id: "",
                        timestamp: 0,
                        content: "",
                        clientId: ""
                    )
                    messages.append(message)
                }
            }
        }
        
        return messages
    }
}


//
//public func history(topic: String, minutes: Int = 5) async throws -> [Message] {
//    try validateAuth()
//    try TopicValidator.validate(topic)
//    
//    guard minutes > 0 else {
//        throw RelayError.invalidDate("Minutes must be greater than 0")
//    }
//    
//    try await ensureStreamExists()
//    
//    let consumerName = "history_\(UUID().uuidString)"
//    let startTime = Date().addingTimeInterval(-Double(minutes * 60))
//    
//    let consumerConfig: [String: Any] = [
//        "stream_name": streamName,
//        "config": [
//            "filter_subject": NatsConstants.Topics.formatTopic(topic),
//            "deliver_policy": "by_start_time",
//            "opt_start_time": ISO8601DateFormatter().string(from: startTime),
//            "ack_policy": "explicit",
//            "max_deliver": 1,
//            "num_replicas": 1,
//            "max_waiting": 1,
//            "max_batch": 100,
//            "max_expires": 5000000000
//        ]
//    ]
//    
//    let jsonData = try JSONSerialization.data(withJSONObject: consumerConfig)
//    let request = try await natsConnection.request(
//        jsonData,
//        subject: NatsConstants.JetStream.Stream.consumer(stream: streamName),
//        timeout: 5.0
//    )
//    
//    if isDebug {
//        print("Creating consumer with config:", String(data: jsonData, encoding: .utf8) ?? "")
//    }
//    
//    guard let payload = request.payload,
//          let response = String(data: payload, encoding: .utf8) else {
//        throw RelayError.invalidResponse
//    }
//    print("Consumer creation response:", response)
//    
//    // Request messages in batches
//    var allMessages: [Message] = []
//    var hasMore = true
//    
//    while hasMore {
//        let batchRequest: [String: Any] = [
//            "batch": 100,
//            "no_wait": true
//        ]
//        let batchData = try JSONSerialization.data(withJSONObject: batchRequest)
//        
//        let batchResponse = try await natsConnection.request(
//            batchData,
//            subject: NatsConstants.JetStream.Stream.consumerNext(stream: streamName, consumer: consumerName),
//            timeout: 1.0
//        )
//        
//        guard let payload = batchResponse.payload else {
//            hasMore = false
//            continue
//        }
//        
//        if let responseStr = String(data: payload, encoding: .utf8) {
//            print("Batch response:", responseStr)
//            
//            if responseStr.contains("no messages") {
//                hasMore = false
//            } else {
//                do {
//                    if let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
//                       let id = json["id"] as? String,
//                       let timestamp = json["timestamp"] as? Int64,
//                       let content = json["content"] as? String,
//                       let clientId = json["client_id"] as? String {
//                        
//                        let message = Message(
//                            subject: NatsConstants.Topics.formatTopic(topic),
//                            payload: payload,
//                            sequence: 0,
//                            replySubject: batchResponse.replySubject,
//                            headers: nil,
//                            status: .ok,
//                            description: nil,
//                            id: id,
//                            timestamp: timestamp,
//                            content: content,
//                            clientId: clientId
//                        )
//                        
//                        if Int64(message.timestamp) >= Int64(startTime.timeIntervalSince1970 * 1000) {
//                            allMessages.append(message)
//                        }
//                    }
//                } catch {
//                    print("Failed to decode message:", error)
//                    hasMore = false
//                }
//            }
//        } else {
//            hasMore = false
//        }
//    }
//    
//    // Delete the consumer
//    _ = try? await natsConnection.request(
//        Data(),
//        subject: "\(NatsConstants.JetStream.apiPrefix).CONSUMER.DELETE.\(streamName).\(consumerName)",
//        timeout: 5.0
//    )
//    
//    print("Retrieved \(allMessages.count) messages")
//    return allMessages
//}
