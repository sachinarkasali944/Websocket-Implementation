//
//  ConnectView.swift
//  Websocket
//
//  Created by Sachin Arkasali on 08/05/26.
//
//  This screen teaches:
//    • How to open / close a WebSocket connection
//    • The connection state machine (disconnected → connecting → connected → …)
//    • A live event log showing every frame that travels over the wire

import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var ws: WebSocketManager
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    connectionCard
                    urlCard
                    actionButtons
                    eventLogCard
                }
                .padding()
            }
            .navigationTitle("Connect")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo.toggle() } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showInfo) { InfoSheet() }
        }
    }

    // ── Connection status card ─────────────────────────────────────────────────

    private var connectionCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: stateColor.opacity(0.6), radius: 4)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                               value: ws.connectionState == .connecting)
                Text(ws.connectionState.label)
                    .font(.headline)
                Spacer()
                Text("URLSessionWebSocketTask")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            // State machine diagram
            HStack(spacing: 0) {
                ForEach(stateMachineSteps, id: \.0) { step in
                    Text(step.1)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(step.0 ? Color.accentColor : Color.secondary.opacity(0.15),
                                    in: Capsule())
                        .foregroundStyle(step.0 ? .white : .secondary)
                    if step.1 != stateMachineSteps.last?.1 {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var stateMachineSteps: [(Bool, String)] {
        switch ws.connectionState {
        case .disconnected:   return [(true,"Disconnected"),(false,"Connecting"),(false,"Connected"),(false,"Closed")]
        case .connecting:     return [(false,"Disconnected"),(true,"Connecting"),(false,"Connected"),(false,"Closed")]
        case .connected:      return [(false,"Disconnected"),(false,"Connecting"),(true,"Connected"),(false,"Closed")]
        case .disconnecting:  return [(false,"Disconnected"),(false,"Connecting"),(false,"Connected"),(true,"Closing")]
        case .error:          return [(false,"Disconnected"),(false,"Connecting"),(false,"Connected"),(true,"Error")]
        }
    }

    private var stateColor: Color {
        switch ws.connectionState {
        case .connected:               return .green
        case .connecting,.disconnecting: return .orange
        case .disconnected:            return .gray
        case .error:                   return .red
        }
    }

    // ── URL input card ────────────────────────────────────────────────────────

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Server URL", systemImage: "network")
                .font(.subheadline.bold())

            TextField("wss://…", text: $ws.urlString)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .disabled(ws.connectionState.isConnected)

            // Quick-pick servers
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickPickButton("Echo Server",   url: "wss://echo.websocket.events",  ws: ws)
                    QuickPickButton("Postman Echo",  url: "wss://ws.postman-echo.com/raw", ws: ws)
                    QuickPickButton("Local Node.js", url: "ws://localhost:3000",           ws: ws)
                }
            }

            Text("The URL must start with ws:// (plain) or wss:// (TLS encrypted).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // ── Action buttons ────────────────────────────────────────────────────────

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                ws.connect()
            } label: {
                Label("Connect", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(ws.connectionState.isConnected || ws.connectionState == .connecting)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                ws.disconnect()
            } label: {
                Label("Disconnect", systemImage: "bolt.slash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!ws.connectionState.isConnected)
        }
    }

    // ── Event log ─────────────────────────────────────────────────────────────

    private var eventLogCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Event Log", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.bold())
                Spacer()
                if !ws.events.isEmpty {
                    Button("Clear", role: .destructive) { ws.clearEvents() }
                        .font(.caption)
                }
            }

            if ws.events.isEmpty {
                ContentUnavailableView(
                    "No events yet",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Tap Connect to start a WebSocket session")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(ws.events) { event in
                        EventRow(event: event)
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Sub-views

private struct QuickPickButton: View {
    let label: String
    let url: String
    let ws: WebSocketManager

    init(_ label: String, url: String, ws: WebSocketManager) {
        self.label = label; self.url = url; self.ws = ws
    }

    var body: some View {
        Button(label) { ws.urlString = url }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ws.urlString == url ? Color.accentColor : Color.secondary.opacity(0.15),
                        in: Capsule())
            .foregroundStyle(ws.urlString == url ? .white : .primary)
            .disabled(ws.connectionState.isConnected)
    }
}

private struct EventRow: View {
    let event: WSEvent

    var iconColor: Color {
        switch event.kind {
        case .connected:       return .green
        case .disconnected:    return .gray
        case .messageSent:     return .blue
        case .messageReceived: return .purple
        case .ping:            return .orange
        case .pong:            return .teal
        case .error:           return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.kind.icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.detail)
                    .font(.caption)
                    .lineLimit(3)
                Text(event.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct InfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What is a WebSocket?") {
                    Text("A WebSocket is a persistent, full-duplex communication channel over a single TCP connection. Unlike HTTP (request → response), either side can send data at any time.")
                        .padding(.vertical, 4)
                }
                Section("The Handshake") {
                    Text("The client sends an HTTP/1.1 request with 'Upgrade: websocket'. The server replies with '101 Switching Protocols'. From that point on, the connection is no longer HTTP.")
                        .padding(.vertical, 4)
                }
                Section("URL Schemes") {
                    Label("ws://  — plain (no encryption)", systemImage: "lock.open")
                    Label("wss:// — TLS encrypted (use in production)", systemImage: "lock.fill")
                }
                Section("Close Codes") {
                    Text("1000 = Normal closure\n1001 = Going away\n1006 = Abnormal (no close frame)\n1011 = Server error")
                        .font(.caption)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("WebSocket Basics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ConnectView().environmentObject(WebSocketManager())
}
