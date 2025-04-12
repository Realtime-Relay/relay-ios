//
//  MessageListener.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//
import Foundation

/// Protocol for receiving messages from the Realtime service
public protocol MessageListener {
    /// Called when a message is received
    /// - Parameter message: The message content which can be:
    ///   - String: For text messages
    ///   - Double: For numeric messages
    ///   - [String: Any]: For JSON messages
    func onMessage(_ message: Any)
}
