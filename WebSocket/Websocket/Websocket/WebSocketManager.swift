//
//  WebSocketManager.swift
//  Websocket
//
//  Created by Sachin Arkasali on 08/05/26.
//

import Foundation
import Combine

/// Core WebSocket manager built on top of Apple's URLSessionWebSocketTask.
///
/// KEY CONCEPTS demonstrated here:
///   1. Handshake  – upgrading an HTTP request to a WebSocket connection
///   2. Frames     – text or binary messages sent as discrete frames
///   3. Ping/Pong  – built-in heartbeat to keep the connection alive
///   4. Close      – graceful teardown with a close code & reason
///   5. Receive loop – you must re-arm the receive after every message

@MainActor
final class WebSocketManager: ObservableObject {

    // ── Published state (drives all views) ────────────────────────────────────
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage]          = []
    @Published var events: [WSEvent]                = []
    @Published var pingSamples: [PingSample]        = []
    @Published var urlString: String                = "wss://echo.websocket.events"

    // ── Private ────────────────────────────────────────────────────────────────
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingSequence = 0
    private var pendingPings: [Int: PingSample] = [:]  // seq → sample

    // ── Connect ────────────────────────────────────────────────────────────────

    /// Opens the WebSocket connection.
    /// Under the hood URLSession sends an HTTP/1.1 Upgrade request;
    /// the server responds with 101 Switching Protocols.
    func connect() {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            log(.error, "Invalid URL")
            connectionState = .error("Invalid URL")
            return
        }

        connectionState = .connecting
        log(.connected, "Opening connection to \(url.host ?? url.absoluteString)")

        session = URLSession(configuration: .default)
        task    = session?.webSocketTask(with: url)
        task?.resume()    // ← triggers the HTTP → WebSocket upgrade handshake

        // Start the recursive receive loop immediately after resume()
        scheduleReceive()

        // Give the task a moment to complete the handshake
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if self.connectionState == .connecting {
                self.connectionState = .connected
                self.log(.connected, "Handshake complete ✓")
            }
        }
    }

    // ── Disconnect ────────────────────────────────────────────────────────────

    /// Closes the connection with a normal close code (1000).
    /// The close frame is a standard WebSocket control frame.
    func disconnect() {
        connectionState = .disconnecting
        log(.disconnected, "Sending close frame (code 1000)")
        task?.cancel(with: .normalClosure, reason: "User disconnected".data(using: .utf8))
        task    = nil
        session = nil
        connectionState = .disconnected
        log(.disconnected, "Connection closed")
    }

    // ── Send a text message ───────────────────────────────────────────────────

    /// Sends a UTF-8 text frame to the server.
    func send(_ text: String) {
        guard connectionState.isConnected else { return }
        let message = URLSessionWebSocketTask.Message.string(text)

        task?.send(message) { [weak self] error in
            Task { @MainActor [weak self] in
                if let error {
                    self?.log(.error, "Send failed: \(error.localizedDescription)")
                    return
                }
                self?.log(.messageSent, text)
                self?.messages.append(ChatMessage(text: text, sender: .me, timestamp: Date()))
            }
        }
    }

    // ── Send a ping ───────────────────────────────────────────────────────────

    /// Sends a WebSocket ping frame and measures round-trip time.
    /// The server automatically replies with a pong frame.
    func sendPing() {
        guard connectionState.isConnected else { return }
        pingSequence += 1
        let seq = pingSequence

        var sample = PingSample(sequence: seq, sentAt: Date())
        pingSamples.append(sample)
        log(.ping, "Ping #\(seq) sent")

        task?.sendPing { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.log(.error, "Ping #\(seq) failed: \(error.localizedDescription)")
                    return
                }
                // Pong received – calculate latency
                if let idx = self.pingSamples.firstIndex(where: { $0.sequence == seq }) {
                    self.pingSamples[idx].receivedAt = Date()
                    if let ms = self.pingSamples[idx].latencyMs {
                        self.log(.pong, String(format: "Pong #%d  %.1f ms", seq, ms))
                    }
                }
            }
        }
    }

    // ── Receive loop ──────────────────────────────────────────────────────────

    /// WebSocket reception is not a stream — you must call receive() again
    /// after each message to keep listening. This is the "re-arm" pattern.
    private func scheduleReceive() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success(let message):
                    self.handleIncoming(message)
                    // ✅ Re-arm: ask for the next message
                    self.scheduleReceive()

                case .failure(let error):
                    // Connection was closed or an error occurred
                    let nsError = error as NSError
                    // Code 57 = "Socket is not connected" (normal after disconnect)
                    if nsError.code != 57 {
                        self.connectionState = .error(error.localizedDescription)
                        self.log(.error, error.localizedDescription)
                    }
                    self.connectionState = .disconnected
                }
            }
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            log(.messageReceived, text)
            messages.append(ChatMessage(text: text, sender: .server, timestamp: Date()))

        case .data(let data):
            let text = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
            log(.messageReceived, text)
            messages.append(ChatMessage(text: text, sender: .server, timestamp: Date()))

        @unknown default:
            break
        }
    }

    // ── Event log helper ──────────────────────────────────────────────────────

    private func log(_ kind: WSEventKind, _ detail: String) {
        events.insert(WSEvent(kind: kind, detail: detail, timestamp: Date()), at: 0)
        if events.count > 200 { events = Array(events.prefix(200)) }
    }

    // ── Clear helpers ─────────────────────────────────────────────────────────

    func clearMessages()    { messages    = [] }
    func clearEvents()      { events      = [] }
    func clearPingSamples() { pingSamples = [] }
}
