//
//  MessageListener.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//
import Foundation

/// Protocol for handling realtime messages
/// - Note: This protocol is class-bound to support weak references
public protocol MessageListener: AnyObject {
    /// Called when a message is received
    /// - Parameter message: The message content (String, Double, or JSON object)
    func onMessage(_ message: Any)
}
