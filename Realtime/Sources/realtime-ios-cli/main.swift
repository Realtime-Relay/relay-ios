import Foundation

struct RealtimeCLI {
    static func main() async throws {
//        print("\n=== Message Encoding Test ===")
//        let messageEncodingTest = MessageEncodingTest()
//        try await messageEncodingTest.run()
//        
//        print("\n=== System Event Test ===")
//        if #available(iOS 15.0, *) {
//            try await SystemEventTest.main()
//        }
        
        print("\nAll tests completed.")
    }
}

// Run the tests
Task {
    do {
        try await RealtimeCLI.main()
    } catch {
        print("Error running tests: \(error)")
    }
    exit(0)
}

// Keep the main thread running
RunLoop.main.run()
