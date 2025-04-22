import Foundation

struct ConfigManager {
    private static let configFile: URL = {
        // Get home directory in a cross-platform way
        let homeDir: String
        #if os(iOS)
        homeDir = NSHomeDirectory()
        #else
        homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        #endif
        return URL(fileURLWithPath: homeDir).appendingPathComponent(".realtime-cli-config.json")
    }()
    
    struct Config: Codable {
        var apiKey: String?
        var secret: String?
        var defaultTopic: String?
        var isStaging: Bool = false
        var isDebug: Bool = false
    }
    
    static func loadConfig() -> Config {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return Config()
        }
        return config
    }
    
    static func saveConfig(_ config: Config) throws {
        let data = try JSONEncoder().encode(config)
        try data.write(to: configFile)
    }
    
    static func updateConfig(apiKey: String? = nil, secret: String? = nil, 
                           defaultTopic: String? = nil, isStaging: Bool? = nil,
                           isDebug: Bool? = nil) throws {
        var config = loadConfig()
        
        if let apiKey = apiKey { config.apiKey = apiKey }
        if let secret = secret { config.secret = secret }
        if let defaultTopic = defaultTopic { config.defaultTopic = defaultTopic }
        if let isStaging = isStaging { config.isStaging = isStaging }
        if let isDebug = isDebug { config.isDebug = isDebug }
        
        try saveConfig(config)
    }
    
    static func printCurrentConfig() {
        let config = loadConfig()
        print("\n📋 Current Configuration:")
        print("API Key: \(config.apiKey ?? "Not set")")
        print("Secret: \(config.secret != nil ? "Set" : "Not set")")
        print("Default Topic: \(config.defaultTopic ?? "Not set")")
        print("Staging Mode: \(config.isStaging ? "Enabled" : "Disabled")")
        print("Debug Mode: \(config.isDebug ? "Enabled" : "Disabled")")
    }
} 
