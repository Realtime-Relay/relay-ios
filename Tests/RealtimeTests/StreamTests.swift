import XCTest
@testable import Realtime
import Nats
import JetStream

final class StreamTests: XCTestCase {
    var realtime: Realtime!
    
    override func setUp() async throws {
        super.setUp()
        
        // Initialize Realtime with test credentials
        realtime = try Realtime(
            apiKey: "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        
        // Configure for staging and debug mode
        try realtime.prepare(staging: true, opts: ["debug": true])
        
        // Connect to NATS
        try await realtime.connect()
    }
    
    override func tearDown() async throws {
        try await realtime.disconnect()
        realtime = nil
        super.tearDown()
    }
    
    func testCreateNewStream() async throws {
        // Test creating a new stream
        let topic = "test.create.stream"
        
        // Create a new stream
        try await realtime.createOrGetStream(for: topic)
        
        // Verify stream exists by trying to publish a message
        let success = try await realtime.publish(topic: topic, message: "Test message")
        XCTAssertTrue(success, "Should successfully publish to newly created stream")
    }
    
    func testGetExistingStream() async throws {
        let topic = "test.existing.stream"
        
        // First create the stream
        try await realtime.createOrGetStream(for: topic)
        
        // Try to get the same stream again
        try await realtime.createOrGetStream(for: topic)
        
        // Verify stream works by publishing
        let success = try await realtime.publish(topic: topic, message: "Test message")
        XCTAssertTrue(success, "Should successfully publish to existing stream")
    }
    
    func testStreamWithMultipleSubjects() async throws {
        let topic1 = "test.multi.1"
        let topic2 = "test.multi.2"
        
        // Create stream with first topic
        try await realtime.createOrGetStream(for: topic1)
        
        // Add second topic to same stream
        try await realtime.createOrGetStream(for: topic2)
        
        // Verify both topics work
        let success1 = try await realtime.publish(topic: topic1, message: "Test message 1")
        let success2 = try await realtime.publish(topic: topic2, message: "Test message 2")
        
        XCTAssertTrue(success1, "Should successfully publish to first topic")
        XCTAssertTrue(success2, "Should successfully publish to second topic")
    }
    
    func testStreamCreationWhenDisconnected() async throws {
        let topic = "test.disconnected"
        
        // Disconnect first
        try await realtime.disconnect()
        
        do {
            try await realtime.createOrGetStream(for: topic)
            XCTFail("Should throw error when disconnected")
        } catch {
            XCTAssertTrue(error is RelayError, "Should throw RelayError.notConnected")
        }
    }
    
    func testStreamWithInvalidTopic() async throws {
        let invalidTopic = ""
        
        do {
            try await realtime.createOrGetStream(for: invalidTopic)
            XCTFail("Should throw error for invalid topic")
        } catch {
            XCTAssertTrue(error is TopicValidationError, "Should throw TopicValidationError")
        }
    }
    
    static var allTests = [
        ("testCreateNewStream", testCreateNewStream),
        ("testGetExistingStream", testGetExistingStream),
        ("testStreamWithMultipleSubjects", testStreamWithMultipleSubjects),
        ("testStreamCreationWhenDisconnected", testStreamCreationWhenDisconnected),
        ("testStreamWithInvalidTopic", testStreamWithInvalidTopic)
    ]
} 