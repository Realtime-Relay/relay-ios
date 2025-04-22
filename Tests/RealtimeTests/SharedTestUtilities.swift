import XCTest
@testable import Realtime

// MARK: - Helper Classes
public class SharedTestMessageListener: MessageListener {
    public private(set) var messageCount = 0
    public private(set) var lastMessage: Any?
    
    public init() {}
    
    public func onMessage(_ message: Any) {
        messageCount += 1
        lastMessage = message
    }
}

// MARK: - Helper Extensions
public extension XCTestCase {
    func asyncAssertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: any Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
} 