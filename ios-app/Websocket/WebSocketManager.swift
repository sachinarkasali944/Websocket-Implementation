//
//  WebSocketManager.swift
//  Websocket
//
//  Created by Sachin Arkasali on 08/05/26.
//

import Foundation
import Combine

/// Core WebSocket manager built on top of Apple's URLSessionWebSocketTask.
/// Conforms to URLSessionWebSocketDelegate to receive genuine connection handshake & closure events.
@MainActor
final class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {

    // ── Published state (drives SwiftUI views) ────────────────────────────────
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage]          = []
    @Published var events: [WSEvent]                = []
    @Published var pingSamples: [PingSample]        = []
    @Published var urlString: String                = "wss://ws.postman-echo.com/raw"

    // ── Private Properties ───────────────────────────────────────────────────
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingSequence = 0

    // ── Connect ────────────────────────────────────────────────────────────────

    /// Opens the WebSocket connection.
    /// Under the hood URLSession sends an HTTP/1.1 Upgrade request;
    /// the server responds with 101 Switching Protocols.
    func connect() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              !urlString.isEmpty else {
            log(.error, "Invalid WebSocket URL")
            connectionState = .error("Invalid WebSocket URL")
            return
        }

        disconnect() // Clean up any active session first

        connectionState = .connecting
        log(.connected, "Initiating HTTP Upgrade handshake → \(url.host ?? url.absoluteString)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        // Start listening for incoming frames immediately
        scheduleReceive()
    }

    // ── Disconnect ────────────────────────────────────────────────────────────

    /// Closes the connection with a normal close code (1000).
    func disconnect() {
        guard task != nil || connectionState != .disconnected else { return }
        connectionState = .disconnecting
        log(.disconnected, "Sending close frame (code 1000 Normal Closure)")
        task?.cancel(with: .normalClosure, reason: "User requested disconnect".data(using: .utf8))
        task = nil
        session?.invalidateAndCancel()
        session = nil
        connectionState = .disconnected
        log(.disconnected, "Connection teardown complete")
    }

    // ── Send Text Frame ───────────────────────────────────────────────────────

    /// Sends a UTF-8 text frame to the server.
    func send(_ text: String) {
        guard connectionState.isConnected else {
            log(.error, "Cannot send message: Not connected")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(text)
        task?.send(message) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.log(.error, "Send failed: \(error.localizedDescription)")
                    return
                }
                self.log(.messageSent, text)
                self.messages.append(ChatMessage(text: text, sender: .me, timestamp: Date()))
            }
        }
    }

    // ── Send Ping Control Frame ───────────────────────────────────────────────

    /// Sends a WebSocket ping frame and measures round-trip latency.
    func sendPing() {
        guard connectionState.isConnected else { return }
        pingSequence += 1
        let seq = pingSequence

        let sample = PingSample(sequence: seq, sentAt: Date())
        pingSamples.append(sample)
        log(.ping, "Ping #\(seq) frame transmitted")

        task?.sendPing { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.log(.error, "Ping #\(seq) failed: \(error.localizedDescription)")
                    return
                }
                // Pong control frame received
                if let idx = self.pingSamples.firstIndex(where: { $0.sequence == seq }) {
                    self.pingSamples[idx].receivedAt = Date()
                    if let ms = self.pingSamples[idx].latencyMs {
                        self.log(.pong, String(format: "Pong #%d received (%.1f ms)", seq, ms))
                    }
                }
            }
        }
    }

    // ── Receive Loop (Re-arm Pattern) ─────────────────────────────────────────

    private func scheduleReceive() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    // If we were connecting, mark as connected
                    if self.connectionState == .connecting {
                        self.connectionState = .connected
                        self.log(.connected, "Connected & receiving data ✓")
                    }
                    self.handleIncoming(message)
                    // 🔄 Re-arm: listen for next frame
                    self.scheduleReceive()

                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code != 57 && nsError.code != 89 { // 57 = Socket not connected after close
                        self.connectionState = .error(error.localizedDescription)
                        self.log(.error, "Receive error: \(error.localizedDescription)")
                    } else {
                        self.connectionState = .disconnected
                    }
                }
            }
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let str):
            text = str
        case .data(let data):
            text = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
        @unknown default:
            return
        }

        log(.messageReceived, text)

        // Intelligently parse JSON protocol messages if present
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {

            switch type {
            case "chat":
                let senderName = json["username"] as? String ?? "Server"
                let content = json["text"] as? String ?? text
                messages.append(ChatMessage(text: "[\(senderName)]: \(content)", sender: .server, timestamp: Date()))
            case "user_joined":
                let name = json["username"] as? String ?? "User"
                messages.append(ChatMessage(text: "⚡ \(name) joined the server", sender: .system, timestamp: Date()))
            case "user_left":
                let name = json["username"] as? String ?? "User"
                messages.append(ChatMessage(text: "⚡ \(name) left the server", sender: .system, timestamp: Date()))
            case "welcome":
                let name = json["username"] as? String ?? "You"
                messages.append(ChatMessage(text: "⚡ Welcome! Connected as \(name)", sender: .system, timestamp: Date()))
            default:
                messages.append(ChatMessage(text: text, sender: .server, timestamp: Date()))
            }
        } else {
            messages.append(ChatMessage(text: text, sender: .server, timestamp: Date()))
        }
    }

    // ── Logging & Utilities ───────────────────────────────────────────────────

    private func log(_ kind: WSEventKind, _ detail: String) {
        events.insert(WSEvent(kind: kind, detail: detail, timestamp: Date()), at: 0)
        if events.count > 200 { events = Array(events.prefix(200)) }
    }

    func clearMessages()    { messages    = [] }
    func clearEvents()      { events      = [] }
    func clearPingSamples() { pingSamples = [] }

    // ── URLSessionWebSocketDelegate Handlers ───────────────────────────────────

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            self.connectionState = .connected
            let proto = `protocol` ?? "standard"
            self.log(.connected, "HTTP 101 Upgrade Successful! Protocol: \(proto)")
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Normal disconnect"
            self.connectionState = .disconnected
            self.log(.disconnected, "Close frame received. Code \(closeCode.rawValue): \(reasonStr)")
        }
    }
}
