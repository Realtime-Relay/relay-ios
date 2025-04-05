# Realtime iOS SDK

A modern, thread-safe Swift package for real-time messaging in iOS and macOS applications. Built on top of NATS, this SDK provides a clean, Swift-native API for real-time communication with support for offline messaging, message history, and more.

## 🚀 Features

- **Real-time Messaging**: Pub/Sub pattern with MessagePack encoding
- **Offline Support**: Automatic message storage and resend
- **Message History**: Retrieve past messages with time-based queries
- **Thread Safety**: All operations are automatically handled on appropriate threads
- **Automatic Connection Management**: Handles connection lifecycle and reconnection
- **Main Thread Callbacks**: UI updates are automatically dispatched to the main thread
- **Multiple Message Types**: Support for strings, JSON, and custom objects
- **Error Handling**: Comprehensive error handling with Swift's Result type
- **Async/Await Support**: Modern concurrency support with async/await

## 📋 Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 14.0+

## 📦 Installation

### Swift Package Manager

Add Realtime to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/realtime-ios.git", from: "1.0.0")
]
```

## 🎯 Quick Start

### 1. Initialize Realtime

```swift
import Realtime

// Initialize with debug mode enabled
let realtime = try Realtime(staging: false, opts: ["debug": true])

// Set authentication
try realtime.setAuth(
    apiKey: "your-api-key",
    secret: "your-secret"
)
```

### 2. Connect to Server

```swift
// Using async/await
do {
    try await realtime.connect()
    print("Connected to Realtime server")
} catch {
    print("Failed to connect: \(error)")
}
```

### 3. Publishing Messages

The SDK supports multiple message types:

```swift
// 1. String Message
try await realtime.publish(topic: "test.topic", message: "Hello World!")

// 2. Dictionary Message
let dictMessage = [
    "type": "text",
    "content": "Hello from dictionary!",
    "timestamp": Date().timeIntervalSince1970
]
try await realtime.publish(topic: "test.topic", message: dictMessage)

// 3. Custom Object
struct MyMessage: Codable {
    let content: String
    let timestamp: Date
}
let customMessage = MyMessage(content: "Hello from custom object!", timestamp: Date())
try await realtime.publish(topic: "test.topic", message: customMessage)
```

### 4. Subscribing to Messages

```swift
// Create a message listener
class MyMessageListener: MessageListener {
    func onMessage(_ message: [String: Any]) {
        print("Received message: \(message)")
    }
}

// Subscribe to a topic
let listener = MyMessageListener()
try await realtime.on(topic: "test.topic", listener: listener)
```

### 5. Retrieving Message History

```swift
// Get messages from the last 5 minutes
let startDate = Date().addingTimeInterval(-5 * 60)
let history = try await realtime.history(topic: "test.topic", startDate: startDate)
print("Message history: \(history)")
```

### 6. Unsubscribing from Topics

```swift
// Unsubscribe from a topic
let unsubscribed = try await realtime.off(topic: "test.topic")
if unsubscribed {
    print("Successfully unsubscribed")
}
```

## 🔧 Advanced Usage

### Offline Message Handling

Messages are automatically stored when offline and resent when reconnected:

```swift
// Publish while offline
try await realtime.publish(topic: "test.topic", message: "Offline message")

// Messages will be automatically resent when connection is restored
```

### Error Handling

The SDK provides comprehensive error handling:

```swift
do {
    try await realtime.publish(topic: "test.topic", message: "Hello")
} catch RelayError.notConnected(let message) {
    print("Connection error: \(message)")
} catch RelayError.invalidPayload(let message) {
    print("Invalid message: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Debug Mode

Enable debug mode for detailed logging:

```swift
let realtime = try Realtime(staging: false, opts: ["debug": true])
```

## 📚 Best Practices

1. **Message Types**
   - Use strings for simple messages
   - Use dictionaries for structured data
   - Use custom objects for type-safe messages

2. **Connection Management**
   - Always check connection status before publishing
   - Handle reconnection events appropriately
   - Clean up subscriptions when no longer needed

3. **Error Handling**
   - Implement proper error handling for all operations
   - Use debug mode during development
   - Log errors appropriately in production

4. **Memory Management**
   - Unsubscribe from topics when no longer needed
   - Remove message listeners when done
   - Handle connection cleanup in deinit

## 📄 License

Realtime iOS SDK is available under the MIT license. See the LICENSE file for more info.
