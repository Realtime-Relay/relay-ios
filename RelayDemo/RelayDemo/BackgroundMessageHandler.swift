//
//  BackgroundMessageHandler.swift
//  RelayDemo
//
//  Created by Shaxzod on 19/04/25.
//

import Foundation
import UIKit
import UserNotifications
import Realtime

class BackgroundMessageHandler {
    static let shared = BackgroundMessageHandler()
    
    private var realtime: Realtime?
    private var topic: String = ""
    private var client_Id: String = ""
    private var messageListener: BackgroundMessageListener?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
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
    
    func configure(with realtime: Realtime, topic: String, client_Id: String) {
        self.realtime = realtime
        self.topic = topic
        self.client_Id = client_Id
        
        // Create and store the listener
        messageListener = BackgroundMessageListener(handler: self)
        
        // Subscribe to the topic
        Task {
            do {
                try await realtime.on(topic: topic, listener: messageListener!)
                print("Background message handler subscribed to topic: \(topic)")
            } catch {
                print("Error subscribing to topic in background handler: \(error)")
            }
        }
    }
    
    @objc private func appDidEnterBackground() {
        // Start a background task when app enters background
        Task {
            await startBackgroundTask()
        }
        
        // Ensure we're still connected to receive messages
        if let realtime = realtime, realtime.isConnected {
            print("App entered background, maintaining connection")
        }
    }
    
    @objc private func appWillEnterForeground() {
        // End background task when app comes to foreground
        Task {
            await endBackgroundTask()
        }
    }
    
    private func startBackgroundTask() async {
        // End any existing background task
        await endBackgroundTask()
        
        // Start a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task {
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
    
    private func scheduleNotification(for message: String) async {
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
    
    private class BackgroundMessageListener: MessageListener {
        weak var handler: BackgroundMessageHandler?
        
        init(handler: BackgroundMessageHandler) {
            self.handler = handler
        }
        
        func onMessage(_ message: Any) {
            Task {
                // Start background task to ensure we can process the message
                await handler?.startBackgroundTask()
                
                // Handle different message types
                if let messageText = message as? String {
                    // Simple text message
                    await handler?.scheduleNotification(for: messageText)
                } else if let messageDict = message as? [String: Any] {
                    // Dictionary format
                    if let text = messageDict["text"] as? String {
                        await handler?.scheduleNotification(for: text)
                    }
                }
                
                // End background task after processing
                await handler?.endBackgroundTask()
            }
        }
    }
} 