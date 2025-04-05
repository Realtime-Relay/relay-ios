import Testing
@testable import Relay
import Foundation

@Suite("Realtime Tests")
final class RealtimeTests: @unchecked Sendable {
    private var realtime: Realtime!
    private let testSubject = "test.subject"
    private let testStream = "test.stream"
    private let retryCount = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1 second
    private let timeout: UInt64 = 10_000_000_000 // 10 seconds
    
    init() async throws {
        realtime = try Realtime(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        try await connectWithRetry()
    }
    
    private func connectWithRetry() async throws {
        var lastError: Error?
        for _ in 0..<retryCount {
            do {
                try await realtime.connect()
                return
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: retryDelay)
            }
        }
        throw lastError ?? NSError(domain: "RealtimeTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect after \(retryCount) attempts"])
    }
    
    deinit {
        let realtime = self.realtime
        Task {
            try? await realtime?.disconnect()
        }
    }
    
    @Test("Basic Connection Test")
    func testConnection() async throws {
        let result = try await realtime.publish(subject: testSubject, message: "test")
        #expect(result, "Publishing should succeed if connected")
    }
    
    @Test("Publish and Subscribe Test")
    func testPublishSubscribe() async throws {
        // Subscribe first
        let subscription = try await realtime.subscribe(subject: testSubject)
        let testMessage = "Test message for subscription"
        
        // Start a task to receive messages
        let receivedMessage = Task<String?, Error> {
            for try await message in subscription {
                return message.string
            }
            return nil
        }
        
        // Publish a message
        _ = try await realtime.publish(subject: testSubject, message: testMessage)
        
        // Wait for the message with timeout
        let message = try await withTimeout(seconds: 10) {
            try await receivedMessage.value
        }
        
        #expect(message == testMessage, "Received message should match published message")
    }
    
    @Test("JSON Message Test")
    func testJSONMessage() async throws {
        struct TestMessage: Codable {
            let id: Int
            let text: String
        }
        
        // Subscribe first
        let subscription = try await realtime.subscribe(subject: testSubject)
        let testMessage = TestMessage(id: 1, text: "Test message")
        
        // Start a task to receive messages
        let receivedMessage = Task<TestMessage?, Error> {
            for try await message in subscription {
                if let decodedMessage = try? message.json() as TestMessage {
                    return decodedMessage
                }
            }
            return nil
        }
        
        // Publish a message
        _ = try await realtime.publish(subject: testSubject, object: testMessage)
        
        // Wait for the message with timeout
        let message = try await withTimeout(seconds: 10) {
            try await receivedMessage.value
        }
        
        #expect(message?.id == 1, "Message ID should be 1")
        #expect(message?.text == "Test message", "Message text should match")
    }
    
    @Test("Stream Test")
    func testStream() async throws {
        let realtime = self.realtime!
        let testSubject = self.testSubject
        
        // Subscribe first to ensure we don't miss any messages
        let subscription = try await realtime.subscribe(subject: testSubject)
        
        // Publish multiple messages
        let testMessages = [
            "First message",
            "Second message",
            "Third message"
        ]
        
        // Start a task to collect messages
        let receivedMessages = Task<[String], Error> {
            var messages: [String] = []
            for try await message in subscription {
                if let string = message.string {
                    messages.append(string)
                }
                if messages.count >= testMessages.count {
                    break
                }
            }
            return messages
        }
        
        // Publish messages
        for message in testMessages {
            _ = try await realtime.publish(subject: testSubject, message: message)
        }
        
        // Wait for messages with timeout
        let messages = try await withTimeout(seconds: 10) {
            try await receivedMessages.value
        }
        
        // Verify message count
        #expect(messages.count == testMessages.count, "Should receive all published messages")
        
        // Verify message contents
        for message in testMessages {
            #expect(messages.contains(message), "Should receive message: \(message)")
        }
    }
    
    // Helper function for timeouts
    private func withTimeout<T: Sendable>(seconds: UInt64, _ operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw NSError(domain: "RealtimeTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
