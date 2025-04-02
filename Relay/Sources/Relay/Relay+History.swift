import Foundation
@preconcurrency import Nats

extension Relay {
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
    ) async throws -> [NatsMessage] {
        // First, get stream info to get the first and last sequence
        let streamInfoRequest = ["stream_name": stream]
        let streamInfoResponse = try await natsConnection.request(
            try JSONEncoder().encode(streamInfoRequest),
            subject: NatsConstants.JetStream.Stream.info(stream: stream)
        )
        
        guard let infoData = streamInfoResponse.payload,
              let streamInfo = try? JSONDecoder().decode(StreamInfo.self, from: infoData) else {
            throw RelayError.invalidResponse
        }
        
        // Calculate the sequence range to fetch
        let startSeq = max(1, streamInfo.state.firstSequence)
        let endSeq = min(streamInfo.state.lastSequence, startSeq + limit - 1)
        
        // Fetch messages in batches
        var messages: [NatsMessage] = []
        
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
    ) async throws -> [NatsMessage] {
        let streamInfoRequest = ["stream_name": stream]
        let streamInfoResponse = try await natsConnection.request(
            try JSONEncoder().encode(streamInfoRequest),
            subject: NatsConstants.JetStream.Stream.info(stream: stream)
        )
        
        guard let infoData = streamInfoResponse.payload,
              let streamInfo = try? JSONDecoder().decode(StreamInfo.self, from: infoData) else {
            throw RelayError.invalidResponse
        }
        
        let endSeq = min(streamInfo.state.lastSequence, Int(sequence) + limit - 1)
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
    ) async throws -> [NatsMessage] {
        var messages: [NatsMessage] = []
        
        for seq in startSeq...endSeq {
            let request = ["seq": seq]
            
            let response = try await natsConnection.request(
                try JSONEncoder().encode(request),
                subject: NatsConstants.JetStream.Stream.message(stream: stream)
            )
            
            // Apply subject filter if specified
            if let subject = subject, response.subject != subject {
                continue
            }
            
            messages.append(response)
        }
        
        return messages
    }
}
