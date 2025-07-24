import Foundation
import Realtime
import UserNotifications
import UIKit
import BackgroundTasks

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
    private var client_Id: String = UUID().uuidString // Unique client ID for each instance
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Keep a strong reference to the listener
    private var messageListener: ChatMessageListener?
    
    private class ChatMessageListener: MessageListener {
        weak var viewModel: ChatViewModel?
        
        init(viewModel: ChatViewModel) {
            self.viewModel = viewModel
        }
        
        func onMessage(_ data: Any) {
            Task { @MainActor in
                // Start background task to ensure we can process the message
                await viewModel?.startBackgroundTask()
                
                var message: Any
                
                switch data {
                case let dict as [String: Any]:
                    message = dict["data"]
                default:
                    message = data
                }
                
                // Handle string message
                let messageText = message
                    let chatMessage = ChatMessage(
                        sender: "Other User",
                        text: messageText as! String,
                        timestamp: Date().description,
                        isFromCurrentUser: false
                    )
                    viewModel?.messages.append(chatMessage)
                    viewModel?.shouldScrollToBottom = true
                    
                    // Schedule a local notification for the message
                await viewModel?.scheduleNotification(for: messageText as! String)
                
                
                // End background task after processing
                await viewModel?.endBackgroundTask()
            }
        }
    }
    
    init() {
        // Request notification permissions
        requestNotificationPermissions()
        
        // Register for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task {
            await endBackgroundTask()
        }
    }
    
    @objc private func appDidEnterBackground() {
        // Start a background task when app enters background
        Task {
            await startBackgroundTask()
        }
        
        // Ensure we're still connected to receive messages
        if isConnected {
            print("App entered background, maintaining connection")
        }
    }
    
    @objc private func appWillEnterForeground() {
        // End background task when app comes to foreground
        Task {
            await endBackgroundTask()
        }
        
        // Refresh connection if needed
        if isConnected {
            Task {
                await refreshConnection()
            }
        }
    }
    
    private func startBackgroundTask() async {
        // End any existing background task
        await endBackgroundTask()
        
        // Start a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor in
                await self?.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() async {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func refreshConnection() async {
        guard let realtime = realtime, isConnected else { return }
        
        do {
            // Check if we need to reconnect
            if !realtime.isConnected {
                try await realtime.connect()
                print("Reconnected to server in foreground")
            }
        } catch {
            print("Error refreshing connection: \(error.localizedDescription)")
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleNotification(for message: String) async {
        // Schedule notification regardless of app state
        let content = UNMutableNotificationContent()
        content.title = "New Message"
        content.body = message
        content.sound = .default
        
        // Create a unique identifier for this notification
        let identifier = UUID().uuidString
        
        // Create a trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add the request to the notification center
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error.localizedDescription)")
        }
    }
    
    func connect(to topic: String, apiKey: String? = nil, secret: String? = nil) async {
        self.topic = topic
        do {
            // Use provided credentials or default ones
            let finalApiKey = apiKey ?? APIKeys.API_KEY
            let finalSecret = secret ?? APIKeys.SECRET
            
            realtime = try Realtime(apiKey: finalApiKey, secret: finalSecret)
            try realtime?.prepare(staging: false, opts: ["debug": true])
            try await realtime?.connect()
            
            // Create and store the listener
            messageListener = ChatMessageListener(viewModel: self)
            try await realtime?.on(topic: topic, listener: messageListener!)
            
            // Configure background message handler
            if let realtime = realtime {
                BackgroundMessageHandler.shared.configure(with: realtime, topic: topic, client_Id: client_Id)
            }
            
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
                // Extract message details based on the new model
                let clientId = messageDict["client_id"] as? String ?? "Unknown"
                let messageId = messageDict["id"] as? String ?? "Unknown"
                let room = messageDict["room"] as? String ?? "Unknown"
                let startTimestamp = messageDict["start"] as? TimeInterval ?? Date().timeIntervalSince1970
                let messageContent = messageDict["message"] as? String ?? "Some Thing"
                
                return ChatMessage(
                    sender: clientId == client_Id ? "iOS User" : "Other User",
                    text: messageContent,
                    timestamp: Date(timeIntervalSince1970: startTimestamp / 1000).description,
                    isFromCurrentUser: clientId == client_Id
                )
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
        
        do {
            // Send the message as a simple string
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
