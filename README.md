# Relay

A Swift package that provides a simple wrapper around the NATS SDK, handling threading complexity for iOS and macOS applications.

## Features

- Simple API that abstracts away threading complexity
- Automatic connection management
- Thread-safe operations
- Main thread callbacks for UI updates
- JSON encoding/decoding support
- Request-reply pattern support

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add Relay to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/relay-ios.git", from: "1.0.0")
]
```

## Usage

### Initialize Relay

```swift
import Relay

let servers = [
    "nats://api.relay-x.io:4221",
    "nats://api.relay-x.io:4222",
    "nats://api.relay-x.io:4223",
    "nats://api.relay-x.io:4224",
    "nats://api.relay-x.io:4225",
    "nats://api.relay-x.io:4226"
]

let relay = Relay(
    servers: servers,
    apiKey: "your-api-key",
    secret: "your-secret"
)
```

### Connect to Server

```swift
relay.connect { result in
    switch result {
    case .success:
        print("Connected to NATS server")
    case .failure(let error):
        print("Failed to connect: \(error)")
    }
}
```

### Publish Messages

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

### Subscribe to Messages

```swift
let subscription = relay.subscribe(subject: "test.subject") { message in
    // This handler is automatically called on the main thread
    if let data = message.payload,
       let string = String(data: data, encoding: .utf8) {
        print("Received message: \(string)")
    }
}

// Later, unsubscribe when done
subscription.unsubscribe()
```

### Request-Reply Pattern

```swift
relay.request(
    subject: "test.request",
    payload: Data("Hello".utf8),
    timeout: .seconds(5)
) { result in
    switch result {
    case .success(let response):
        if let data = response.payload,
           let string = String(data: data, encoding: .utf8) {
            print("Received response: \(string)")
        }
    case .failure(let error):
        print("Request failed: \(error)")
    }
}
```

### Disconnect

```swift
relay.disconnect { result in
    switch result {
    case .success:
        print("Disconnected from NATS server")
    case .failure(let error):
        print("Failed to disconnect: \(error)")
    }
}
```

## Threading

The Relay package handles all threading complexity for you:

- All network operations are performed on a dedicated background queue
- Subscription handlers are automatically dispatched to the main thread for UI updates
- Connection state is managed thread-safely
- All public methods are thread-safe and can be called from any thread

## License

Relay is available under the MIT license. See the LICENSE file for more info.
