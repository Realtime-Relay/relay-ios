//
//  SystemEvent.swift
//  Realtime
//
//  Created by Shaxzod on 10/04/25.
//

import Foundation


/// System events for internal SDK events
public enum SystemEvent: String, CaseIterable {
    case connected = "sdk.connected"
    case disconnected = "sdk.disconnected"
    case reconnecting = "sdk.reconnecting"
    case reconnected = "sdk.reconnected"
    case messageResend = "sdk.message_resend"
    
    /// Reserved system topics that cannot be used by clients
    static var reservedTopics: Set<String> {
        return Set(SystemEvent.allCases.map { $0.rawValue })
    }
}
