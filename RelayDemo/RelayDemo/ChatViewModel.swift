import Foundation
import Realtime

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentMessage: String = ""
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    @Published var isLoadingHistory: Bool = false
    @Published var shouldScrollToBottom: Bool = false
    
    private var realtime: Realtime?
    private var topic: String = ""
    private var messageTask: Task<Void, Never>?
    private var clientId: String = UUID().uuidString // Unique client ID for each instance
    
    // Keep a strong reference to the listener
    private var messageListener: ChatMessageListener?
    
    private class ChatMessageListener: MessageListener {
        weak var viewModel: ChatViewModel?
        
        init(viewModel: ChatViewModel) {
            self.viewModel = viewModel
        }
        
        func onMessage(_ message: Any) {
            Task { @MainActor in
                // Handle different message types
                if let messageText = message as? String {
                    // Simple text message
                    let chatMessage = ChatMessage(
                        sender: "Other User",
                        text: messageText,
                        timestamp: Date().description,
                        isFromCurrentUser: false
                    )
                    viewModel?.messages.append(chatMessage)
                    viewModel?.shouldScrollToBottom = true
                } else if let messageDict = message as? [String: Any] {
                    // Handle dictionary format for backward compatibility
                    let senderId = messageDict["sender_id"] as? String ?? "Unknown"
                    let chatMessage = ChatMessage(
                        sender: messageDict["sender"] as? String ?? "Unknown",
                        text: messageDict["text"] as? String ?? "",
                        timestamp: messageDict["timestamp"] as? String ?? Date().description,
                        isFromCurrentUser: senderId == viewModel?.clientId
                    )
                    viewModel?.messages.append(chatMessage)
                    viewModel?.shouldScrollToBottom = true
                }
            }
        }
    }
    
    func connect(to topic: String, apiKey: String? = nil, secret: String? = nil) async {
        self.topic = topic
        do {
            // Use provided credentials or default ones
            let finalApiKey = apiKey ?? "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVQU9STjRWQkNXQzJORU1FVkpFWUY3VERIUVdYTUNLTExTWExNTjZRTjRBVU1WUElDSVJOSEpJRyIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDUwNTE2NjcsImp0aSI6IllVMG50TXFNcHhwWFNWbUp0OUJDazhhV0dxd0NwYytVQ0xwa05lWVBVcDNNRTNQWDBRcUJ2ZjBBbVJXMVRDamEvdTg2emIrYUVzSHVKUFNmOFB2SXJnPT0ifQ._LtZJnTADAnz3N6U76OaA-HCYq-XxckChk1WlHi_oZXfYP2vqcGIiNDFSQ-XpfjUTfKtXEuzcf_BDq54nSEMAA"
            let finalSecret = secret ?? "SUAPWRWRITWYL4YP7B5ZHU3W2G2ZPYJ47IN4UWNHLMFTSIJEOMQJWWSWGY"
            
            realtime = try Realtime(apiKey: finalApiKey, secret: finalSecret)
            try realtime?.prepare(staging: false, opts: ["debug": true])
            try await realtime?.connect()
            
            // Create and store the listener
            messageListener = ChatMessageListener(viewModel: self)
            try await realtime?.on(topic: topic, listener: messageListener!)
            
            // Load message history
            await loadHistory()
            
            isConnected = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isConnected = false
        }
    }
    
    func loadHistory() async {
        guard let realtime = realtime else { return }
        
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        
        do {
            // Get messages from the last 24 hours
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            
            let historyMessages = try await realtime.history(
                topic: topic,
                start: startDate,
                end: endDate
            )
            
            // Convert history messages to ChatMessage format
            let chatMessages = historyMessages.map { messageDict -> ChatMessage in
                // Handle different message formats
                if let messageContent = messageDict["message"] as? String {
                    // Simple text message
                    return ChatMessage(
                        sender: "Other User",
                        text: messageContent,
                        timestamp: Date().description,
                        isFromCurrentUser: false
                    )
                } else if let messageContent = messageDict["message"] as? [String: Any] {
                    // Dictionary format
                    let senderId = messageContent["sender_id"] as? String ?? "Unknown"
                    return ChatMessage(
                        sender: messageContent["sender"] as? String ?? "Unknown",
                        text: messageContent["text"] as? String ?? "",
                        timestamp: messageContent["timestamp"] as? String ?? Date().description,
                        isFromCurrentUser: senderId == clientId
                    )
                } else {
                    // Fallback
                    return ChatMessage(
                        sender: "Unknown",
                        text: "Unknown message format",
                        timestamp: Date().description,
                        isFromCurrentUser: false
                    )
                }
            }
            
            // Add messages to the array
            messages = chatMessages
            shouldScrollToBottom = true
        } catch {
            errorMessage = "Failed to load history: \(error.localizedDescription)"
        }
    }
    
    func sendMessage() async {
        guard !currentMessage.isEmpty, isConnected else { return }
        
        // Publish only the message text
        do {
            let success = try await realtime?.publish(topic: topic, message: currentMessage)
            if success == true {
                // Add the message to local messages array since SDK will ignore it
                let chatMessage = ChatMessage(
                    sender: "iOS User",
                    text: currentMessage,
                    timestamp: Date().description,
                    isFromCurrentUser: true
                )
                messages.append(chatMessage)
                currentMessage = ""
                shouldScrollToBottom = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func disconnect() async {
        messageTask?.cancel()
        messageTask = nil
        messageListener = nil // Clear the listener reference
        
        do {
            try await realtime?.close()
            isConnected = false
            messages.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
