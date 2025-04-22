import XCTest
@testable import Realtime

final class RealtimeTests: XCTestCase {
    // MARK: - Properties
    private var realtime: Realtime!
    private let testApiKey = "test_api_key"
    private let testSecret = "test_secret"
    private let mockConnectionSettings: [String: Any] = ["host": "localhost", "port": 4222]
    
    // MARK: - Setup & Teardown
    override func setUp() async throws {
        try await super.setUp()
        realtime = try Realtime(apiKey: testApiKey, secret: testSecret)
    }
    
    override func tearDown() async throws {
        try await realtime.close()
        realtime = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
    func testInitialization() throws {
        XCTAssertNotNil(realtime, "Realtime instance should be initialized")
    }
    
    func testConnection() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        // Try to connect (should fail)
        await asyncAssertThrowsError(try await realtime.connect(), "Connection should fail")
    }
    
    func testDisconnection() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        // Try to connect (should fail)
        await asyncAssertThrowsError(try await realtime.connect(), "Connection should fail")
        
        // Close connection
        try await realtime.close()
    }
    
    func testPublishMessage() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        let topic = "test_topic"
        let message = "test message"
        
        // Should fail to publish when not connected
        let success = try await realtime.publish(topic: topic, message: message)
        XCTAssertFalse(success, "Should not publish when disconnected")
    }
    
    func testSubscribeToTopic() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        let topic = "test_topic"
        let listener = SharedTestMessageListener()
        
        // Should fail to subscribe when not connected
        let success = try await realtime.on(topic: topic, listener: listener)
        XCTAssertFalse(success, "Should not subscribe when disconnected")
    }
    
    func testUnsubscribeFromTopic() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        let topic = "test_topic"
        
        // Should fail to unsubscribe when not connected
        let success = try await realtime.off(topic: topic)
        XCTAssertFalse(success, "Should not unsubscribe when disconnected")
    }
    
    func testGetMessageHistory() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        let topic = "test_topic"
        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()
        
        // Should fail to get history when not connected
        await asyncAssertThrowsError(try await realtime.history(
            topic: topic,
            start: startDate,
            end: endDate,
            limit: 10
        ), "History retrieval should fail when disconnected")
    }
    
    func testSystemEvents() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        let connectedListener = SharedTestMessageListener()
        let disconnectedListener = SharedTestMessageListener()
        let reconnectingListener = SharedTestMessageListener()
        
        // Set up system event listeners
        _ = try await realtime.on(topic: SystemEvent.connected.rawValue, listener: connectedListener)
        _ = try await realtime.on(topic: SystemEvent.disconnected.rawValue, listener: disconnectedListener)
        _ = try await realtime.on(topic: SystemEvent.reconnecting.rawValue, listener: reconnectingListener)
        
        // Try to connect (should fail)
        await asyncAssertThrowsError(try await realtime.connect(), "Connection should fail")
        
        // Verify initial state
        XCTAssertEqual(connectedListener.messageCount, 0, "Should not receive connected event")
        XCTAssertEqual(reconnectingListener.messageCount, 0, "Should not receive reconnecting event")
        
        // Close connection
        try await realtime.close()
    }
} 