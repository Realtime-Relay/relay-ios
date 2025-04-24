//
//  RelayDemoApp.swift
//  RelayDemo
//
//  Created by Shaxzod on 22/04/25.
//

import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct RelayDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            TopicInputView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
        
        // Register for background fetch
        registerBackgroundTasks()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background fetch when app enters background
        scheduleBackgroundFetch()
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // This is called when the system performs a background fetch
        print("Background fetch started")
        
        // Schedule a local notification to indicate background fetch
        let content = UNMutableNotificationContent()
        content.title = "Background Fetch"
        content.body = "App is checking for new messages"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling background fetch notification: \(error.localizedDescription)")
            }
        }
        
        // Complete the background fetch
        completionHandler(.newData)
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.relaydemo.refresh", using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleBackgroundFetch() {
        let request = BGAppRefreshTaskRequest(identifier: "com.relaydemo.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled")
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleBackgroundFetch()
        
        // Set up a task expiration handler
        task.expirationHandler = {
            // Cancel any ongoing work
            print("Background refresh task expired")
        }
        
        // Create a task to perform the background work
        let workTask = Task {
            // Simulate some background work
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            
            // Schedule a local notification to indicate background refresh
            let content = UNMutableNotificationContent()
            content.title = "Background Refresh"
            content.body = "App refreshed in background"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            
            try? await UNUserNotificationCenter.current().add(request)
            
            // Mark the task as completed
            task.setTaskCompleted(success: true)
        }
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification when user taps on it
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped with userInfo: \(userInfo)")
        
        completionHandler()
    }
}
