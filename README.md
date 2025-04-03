# Relay

A modern, thread-safe Swift package for NATS messaging in iOS and macOS applications. Relay simplifies NATS communication by handling complex threading operations and providing a clean, Swift-native API.

## 🚀 Features

- **Thread-Safe Operations**: All operations are automatically handled on appropriate threads
- **Automatic Connection Management**: Handles connection lifecycle and reconnection
- **Main Thread Callbacks**: UI updates are automatically dispatched to the main thread
- **JSON Support**: Built-in JSON encoding/decoding for Swift types
- **Request-Reply Pattern**: Support for request-reply messaging pattern
- **Stream Support**: Create and manage NATS streams
- **Message History**: Retrieve message history from streams
- **Error Handling**: Comprehensive error handling with Swift's Result type
- **Async/Await Support**: Modern concurrency support with async/await

## 📋 Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 14.0+

## 📦 Installation

### Swift Package Manager

Add Relay to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/relay-ios.git", from: "1.0.0")
]
```

## 🎯 Quick Start

### 1. Initialize Relay

```swift
import Relay

// Configure NATS servers
let servers = [
    "nats://api.yout-project:4221",
    "nats://api.yout-project:4222",
    "nats://api.yout-project:4223"
]

// Create Relay instance
let relay = Relay(
    servers: servers,
    apiKey: "your-api-key",
    secret: "your-secret"
)
```

### 2. Connect to Server

```swift
// Using completion handler
relay.connect { result in
    switch result {
    case .success:
        print("Connected to NATS server")
    case .failure(let error):
        print("Failed to connect: \(error)")
    }
}

// Using async/await
do {
    try await relay.connect()
    print("Connected to NATS server")
} catch {
    print("Failed to connect: \(error)")
}
```

### 3. Publish Messages

```swift
// Publish string message
relay.publish(subject: "test.subject", message: "Hello, NATS!") { result in
    switch result {
    case .success:
        print("Message published successfully")
    case .failure(let error):
        print("Failed to publish: \(error)")
    }
}

// Publish JSON object
struct Message: Codable {
    let content: String
    let timestamp: Date
}

let message = Message(content: "Hello", timestamp: Date())
relay.publish(subject: "test.subject", object: message) { result in
    switch result {
    case .success:
        print("JSON message published successfully")
    case .failure(let error):
        print("Failed to publish JSON: \(error)")
    }
}
```

### 4. Subscribe to Messages

```swift
// Subscribe to string messages
relay.subscribe(subject: "test.subject") { result in
    switch result {
    case .success(let message):
        print("Received message: \(message)")
    case .failure(let error):
        print("Error receiving message: \(error)")
    }
}

// Subscribe to JSON messages
relay.subscribe(subject: "test.subject", type: Message.self) { result in
    switch result {
    case .success(let message):
        print("Received message: \(message.content) at \(message.timestamp)")
    case .failure(let error):
        print("Error receiving message: \(error)")
    }
}
```

### 5. Request-Reply Pattern

```swift
// Send request and wait for reply
relay.request(subject: "service.request", message: "Request data") { result in
    switch result {
    case .success(let reply):
        print("Received reply: \(reply)")
    case .failure(let error):
        print("Request failed: \(error)")
    }
}
```

### 6. Stream Operations

```swift
// Create a stream
relay.createStream(name: "my-stream", subjects: ["test.*"]) { result in
    switch result {
    case .success:
        print("Stream created successfully")
    case .failure(let error):
        print("Failed to create stream: \(error)")
    }
}

// Get message history
relay.getMessageHistory(stream: "my-stream", subject: "test.subject") { result in
    switch result {
    case .success(let messages):
        print("Retrieved \(messages.count) messages")
    case .failure(let error):
        print("Failed to get history: \(error)")
    }
}
```

## 🔧 Advanced Usage

### Error Handling

Relay provides comprehensive error handling through the `RelayError` enum:

```swift
public enum RelayError: Error {
    case connectionFailed(String)
    case publishFailed(String)
    case subscribeFailed(String)
    case requestFailed(String)
    case invalidMessage(String)
    case streamOperationFailed(String)
    case timeout(String)
}
```

### Thread Safety

All operations in Relay are thread-safe:
- Network operations run on background threads
- Callbacks are automatically dispatched to the main thread
- Internal state is protected by proper synchronization

## 📚 Documentation

For more detailed documentation, check out the [API Reference](docs/API.md).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

Relay is available under the MIT license. See the LICENSE file for more info.
