import Foundation
import Realtime

// Create a chat message listener
class ChatMessageListener: MessageListener {
    var messageCount: Int = 0

    func onMessage(_ message: Any) {
        messageCount += 1
        print("\n📥 Received chat message:")
        if let messageDict = message as? [String: Any] {
            print("   From: \(messageDict["sender"] ?? "Unknown")")
            print("   Message: \(messageDict["text"] ?? "")")
            print("   Time: \(messageDict["timestamp"] ?? "")")
        } else {
            print("   Message: \(message)")
        }
    }
}

// Commented out: Other tests for fast feedback on latency logging
// import SystemEventTest
// import HistoryTest
// import PublishTests
// import RealtimeTests

// Run only the latency log test
Task {
    do {
        // print("\n=== Running System Event Tests ===")
        // if #available(iOS 15.0, *) {
        //     try await SystemEventTest.main()
        // } else {
        //     // Fallback on earlier versions
        // }
        // print("\n=== Running History Tests ===")
        // try await HistoryTest.main()
        // ...
        // print("\n=== Demonstrating Real-time Pub/Sub ===")
        // ...
        // print("\n=== Running Publish Tests ===")
        // try await PublishTests.main()
        // print("\n=== Running Realtime Tests ===")
        // try await RealtimeTests.main()

        // Only run the latency log test
        if #available(iOS 15.0, *) {
            try await LatencyLogTest.main()
        } else {
            print("LatencyLogTest requires iOS 15.0 or newer.")
        }
    } catch {
        print("\n❌ Error running tests:")
        print("   Error type: \(type(of: error))")
        print("   Description: \(error)")
        print("   Localized: \(error.localizedDescription)")
        if let relayError = error as? RelayError {
            print("   RelayError: \(relayError)")
        }
    }
    exit(0)
}

// Keep the main thread running
RunLoop.main.run()

