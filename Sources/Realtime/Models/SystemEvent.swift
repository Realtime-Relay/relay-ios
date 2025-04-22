//
//  SystemEvent.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//

import Foundation


/// System events for internal SDK events
public enum SystemEvent: String, CaseIterable {
    case connected = "CONNECTED"
    case disconnected = "DISCONNECTED"
    case reconnecting = "RECONNECTING"
    case reconnected = "RECONNECT"
    case messageResend = "MESSAGE_RESEND"
    
    /// Reserved system topics that cannot be used by clients
    static var reservedTopics: Set<String> {
        return Set(SystemEvent.allCases.map { $0.rawValue })
    }
}
