# RelayX Swift SDK

![License](https://img.shields.io/badge/Apache_2.0-green?label=License)

Swift SDK for building real-time messaging applications with RelayX.

---

## What is RelayX?

RelayX is a real-time messaging platform for building pub/sub applications. It handles message delivery, reconnection, and offline storage automatically so you can focus on your application logic.

---

## Installation

Add the package to your Swift project using Swift Package Manager.

In Xcode: **File > Add Package Dependencies**, then enter:

```
https://github.com/Realtime-Relay/Realtime
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Realtime-Relay/Realtime", from: "1.0.0")
]
```

---

## Quick Start

```swift
import Realtime

// Create client
let realtime = try Realtime(apiKey: "your-api-key", secret: "your-secret")
try realtime.prepare(staging: false)
try await realtime.connect()

// Create listener
class MyListener: MessageListener {
    func onMessage(_ message: Any) {
        if let msg = message as? [String: Any],
           let data = msg["data"] {
            print("Received: \(data)")
        }
    }
}

// Subscribe
let listener = MyListener()
try await realtime.on(topic: "hello", listener: listener)

// Publish
try await realtime.publish(topic: "hello", message: "Hello World")
```

---

## Messaging (Pub/Sub)

**Publish:**

```swift
try await realtime.publish(topic: "chat.room1", message: "Hello")
```

**Subscribe:**

```swift
class ChatListener: MessageListener {
    func onMessage(_ message: Any) {
        if let msg = message as? [String: Any] {
            let data = msg["data"]
            print("Received: \(data ?? "")")
        }
    }
}

let listener = ChatListener()
try await realtime.on(topic: "chat.room1", listener: listener)
```

---

## Documentation

Full documentation is available at:

https://docs.relay-x.io

All guarantees, limits, and behavior are documented there.

---

## License

This SDK is licensed under the Apache 2.0 License.
