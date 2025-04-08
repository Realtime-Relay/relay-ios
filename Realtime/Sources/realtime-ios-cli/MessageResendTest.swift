//import Foundation
//import Realtime
//import SwiftMsgpack
//
//struct MessageResendTest {
//    static func main() async throws {
//        print("\n🧪 Starting Message Resend Test...")
//        
//        // Initialize Realtime instance
//        print("\n📱 Initializing Realtime instance...")
//        let realtime = try Realtime(staging: false, opts: ["debug": true])
//        
//        // Set authentication
//        try realtime.setAuth(
//            apiKey: "eyJ0eXAiOiJK6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
//            secret: "SUABDOOC4JWCVOMSJO4"
//        )
//        
//        // Set up message listeners
//        print("\n🎧 Setting up message listeners...")
//        let regularListener = TestMessageListener(name: "Regular Messages")
//        let resendListener = TestMessageListener(name: "Message Resend")
//        
//        // Store messages while offline
//        print("\n📤 Publishing messages while offline...")
//        let messages = [
//            ["type": "text", "content": "Offline message 1"],
//            ["type": "text", "content": "Offline message 2"],
//            ["type": "text", "content": "Offline message 3"]
//        ]
//        
//        for (index, message) in messages.enumerated() {
//            let encoder = MsgPackEncoder()
//            _ = try encoder.encode(message)
//            let result = try await realtime.publish(topic: "test.resend", message: message)
//            print("✅ Stored offline message \(index + 1): \(result)")
//        }
//        
//        // Connect to trigger message resend
//        print("\n🔄 Connecting to trigger message resend...")
//        try await realtime.connect()
//        try await realtime.on(topic: "test.resend", listener: regularListener)
//        try await realtime.on(topic: SDKTopic.MESSAGE_RESEND, listener: resendListener)
//        
//        // Wait for messages to be processed and resent
//        print("\n⏳ Waiting for messages to be processed and resent (5 seconds)...")
//        try await Task.sleep(nanoseconds: 5_000_000_000)
//        
//        // Print received messages
//        print("\n📨 Regular messages received: \(regularListener.receivedMessages.count)")
//        for (index, message) in regularListener.receivedMessages.enumerated() {
//            print("\nMessage \(index + 1):")
//            print("   Content: \(message)")
//            
//            // Try to decode the message content
//            let decoder = MsgPackDecoder()
//            if let messageContent = message["message"] as? String,
//               let contentData = Data(base64Encoded: messageContent),
//               let decodedData = try? decoder.decode(Data.self, from: contentData),
//               let decodedContent = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
//                print("\n📝 Decoded Message Content:")
//                print("Type: \(decodedContent["type"] ?? "unknown")")
//                print("Content: \(decodedContent["content"] ?? "none")")
//            } else {
//                print("\n❌ Message content is not in expected format")
//                print("Content type: \(type(of: message["message"]))")
//            }
//        }
//        
//        // Print resend statuses
//        print("\n📊 Message resend statuses: \(resendListener.receivedMessages.count)")
//        
//        // Clean up
//        print("\nDisconnecting...")
//        try await realtime.disconnect()
//        print("✅ Message resend test completed")
//    }
//} 
