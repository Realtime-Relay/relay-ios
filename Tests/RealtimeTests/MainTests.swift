import XCTest
@testable import Realtime

final class MainTests: XCTestCase {
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
    
    // MARK: - Main Functionality Tests
    func testMainConnectionFlow() async throws {
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
        
        // Close connection
        try await realtime.close()
    }
    
    func testMainMessageHandling() async throws {
        try realtime.prepare(staging: true, opts: ["debug": true, "connection": mockConnectionSettings])
        
        let topic = "test_topic"
        let message = "test message"
        
        // Should fail to publish when not connected
        let publishSuccess = try await realtime.publish(topic: topic, message: message)
        XCTAssertFalse(publishSuccess, "Should not publish when disconnected")
        
        // Should fail to subscribe when not connected
        let listener = SharedTestMessageListener()
        let subscribeSuccess = try await realtime.on(topic: topic, listener: listener)
        XCTAssertFalse(subscribeSuccess, "Should not subscribe when disconnected")
        
        // Should fail to unsubscribe when not connected
        let unsubscribeSuccess = try await realtime.off(topic: topic)
        XCTAssertFalse(unsubscribeSuccess, "Should not unsubscribe when disconnected")
        
        // Should fail to get history when not connected
        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()
        await asyncAssertThrowsError(try await realtime.history(
            topic: topic,
            start: startDate,
            end: endDate,
            limit: 10
        ), "History retrieval should fail when disconnected")
    }
    
    func testMainSystemEvents() async throws {
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