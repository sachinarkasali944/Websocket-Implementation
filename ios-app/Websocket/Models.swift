//
//  Models.swift
//  Websocket
//
//  Created by Sachin Arkasali on 08/05/26.
//

import Foundation

// MARK: - Connection State

/// Represents every possible state of a WebSocket connection.
/// Understanding this lifecycle is one of the most important WebSocket concepts.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)

    var label: String {
        switch self {
        case .disconnected:    return "Disconnected"
        case .connecting:      return "Connecting…"
        case .connected:       return "Connected"
        case .disconnecting:   return "Disconnecting…"
        case .error(let msg):  return "Error: \(msg)"
        }
    }

    var color: String {
        switch self {
        case .connected:       return "green"
        case .connecting,
             .disconnecting:   return "orange"
        case .disconnected:    return "gray"
        case .error:           return "red"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Chat Message

/// A single chat message displayed in ChatView.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let sender: MessageSender
    let timestamp: Date

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}

enum MessageSender: Equatable {
    case me
    case server
    case system
}

// MARK: - Event Log Entry

/// Records every WebSocket lifecycle event for the Connection screen.
struct WSEvent: Identifiable {
    let id = UUID()
    let kind: WSEventKind
    let detail: String
    let timestamp: Date

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: timestamp)
    }
}

enum WSEventKind {
    case connected
    case disconnected
    case messageSent
    case messageReceived
    case ping
    case pong
    case error

    var icon: String {
        switch self {
        case .connected:        return "bolt.fill"
        case .disconnected:     return "bolt.slash.fill"
        case .messageSent:      return "arrow.up.circle.fill"
        case .messageReceived:  return "arrow.down.circle.fill"
        case .ping:             return "dot.radiowaves.right"
        case .pong:             return "dot.radiowaves.left.and.right"
        case .error:            return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .connected:        return "green"
        case .disconnected:     return "gray"
        case .messageSent:      return "blue"
        case .messageReceived:  return "purple"
        case .ping:             return "orange"
        case .pong:             return "teal"
        case .error:            return "red"
        }
    }
}

// MARK: - Ping Sample

/// A single round-trip latency measurement.
struct PingSample: Identifiable {
    let id = UUID()
    let sequence: Int
    let sentAt: Date
    var receivedAt: Date?

    var latencyMs: Double? {
        guard let r = receivedAt else { return nil }
        return r.timeIntervalSince(sentAt) * 1000
    }
}
