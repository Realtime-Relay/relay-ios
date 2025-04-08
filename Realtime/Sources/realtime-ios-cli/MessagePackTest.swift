//import Foundation
//import Realtime
//import SwiftMsgpack
//
//// Define message structures
//struct PackedMessage: Codable {
//    let room: String
//    let message: String
//    let timestamp: Date
//    
//    enum CodingKeys: String, CodingKey {
//        case room
//        case message
//        case timestamp
//    }
//}
//
//struct PackedContent: Codable {
//    let type: String
//    let content: String
//    let timestamp: Date
//    
//    enum CodingKeys: String, CodingKey {
//        case type
//        case content
//        case timestamp
//    }
//}
//
//struct MessagePackTest {
//    static func main() async throws {
//        print("\n=== Testing MessagePack Encoding/Decoding ===")
//        
//        // Test basic MessagePack encoding/decoding
//        let encoder = MsgPackEncoder()
//        let decoder = MsgPackDecoder()
//        
//        // Test string encoding/decoding
//        let testString = "Hello, MessagePack!"
//        let encodedString = try encoder.encode(testString)
//        let decodedString = try decoder.decode(String.self, from: encodedString)
//        
//        print("\nString test:")
//        print("Original: \(testString)")
//        print("Encoded: \(encodedString)")
//        print("Decoded: \(decodedString)")
//        
//        // Test struct encoding/decoding
//        let testMessage = PackedMessage(
//            room: "test.room",
//            message: "Test message",
//            timestamp: Date()
//        )
//        let encodedMessage = try encoder.encode(testMessage)
//        let decodedMessage = try decoder.decode(PackedMessage.self, from: encodedMessage)
//        
//        print("\nStruct test:")
//        print("Original: \(testMessage)")
//        print("Encoded: \(encodedMessage)")
//        print("Decoded: \(decodedMessage)")
//        
//        // Test with Realtime
//        print("\nTesting with Realtime...")
//        let realtime = try Realtime(staging: false, opts: ["debug": true])
//        
//        // Set authentication
//        try realtime.setAuth(
//            apiKey: "eyJ0eXAiOiJKV1QiLCJhhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
//            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGMSJO4"
//        )
//        
//        // Set up message listener
//        print("\nSetting up message listener...")
//        let listener = TestMessageListener(name: "MessagePack Test")
//        try await realtime.on(topic: "test.messagepack", listener: listener)
//        print("✅ Message listener set up")
//        
//        // Connect to Realtime
//        print("\nConnecting to Realtime...")
//        try await realtime.connect()
//        print("✅ Connected to Realtime")
//        
//        // Create and encode message content
//        let messageContent = PackedContent(
//            type: "text",
//            content: "MessagePack test message",
//            timestamp: Date()
//        )
//        
//        // Encode the message content and convert to base64
//        let encodedContent = try encoder.encode(messageContent)
//        let base64Content = encodedContent.base64EncodedString()
//        print("\n📤 Encoded message content (base64): \(base64Content)")
//        
//        // Publish the message
//        print("\nPublishing test message...")
//        let message: [String: Any] = [
//            "type": "text",
//            "content": base64Content,
//            "timestamp": Date().timeIntervalSince1970
//        ]
//        
//        print("\n📤 Message to be published:")
//        print("Topic: test.messagepack")
//        print("Content: \(message)")
//        
//        let publishResult = try await realtime.publish(topic: "test.messagepack", message: message)
//        print("✅ Message published: \(publishResult)")
//        
//        // Wait for message to be received
//        print("\nWaiting for message...")
//        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
//        
//        // Verify message was received
//        if listener.receivedMessages.isEmpty {
//            print("❌ No messages received")
//        } else {
//            let receivedMessage = listener.receivedMessages[0]
//            print("\n📨 Received Message Details:")
//            print("Client ID: \(receivedMessage["client_id"] ?? "N/A")")
//            print("Message ID: \(receivedMessage["id"] ?? "N/A")")
//            print("Timestamp: \(receivedMessage["timestamp"] ?? "N/A")")
//            
//            // Debug the message structure
//            print("\n🔍 Message Structure:")
//            for (key, value) in receivedMessage {
//                print("\(key): \(value)")
//            }
//            
//            // Try to decode the message content
//            if let messageContent = receivedMessage["message"] as? [String: Any],
//               let base64Content = messageContent["content"] as? String,
//               let contentData = Data(base64Encoded: base64Content),
//               let decodedContent = try? decoder.decode(PackedContent.self, from: contentData) {
//                print("\n📝 Decoded Message Content:")
//                print("Type: \(decodedContent.type)")
//                print("Content: \(decodedContent.content)")
//                print("Timestamp: \(decodedContent.timestamp)")
//            } else {
//                print("\n❌ Message content is not in expected format")
//                print("Content type: \(type(of: receivedMessage["message"]))")
//            }
//        }
//        
//        // Clean up
//        print("\nDisconnecting from Realtime...")
//        try await realtime.disconnect()
//        print("\n✅ MessagePack test completed")
//    }
//} 
