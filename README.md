# Realtime

A modern, thread-safe Swift package for real-time messaging in iOS and macOS applications. Realtime provides a clean, Swift-native API for real-time communication with support for topics, message history, and automatic reconnection.

## 🚀 Features

- **Thread-Safe Operations**: All operations are automatically handled on appropriate threads
- **Automatic Connection Management**: Handles connection lifecycle and reconnection
- **Main Thread Callbacks**: UI updates are automatically dispatched to the main thread
- **Topic-Based Messaging**: Publish/subscribe with topic validation
- **Message History**: Retrieve message history with date filtering
- **Multiple Message Types**: Support for String, Number, and JSON messages
- **Error Handling**: Comprehensive error handling with Swift's Result type
- **Async/Await Support**: Modern concurrency support with async/await
- **Debug Mode**: Optional debug logging for development

## 📋 Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 14.0+

## 📦 Installation

### Swift Package Manager

Add Realtime to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Realtime-Relay/realtime-ios.git", from: "1.0.0")
]
```

## 🎯 Quick Start

### 1. Initialize Realtime

```swift
import Realtime

// Configure options
let opts: [String: Any] = [
    "apiKey": "your-api-key",
    "secretKey": "your-secret-key",
    "debug": true // Optional, enables debug logging
]

// Create Realtime instance
let realtime = try Realtime(staging: true, opts: opts)
```

### 2. Connect to Server

```swift
// Using async/await
do {
    try await realtime.connect()
    print("Connected to server")
} catch {
    print("Failed to connect: \(error)")
}
```

### 3. Publish Messages

```swift
// Publish string message
try await realtime.publish(topic: "chat.room1", message: "Hello, world!")

// Publish number
try await realtime.publish(topic: "sensor.temperature", message: 25.5)

// Publish JSON object
let message = ["user": "John", "text": "Hello!"]
try await realtime.publish(topic: "chat.room1", message: message)
```

### 4. Subscribe to Messages

```swift
// Subscribe to string messages
try await realtime.on(topic: "chat.room1") { message in
    if let text = message as? String {
        print("Received message: \(text)")
    }
}

// Subscribe to JSON messages
try await realtime.on(topic: "chat.room1") { message in
    if let data = message as? [String: Any],
       let user = data["user"] as? String,
       let text = data["text"] as? String {
        print("\(user): \(text)")
    }
}
```

### 5. Get Message History

```swift
// Get messages from a specific date
let startDate = Date().addingTimeInterval(-3600) // Last hour
let messages = try await realtime.history(
    topic: "chat.room1",
    startDate: startDate
)

// Get messages in a date range
let endDate = Date()
let messages = try await realtime.history(
    topic: "chat.room1",
    startDate: startDate,
    endDate: endDate
)
```

### 6. Unsubscribe and Cleanup

```swift
// Unsubscribe from a topic
try await realtime.off(topic: "chat.room1")

// Close connection
try await realtime.close()
```

## 🔧 Advanced Usage

### Topic Validation

Topics must:
- Be non-empty strings
- Not contain spaces or '*' characters
- Not be system-reserved topics (CONNECTED, RECONNECT, etc.)

### Message Types

Supported message types:
- String
- Number (Int or Double)
- JSON (Dictionary<String, Any>)

### Error Handling

Realtime provides comprehensive error handling through the `RealtimeError` enum:

```swift
public enum RealtimeError: Error {
    case invalidPayload
    case invalidResponse
    case invalidConfiguration(String)
    case invalidTopic(String)
    case invalidMessage(String)
    case invalidDate(String)
    case connectionFailed(String)
    case publishFailed(String)
    case subscribeFailed(String)
    case requestFailed(String)
    case streamOperationFailed(String)
    case timeout(String)
}
```

### Thread Safety

All operations in Realtime are thread-safe:
- Network operations run on background threads
- Callbacks are automatically dispatched to the main thread
- Internal state is protected by proper synchronization

## 📚 Documentation

For more detailed documentation, check out the [API Reference](https://pypi.org/project/relayx-py/).

## 📄 License

Realtime is available under the MIT license. See the LICENSE file for more info.
