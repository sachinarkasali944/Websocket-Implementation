//
//  ConnectView.swift
//  Websocket
//

import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var ws: WebSocketManager
    @State private var showInfo = false
    @State private var filterKind: WSEventKind? = nil

    var filteredEvents: [WSEvent] {
        guard let filter = filterKind else { return ws.events }
        return ws.events.filter { $0.kind == filter }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.tertiarySystemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        heroStatusCard
                        urlCard
                        actionButtons
                        eventLogSection
                    }
                    .padding()
                }
            }
            .navigationTitle("WebSocket Lab")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showInfo) { InfoSheet() }
        }
    }

    // ── Hero Connection Status Card ───────────────────────────────────────────

    private var heroStatusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                // Pulsing Status Indicator Ring
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .scaleEffect(ws.connectionState == .connecting ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                   value: ws.connectionState == .connecting)

                    Circle()
                        .fill(stateColor)
                        .frame(width: 20, height: 20)
                        .shadow(color: stateColor.opacity(0.8), radius: 8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(ws.connectionState.label)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Text(connectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Protocol")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text("RFC 6455")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.indigo.opacity(0.12), in: Capsule())
                        .foregroundStyle(.indigo)
                }
            }

            Divider()

            // State Machine Flow Visualizer
            HStack(spacing: 4) {
                stateMachineNode("Idle", active: ws.connectionState == .disconnected)
                arrowIcon
                stateMachineNode("Upgrade", active: ws.connectionState == .connecting)
                arrowIcon
                stateMachineNode("Open", active: ws.connectionState.isConnected)
                arrowIcon
                stateMachineNode("Closed", active: ws.connectionState == .disconnecting)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(stateColor.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var connectionSubtitle: String {
        switch ws.connectionState {
        case .disconnected:   return "Ready to initialize TCP handshake"
        case .connecting:     return "Sending HTTP/1.1 Upgrade header..."
        case .connected:      return "Full-duplex channel active"
        case .disconnecting:  return "Transmitting close frame 1000..."
        case .error(let msg): return "Failure: \(msg)"
        }
    }

    private func stateMachineNode(_ label: String, active: Bool) -> some View {
        Text(label)
            .font(.caption2.weight(active ? .bold : .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? stateColor : Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(active ? .white : .secondary)
    }

    private var arrowIcon: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private var stateColor: Color {
        switch ws.connectionState {
        case .connected:                 return .green
        case .connecting, .disconnecting: return .orange
        case .disconnected:              return .gray
        case .error:                     return .red
        }
    }

    // ── Server URL Picker Card ────────────────────────────────────────────────

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Target Server Endpoint", systemImage: "network")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            HStack {
                Image(systemName: ws.urlString.hasPrefix("wss://") ? "lock.fill" : "lock.open.fill")
                    .foregroundStyle(ws.urlString.hasPrefix("wss://") ? .green : .orange)
                    .font(.subheadline)

                TextField("ws:// or wss:// endpoint", text: $ws.urlString)
                    .font(.subheadline.monospaced())
                    .textFieldStyle(.plain)
                    .disabled(ws.connectionState.isConnected)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !ws.urlString.isEmpty && !ws.connectionState.isConnected {
                    Button {
                        ws.urlString = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            // Verified Endpoint Quick-Pick Buttons
            VStack(alignment: .leading, spacing: 6) {
                Text("VERIFIED ENDPOINTS")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        EndpointPill(
                            title: "Postman Echo",
                            tag: "TLS Echo",
                            url: "wss://ws.postman-echo.com/raw",
                            ws: ws
                        )
                        EndpointPill(
                            title: "Echo Org",
                            tag: "Public",
                            url: "wss://echo.websocket.org",
                            ws: ws
                        )
                        EndpointPill(
                            title: "Local Node.js",
                            tag: "Port 3000",
                            url: "ws://localhost:3000",
                            ws: ws
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // ── Action Buttons ────────────────────────────────────────────────────────

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                ws.connect()
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Connect")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(ws.connectionState.isConnected || ws.connectionState == .connecting)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                ws.disconnect()
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Disconnect")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(!ws.connectionState.isConnected)
        }
    }

    // ── Wire Frame Event Log ──────────────────────────────────────────────────

    private var eventLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wire Frame Inspector", systemImage: "terminal.fill")
                    .font(.subheadline.bold())
                Spacer()
                if !ws.events.isEmpty {
                    Button("Clear", role: .destructive) {
                        ws.clearEvents()
                    }
                    .font(.caption.bold())
                }
            }

            if ws.events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No frame activity yet")
                        .font(.subheadline.bold())
                    Text("Tap Connect above to capture the WebSocket HTTP upgrade handshake and data frames.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredEvents) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Sub-components

private struct EndpointPill: View {
    let title: String
    let tag: String
    let url: String
    let ws: WebSocketManager

    var isSelected: Bool { ws.urlString == url }

    var body: some View {
        Button {
            ws.urlString = url
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.bold())
                    Text(tag)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing) :
                LinearGradient(colors: [Color(.secondarySystemGroupedBackground)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .disabled(ws.connectionState.isConnected)
    }
}

private struct EventRow: View {
    let event: WSEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.kind.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(event.detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(4)

                Text(event.formattedTime)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var iconColor: Color {
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
}

private struct InfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("WebSocket Protocol Overview") {
                    Text("WebSockets provide a full-duplex, persistent TCP connection between client and server, allowing data to be pushed in real-time with minimal frame overhead.")
                }
                Section("Verified Test Endpoints") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• wss://ws.postman-echo.com/raw").bold()
                        Text("Postman's official TLS WebSocket echo service.").font(.caption)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• wss://echo.websocket.org").bold()
                        Text("Public WebSocket standard echo server.").font(.caption)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• ws://localhost:3000").bold()
                        Text("Local Node.js WebSocket server included in this project.").font(.caption)
                    }
                }
            }
            .navigationTitle("Protocol Guide")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
