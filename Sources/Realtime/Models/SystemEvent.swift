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
    case reconnect = "RECONNECT"
    case messageResend = "MESSAGE_RESEND"
    case reconnected = "RECONNECTED"
    case reconn_failed = "RECONN_FAILED"
    
    /// Reserved system topics that cannot be used by clients
    static var reservedTopics: Set<String> {
        return Set(SystemEvent.allCases.map { $0.rawValue })
    }
}
