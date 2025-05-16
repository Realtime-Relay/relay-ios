# Relay iOS Library

A modern, thread-safe Swift package for real-time messaging in iOS and macOS applications. Built on top of NATS and JetStream, this SDK provides a clean, Swift-native API for real-time communication with support for offline messaging, message history, and more.

## 🚀 Features

1. Real-time communication made easy—connect, publish, and subscribe with minimal effort.
2. Automatic reconnection built-in, with a 2-minute retry window for network disruptions.
3. Message persistence during reconnection ensures no data loss when the client reconnects.

## 📋 Requirements

- iOS 15.0+ / macOS 13.0+

## 📦 Installation

### Swift Package Manager

Add Relay to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Realtime-Relay/relay-ios.git", from: "1.0.0")
]
```

## 📚 Usage

### Prerequisites
1. Obtain API key and Secret key
2. Initialize the library
    ```swift
    import Realtime

    // Initialize with API key and secret
    let realtime = try Realtime(apiKey: "your-api-key", secret: "your-secret")

    // Configure for staging or production
    try realtime.prepare(staging: false, opts: ["debug": true])
    
    // Connect to server
    do {
        try await realtime.connect()
        print("Connected to Relay server")
    } catch {
        print("Failed to connect: \(error)")
    }
    ```

### Usage
1. **Publish**<br>
Send a message to a topic:<br>
    ```swift
    // Simple text message
    try await realtime.publish(topic: "chat_room1", message: "Hello, world!")

    // Multi-line text
    try await realtime.publish(
        topic: "notifications", 
        message: """
        System Update:
        - New features added
        - Bug fixes implemented
        - Performance improvements
        """
    )
    
    // Numeric messages
    try await realtime.publish(topic: "sensors_temperature", message: 23.5)
    
    // Dictionary messages
    try await realtime.publish(
        topic: "user_status", 
        message: [
            "userId": "123",
            "status": "online",
            "lastSeen": Date().timeIntervalSince1970
        ]
    )
    ```

2. **Listen**<br>
Subscribe to a topic to receive messages:<br>
    ```swift
    // Create a message listener
    class MyMessageListener: MessageListener {
        func onMessage(_ message: Any) {
            print("Received message: \(message)")
        }
    }

    // Subscribe to a topic
    let listener = MyMessageListener()
    try await realtime.on(topic: "test_topic", listener: listener)
    ```

3. **Turn Off Listener**<br>
Unsubscribe from a topic:<br>
    ```swift
    // Unsubscribe from a topic
    try await realtime.off(topic: "test_topic")
    ```

4. **History**<br>
Get previously published messages between a start date and end date:
    ```swift
    // Get messages from the last 5 minutes
    let startDate = Date().addingTimeInterval(-5 * 60)
    let history = try await realtime.history(
        topic: "test_topic",
        start: startDate
    )

    // Get messages with end date and limit
    let endDate = Date()
    let history = try await realtime.history(
        topic: "test_topic",
        start: startDate,
        end: endDate,
        limit: 100
    )
    ```

5. **Cleanup**<br>
Close the connection when done:<br>
    ```swift
    // Close connection
    try await realtime.close()
    ```

## 📚 API Documentation

### Models

#### SystemEvent
The `SystemEvent` enum represents various system-level events that can occur during the SDK's lifecycle. These events are crucial for implementing robust real-time applications.

```swift
public enum SystemEvent: String, CaseIterable {
    case connected = "CONNECTED"          // Initial connection established
    case disconnected = "DISCONNECTED"    // Connection lost
    case reconnecting = "RECONNECTING"    // Attempting to reconnect
    case reconnected = "RECONNECT"        // Successfully reconnected
    case messageResend = "MESSAGE_RESEND" // Offline messages being resent
}
```

**Use Cases:**
1. **Connection State Management**
   ```swift
   class ConnectionManager: MessageListener {
       func onMessage(_ message: Any) {
           if let event = message as? String {
               switch event {
               case SystemEvent.connected.rawValue:
                   updateUI(connected: true)
               case SystemEvent.disconnected.rawValue:
                   updateUI(connected: false)
               default:
                   break
               }
           }
       }
   }

   // Subscribe to system events
   let connectionManager = ConnectionManager()
   try await realtime.on(topic: SystemEvent.connected.rawValue, listener: connectionManager)
   try await realtime.on(topic: SystemEvent.disconnected.rawValue, listener: connectionManager)
   ```

2. **Offline Message Handling**
   ```swift
   class OfflineManager: MessageListener {
       func onMessage(_ message: Any) {
           if let event = message as? String {
               switch event {
               case SystemEvent.reconnecting.rawValue:
                   showLoadingIndicator()
               case SystemEvent.reconnected.rawValue:
                   hideLoadingIndicator()
               case SystemEvent.messageResend.rawValue:
                   showMessage("Syncing offline messages...")
               default:
                   break
               }
           }
       }
   }

   // Subscribe to reconnection events
   let offlineManager = OfflineManager()
   try await realtime.on(topic: SystemEvent.reconnecting.rawValue, listener: offlineManager)
   try await realtime.on(topic: SystemEvent.reconnected.rawValue, listener: offlineManager)
   try await realtime.on(topic: SystemEvent.messageResend.rawValue, listener: offlineManager)
   ```

### Protocols

#### MessageListener
The `MessageListener` protocol defines the interface for handling incoming messages. It's designed to be class-bound to support weak references and prevent memory leaks.

```swift
public protocol MessageListener: AnyObject {
    func onMessage(_ message: Any)
}
```

**Use Cases:**
1. **Real-time Updates**
   ```swift
   class DashboardView: UIView, MessageListener {
       func onMessage(_ message: Any) {
           if let metrics = message as? [String: Double] {
               updateMetrics(metrics)
           }
       }
   }
   ```

### Supported Message Types

The SDK supports the following message types:
- String (including multi-line text)
- Numbers (Int, Double, Float)
- Arrays of numbers
- Dictionary/JSON objects (including nested dictionaries)

Note: All messages are automatically encoded using MessagePack before transmission for efficient and secure communication.

### Errors

The SDK provides comprehensive error handling through the `RelayError` enum:

```swift
public enum RelayError: LocalizedError {
    case invalidCredentials(String)      // Authentication errors
    case invalidResponse                 // Server response errors
    case invalidOptions(String)          // Configuration errors
    case invalidPayload(String)          // Message format errors
    case notConnected(String)            // Connection state errors
    case invalidDate(String)             // Date format errors
    case invalidNamespace(String)        // Namespace errors
    case subscriptionFailed(String)      // Subscription errors
    case invalidListener(String)         // Listener configuration errors
    case invalidTopic(String)            // Topic format errors
}
```

**Use Cases:**
1. **Authentication Error Handling**
   ```swift
   do {
       try await realtime.connect()
   } catch RelayError.invalidCredentials(let message) {
       showLoginScreen()
       logError("Authentication failed: \(message)")
   }
   ```

2. **Connection Error Recovery**
   ```swift
   do {
       try await realtime.publish(topic: "updates", message: data)
   } catch RelayError.notConnected(let message) {
       attemptReconnection()
       storeMessageForLater(data)
   }
   ```

3. **Message Validation**
   ```swift
   do {
       try await realtime.publish(topic: "chat", message: message)
   } catch RelayError.invalidPayload(let message) {
       showError("Invalid message format: \(message)")
   } catch RelayError.invalidTopic(let message) {
       showError("Invalid topic: \(message)")
   }
   ```

### Public Methods

#### Initialization
```swift
// Initialize with API key and secret
let realtime = try Realtime(apiKey: String, secret: String)

// Configure for staging or production
try realtime.prepare(staging: Bool, opts: [String: Any])
```

#### Connection Management
```swift
// Connect to server
func connect() async throws

// Close connection
func close() async throws

// Check connection status
var isConnected: Bool { get }
```

#### Message Publishing
```swift
// Publish message to topic
func publish(topic: String, message: Any) async throws

// Publish message with options
func publish(topic: String, message: Any, options: [String: Any]) async throws
```

#### Message Subscription
```swift
// Subscribe to topic
func on(topic: String, listener: MessageListener) async throws

// Unsubscribe from topic
func off(topic: String) async throws

// Subscribe to system events
func onSystemEvent(_ event: SystemEvent, handler: @escaping () -> Void)
```

#### Message History
```swift
// Get message history
func history(topic: String, startDate: Date) async throws -> [RealtimeMessage]
```

## 🔧 Advanced Usage

### Offline Message Handling

Messages are automatically stored when offline and resent when reconnected:

```swift
// Publish while offline
try await realtime.publish(topic: "test_topic", message: "Offline message")

// Messages will be automatically resent when connection is restored
```

### Error Handling

```swift
do {
    try await realtime.publish(topic: "test.topic", message: "Hello")
} catch RelayError.notConnected(let message) {
    print("Connection error: \(message)")
} catch RelayError.invalidPayload(let message) {
    print("Invalid message: \(message)")
} catch RelayError.invalidTopic(let message) {
    print("Invalid topic format: \(message)")
} catch RelayError.invalidCredentials(let message) {
    print("Authentication error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Debug Mode

Enable debug mode for detailed logging:

```swift
try realtime.prepare(staging: false, opts: ["debug": true])
```

## 📚 Best Practices

1. **Connection Management**
   - Always check connection status before publishing
   - Handle reconnection events appropriately
   - Clean up subscriptions when no longer needed

2. **Message Types**
   - Use strings for simple messages
   - Use dictionaries for structured data
   - Use custom objects for type-safe messages

3. **Error Handling**
   - Implement proper error handling for all operations
   - Use debug mode during development
   - Log errors appropriately in production

4. **Memory Management**
   - Unsubscribe from topics when no longer needed
   - Remove message listeners when done
   - Handle connection cleanup in deinit

5. **Security**
   - Store API keys and secrets securely
   - Use staging environment for development
   - Implement proper error handling for authentication
