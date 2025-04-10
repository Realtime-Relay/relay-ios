//
//  MessageListener.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//
import Foundation

/// Protocol for receiving messages from the Realtime service
public protocol MessageListener {
    func onMessage(_ message: [String: Any])
}
