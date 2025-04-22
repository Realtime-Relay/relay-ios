import Foundation
import ArgumentParser
import Realtime

@main
struct RealtimeCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "realtime-cli",
        abstract: "A CLI tool for testing the Realtime SDK",
        subcommands: [
            Connect.self,
            Publish.self,
            Subscribe.self,
            History.self,
            Config.self,
            SetConfig.self
        ]
    )
    
    func run() async throws {
        // Main command just shows help
        RealtimeCLI.exit(withError: CleanExit.helpRequest())
    }
}

struct Config: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Show current configuration"
    )
    
    func run() throws {
        ConfigManager.printCurrentConfig()
    }
}

struct SetConfig: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set configuration values"
    )
    
    @Option(name: .shortAndLong, help: "API Key for authentication")
    var apiKey: String?
    
    @Option(name: .shortAndLong, help: "Secret for authentication")
    var secret: String?
    
    @Option(name: .shortAndLong, help: "Default topic to use")
    var topic: String?
    
    @Flag(name: .long, help: "Use staging environment")
    var staging: Bool = false
    
    @Flag(name: .long, help: "Enable debug mode")
    var debug: Bool = false
    
    func run() throws {
        try ConfigManager.updateConfig(
            apiKey: apiKey,
            secret: secret,
            defaultTopic: topic,
            isStaging: staging,
            isDebug: debug
        )
        ConfigManager.printCurrentConfig()
    }
}

struct Connect: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "connect",
        abstract: "Connect to the Realtime service"
    )
    
    @Option(name: .shortAndLong, help: "API Key for authentication")
    var apiKey: String?
    
    @Option(name: .shortAndLong, help: "Secret for authentication")
    var secret: String?
    
    @Flag(name: .long, help: "Use staging environment")
    var staging: Bool = false
    
    @Flag(name: .long, help: "Enable debug mode")
    var debug: Bool = false
    
    func run() async throws {
        let config = ConfigManager.loadConfig()
        
        let finalApiKey = apiKey ?? config.apiKey
        let finalSecret = secret ?? config.secret
        let finalStaging = staging || config.isStaging
        let finalDebug = debug || config.isDebug
        
        guard let finalApiKey = finalApiKey, let finalSecret = finalSecret else {
            print("❌ API Key and Secret must be set. Use 'realtime set' to configure them.")
            return
        }
        
        print("🔌 Connecting to Realtime service...")
        
        let realtime = try Realtime(apiKey: finalApiKey, secret: finalSecret)
        try await realtime.prepare(staging: finalStaging, opts: ["debug": finalDebug])
        try await realtime.connect()
        
        print("✅ Connected successfully!")
        
        // Keep the connection alive
        while true {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
}

struct Publish: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "publish",
        abstract: "Publish a message to a topic"
    )
    
    @Option(name: .shortAndLong, help: "API Key for authentication (optional if set in config)")
    var apiKey: String?
    
    @Option(name: .shortAndLong, help: "Secret for authentication (optional if set in config)")
    var secret: String?
    
    @Option(name: .shortAndLong, help: "Topic to publish to (optional if default topic is set in config)")
    var topic: String?
    
    @Option(name: .shortAndLong, help: "Message to publish")
    var message: String
    
    @Flag(name: .long, help: "Use staging environment")
    var staging: Bool = false
    
    @Flag(name: .long, help: "Enable debug mode")
    var debug: Bool = false
    
    mutating func run() async throws {
        let config = ConfigManager.loadConfig()
        
        let finalApiKey = apiKey ?? config.apiKey
        let finalSecret = secret ?? config.secret
        let finalTopic = topic ?? config.defaultTopic
        let finalStaging = staging || config.isStaging
        let finalDebug = debug || config.isDebug
        
        guard let finalApiKey = finalApiKey, let finalSecret = finalSecret else {
            print("❌ API Key and Secret must be set. Use 'realtime-cli set --api-key YOUR_KEY --secret YOUR_SECRET' to configure them.")
            return
        }
        
        guard let finalTopic = finalTopic else {
            print("❌ Topic must be set. Either:")
            print("   1. Set a default topic: realtime-cli set --topic YOUR_TOPIC")
            print("   2. Specify topic in command: realtime-cli publish --topic YOUR_TOPIC -m \"Your message\"")
            return
        }
        
        print("📤 Publishing message to topic: \(finalTopic)")
        
        let realtime = try Realtime(apiKey: finalApiKey, secret: finalSecret)
        try await realtime.prepare(staging: finalStaging, opts: ["debug": finalDebug])
        try await realtime.connect()
        
        let success = try await realtime.publish(topic: finalTopic, message: message)
        
        if success {
            print("✅ Message published successfully!")
        } else {
            print("❌ Failed to publish message")
        }
        
        try await realtime.close()
    }
}

struct Subscribe: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "subscribe",
        abstract: "Subscribe to a topic"
    )
    
    @Option(name: .shortAndLong, help: "API Key for authentication")
    var apiKey: String?
    
    @Option(name: .shortAndLong, help: "Secret for authentication")
    var secret: String?
    
    @Option(name: .shortAndLong, help: "Topic to subscribe to")
    var topic: String?
    
    @Flag(name: .long, help: "Use staging environment")
    var staging: Bool = false
    
    @Flag(name: .long, help: "Enable debug mode")
    var debug: Bool = false
    
    func run() async throws {
        let config = ConfigManager.loadConfig()
        
        let finalApiKey = apiKey ?? config.apiKey
        let finalSecret = secret ?? config.secret
        let finalTopic = topic ?? config.defaultTopic
        let finalStaging = staging || config.isStaging
        let finalDebug = debug || config.isDebug
        
        guard let finalApiKey = finalApiKey, let finalSecret = finalSecret else {
            print("❌ API Key and Secret must be set. Use 'realtime set' to configure them.")
            return
        }
        
        guard let finalTopic = finalTopic else {
            print("❌ Topic must be set. Use 'realtime set --topic' or provide it with --topic.")
            return
        }
        
        print("📥 Subscribing to topic: \(finalTopic)")
        
        let realtime = try Realtime(apiKey: finalApiKey, secret: finalSecret)
        try await realtime.prepare(staging: finalStaging, opts: ["debug": finalDebug])
        try await realtime.connect()
        
        class MyMessageListener: MessageListener {
            func onMessage(_ message: Any) {
                print("📨 Received message: \(message)")
            }
        }
        
        let listener = MyMessageListener()
        try await realtime.on(topic: finalTopic, listener: listener)
        
        print("✅ Subscribed successfully! Waiting for messages...")
        
        // Keep the subscription alive
        while true {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
}

struct History: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Get message history for a topic"
    )
    
    @Option(name: .shortAndLong, help: "API Key for authentication")
    var apiKey: String?
    
    @Option(name: .shortAndLong, help: "Secret for authentication")
    var secret: String?
    
    @Option(name: [.customShort("c"), .long], help: "Topic to get history for")
    var topic: String?
    
    @Option(name: [.customShort("f"), .long], help: "Start date (ISO8601 format)")
    var startDate: String
    
    @Option(name: [.customShort("t"), .long], help: "End date (ISO8601 format)")
    var endDate: String?
    
    @Option(name: [.customShort("l"), .long], help: "Maximum number of messages to fetch")
    var limit: Int?
    
    @Flag(name: .long, help: "Use staging environment")
    var staging: Bool = false
    
    func run() async throws {
        let config = ConfigManager.loadConfig()
        
        let finalApiKey = apiKey ?? config.apiKey
        let finalSecret = secret ?? config.secret
        let finalTopic = topic ?? config.defaultTopic
        let finalStaging = staging || config.isStaging
        
        guard let finalApiKey = finalApiKey, let finalSecret = finalSecret else {
            print("❌ API Key and Secret must be set. Use 'realtime set' to configure them.")
            return
        }
        
        guard let finalTopic = finalTopic else {
            print("❌ Topic must be set. Use 'realtime set --topic' or provide it with --topic.")
            return
        }
        
        print("📜 Getting message history for topic: \(finalTopic)")
        
        let realtime = try Realtime(apiKey: finalApiKey, secret: finalSecret)
        try await realtime.prepare(staging: finalStaging, opts: [:])
        try await realtime.connect()
        
        let dateFormatter = ISO8601DateFormatter()
        let start = dateFormatter.date(from: startDate)!
        let end = endDate.flatMap { dateFormatter.date(from: $0) }
        
        let messages = try await realtime.history(
            topic: finalTopic,
            start: start,
            end: end,
            limit: limit
        )
        
        print("\n📦 Message History:")
        for message in messages {
            print("• \(message)")
        }
        
        try await realtime.close()
    }
} 