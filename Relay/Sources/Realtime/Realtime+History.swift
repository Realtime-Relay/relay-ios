import Foundation
import Nats

extension Realtime {
    // MARK: - JetStream History
    
    /// Get message history from a stream
    /// - Parameters:
    ///   - stream: The stream to get history from
    ///   - subject: The subject to filter by
    ///   - limit: The maximum number of messages to get
    /// - Returns: Array of messages
    func getMessageHistory(stream: String, subject: String, limit: Int = 100) async throws -> [NatsMessage] {
        return try await realtimeActor.getMessageHistory(stream: stream, subject: subject, limit: limit)
    }

    /// Get message history for a topic
    /// - Parameters:
    ///   - topic: The topic to get history for
    ///   - startDate: Start date for history
    ///   - endDate: Optional end date for history
    /// - Returns: Array of messages
    public func history(topic: String, startDate: Date, endDate: Date? = nil) async throws -> [Any] {
        return try await realtimeActor.history(topic: topic, startDate: startDate, endDate: endDate)
    }
}

// MARK: - History Implementation
extension RealtimeActor {
    func getMessageHistory(stream: String, subject: String, limit: Int = 100) async throws -> [NatsMessage] {
        let natsClient = getNatsClient()
        let isDebug = isDebugEnabled()
        
        let consumerConfig: [String: Any] = [
            "stream_name": stream,
            "filter_subject": subject,
            "deliver_policy": "all",
            "ack_policy": "explicit"
        ]
        
        let createRequest: [String: Any] = [
            "stream_name": stream,
            "config": consumerConfig
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: createRequest)
        let createResponse = try await natsClient.request(
            jsonData,
            subject: NatsConstants.JetStream.Consumer.create(stream: stream)
        )
        
        guard let data = createResponse.payload,
              let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let consumerName = responseDict["name"] as? String else {
            throw RealtimeError.invalidResponse
        }
        
        // Subscribe to messages using the consumer
        let subscription = try await natsClient.subscribe(subject: NatsConstants.JetStream.Consumer.next(stream: stream, consumer: consumerName))
        var messages: [NatsMessage] = []
        
        // Get messages with timeout
        let task = Task {
            do {
                for try await message in subscription {
                    messages.append(message)
                    if messages.count >= limit {
                        break
                    }
                }
            } catch {
                if isDebug {
                    print("History subscription error: \(error)")
                }
            }
        }
        
        // Wait for messages or timeout
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        task.cancel()
        
        return messages
    }

    func history(topic: String, startDate: Date, endDate: Date? = nil) async throws -> [Any] {
        // Validate dates
        if let endDate = endDate, endDate < startDate {
            throw RealtimeError.invalidDate("endDate must be greater than or equal to startDate")
        }
        
        let currentNamespace = getCurrentNamespace()
        let streamName = "\(currentNamespace).stream"
        let finalTopic = "\(currentNamespace).stream.\(topic)"
        let natsClient = getNatsClient()
        let isDebug = isDebugEnabled()
        
        // First, get stream info
        let streamInfoRequest: [String: Any] = [
            "name": streamName
        ]
        
        if isDebug {
            print("Requesting stream info for: \(streamName)")
        }
        
        let streamInfoResponse = try await natsClient.request(
            try JSONSerialization.data(withJSONObject: streamInfoRequest),
            subject: NatsConstants.JetStream.Stream.info(stream: streamName),
            timeout: 10000 // 10 second timeout
        )
        
        guard let infoData = streamInfoResponse.payload else {
            if isDebug {
                print("No payload in stream info response")
            }
            return []
        }
        
        if isDebug {
            print("Stream info response: \(String(data: infoData, encoding: .utf8) ?? "no data")")
        }
        
        // Try to decode error response first
        if let errorString = String(data: infoData, encoding: .utf8),
           errorString.contains("stream not found") {
            if isDebug {
                print("Stream '\(streamName)' not found")
            }
            return []
        }
        
        // Create a consumer for fetching messages
        let consumerConfig: [String: Any] = [
            "stream_name": streamName,
            "deliver_policy": "all",
            "ack_policy": "explicit",
            "max_deliver": 1,
            "filter_subject": finalTopic,
            "num_replicas": 1
        ]
        
        let createRequest: [String: Any] = [
            "stream_name": streamName,
            "config": consumerConfig
        ]
        
        if isDebug {
            print("Creating consumer with config: \(String(data: try JSONSerialization.data(withJSONObject: createRequest), encoding: .utf8) ?? "invalid JSON")")
        }
        
        let createResponse = try await natsClient.request(
            try JSONSerialization.data(withJSONObject: createRequest),
            subject: NatsConstants.JetStream.Consumer.create(stream: streamName),
            timeout: 10000 // 10 second timeout
        )
        
        guard let createData = createResponse.payload,
              let responseDict = try? JSONSerialization.jsonObject(with: createData) as? [String: Any],
              let consumerName = responseDict["name"] as? String else {
            if isDebug {
                print("Failed to create consumer: \(String(describing: createResponse.payload))")
            }
            return []
        }
        
        if isDebug {
            print("Created consumer: \(consumerName)")
        }
        
        // Fetch messages using the consumer
        let batchRequest: [String: Any] = [
            "batch": 1000, // Fetch up to 1000 messages
            "no_wait": true
        ]
        
        let batchResponse = try await natsClient.request(
            try JSONSerialization.data(withJSONObject: batchRequest),
            subject: NatsConstants.JetStream.Consumer.next(stream: streamName, consumer: consumerName),
            timeout: 10000 // 10 second timeout
        )
        
        if isDebug {
            print("Batch response: \(String(data: batchResponse.payload ?? Data(), encoding: .utf8) ?? "no data")")
        }
        
        guard let data = batchResponse.payload,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            if isDebug {
                print("Failed to parse messages from response: \(String(describing: batchResponse.payload))")
            }
            return []
        }
        
        // Filter and transform messages
        return messages.compactMap { messageDict -> Any? in
            guard let data = messageDict["data"] as? String,
                  let jsonData = Data(base64Encoded: data),
                  let messageJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let messagePayload = messageJson["message"],
                  let startStr = messageJson["start"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: startStr) else {
                if isDebug {
                    print("Failed to parse message: \(messageDict)")
                }
                return nil
            }
            
            if timestamp >= startDate && (endDate == nil || timestamp <= endDate!) {
                return messagePayload
            }
            
            return nil
        }
    }
}
