import XCTest
@testable import Realtime
import Foundation

final class RealtimeTests: XCTestCase {
    var realtime: Realtime!
    let testTopic = "test_topic"
    let opts: [String: Any] = [
        "apiKey": "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
        "secretKey": "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4",
        "debug": true
    ]
    
    // Actor to handle shared state safely
    private actor TestState {
        var receivedCount: Int = 0
        var receivedMessage: Any?
        
        func incrementCount() {
            receivedCount += 1
        }
        
        func setMessage(_ message: Any) {
            receivedMessage = message
        }
        
        func getCount() -> Int {
            receivedCount
        }
        
        func getMessage() -> Any? {
            receivedMessage
        }
        
        func reset() {
            receivedCount = 0
            receivedMessage = nil
        }
    }
    
    private let testState = TestState()
    
    override func setUp() async throws {
        print("Starting test setup...")
        
        print("Creating Realtime instance...")
        realtime = try await Realtime(staging: true, opts: opts)
        
        print("Connecting with retry...")
        try await connectWithRetry()
        
        print("Setup complete")
    }
    
    override func tearDown() async throws {
        print("Starting test teardown...")
        if realtime != nil {
            try await realtime.close()
            print("Closed Realtime connection")
        }
        print("Teardown complete")
    }
    
    func connectWithRetry(maxAttempts: Int = 3) async throws {
        var attempts = 0
        var lastError: Error?
        
        while attempts < maxAttempts {
            do {
                print("Attempting to connect (attempt \(attempts + 1)/\(maxAttempts))...")
                try await withTimeout(seconds: 15.0) { [self] in
                    try await self.realtime.connect()
                }
                print("Connection successful!")
                return
            } catch {
                lastError = error
                attempts += 1
                if attempts < maxAttempts {
                    print("Connection failed, retrying in 2 seconds...")
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        
        throw lastError ?? RealtimeError.connectionFailed
    }
    
    func testConnection() async throws {
        print("Starting connection test...")
        
        // Test the connection
        let isConnected = await realtime.realtimeActor.isConnected
        XCTAssertTrue(isConnected, "Should be connected after setup")
        
        // Test a simple publish with increased timeout
        let testMessage = "Hello from test!"
        
        print("Publishing test message...")
        let published = try await withTimeout(seconds: 15.0) { [self] in
            try await self.realtime.publish(topic: self.testTopic, message: testMessage)
        }
        XCTAssertTrue(published, "Message should be published successfully")
        
        // Give more time for the publish to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        print("Connection test completed")
    }
    
    func testSubscription() async throws {
        print("Starting subscription test...")
        
        let expectation = XCTestExpectation(description: "Message received")
        let testMessage = "Test message"
        
        // Subscribe first
        try await realtime.on(topic: testTopic) { message in
            if let message = message as? String, message == testMessage {
                expectation.fulfill()
            }
        }
        
        // Publish a message
        let published = try await realtime.publish(topic: testTopic, message: testMessage)
        XCTAssertTrue(published, "Message should be published successfully")
        
        // Wait for the message
        await fulfillment(of: [expectation], timeout: 5)
        
        print("Subscription test completed")
    }
    
    func testHistory() async throws {
        print("Starting history test...")
        
        let testMessages = ["Message 1", "Message 2", "Message 3"]
        let startDate = Date()
        
        // Publish messages with delay between each
        for message in testMessages {
            let published = try await realtime.publish(topic: testTopic, message: message)
            XCTAssertTrue(published, "Message should be published successfully")
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds between messages
        }
        
        // Wait for messages to be stored
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Get history
        let messages = try await realtime.history(topic: testTopic, startDate: startDate)
        
        // Verify message count
        XCTAssertEqual(messages.count, testMessages.count, "Should receive all published messages")
        
        // Verify message content
        for (index, message) in messages.enumerated() {
            XCTAssertEqual(message as? String, testMessages[index], "Message content should match")
        }
        
        print("History test completed")
    }
    
    func testUnsubscribe() async throws {
        print("Starting unsubscribe test...")
        
        let messageCount = ActorIsolated(0)
        
        // Subscribe first
        try await realtime.on(topic: testTopic) { _ in
            Task {
                await messageCount.setValue(await messageCount.value + 1)
            }
        }
        
        // Publish a message
        let published = try await realtime.publish(topic: testTopic, message: "test")
        XCTAssertTrue(published, "Message should be published successfully")
        
        // Wait for the message
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        let count = await messageCount.value
        XCTAssertEqual(count, 1, "Should receive first message")
        
        // Unsubscribe
        let unsubscribed = try await realtime.off(topic: testTopic)
        XCTAssertTrue(unsubscribed, "Unsubscribe should succeed")
        
        // Publish another message
        let publishedAfter = try await realtime.publish(topic: testTopic, message: "test after unsubscribe")
        XCTAssertTrue(publishedAfter, "Message should be published successfully")
        
        // Wait to ensure no more messages are received
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        let finalCount = await messageCount.value
        XCTAssertEqual(finalCount, 1, "Should not receive messages after unsubscribe")
        
        print("Unsubscribe test completed")
    }
}

actor ActorIsolated<T> {
    private var _value: T
    
    init(_ value: T) {
        self._value = value
    }
    
    var value: T {
        get { _value }
    }
    
    func setValue(_ newValue: T) {
        _value = newValue
    }
}

private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NSError(domain: "RealtimeTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
} 