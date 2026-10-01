//
//  ChatView.swift
//  Websocket
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var ws: WebSocketManager
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if !ws.connectionState.isConnected {
                        connectionWarningBanner
                    }

                    // Message Stream
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if ws.messages.isEmpty {
                                    emptyState
                                } else {
                                    ForEach(ws.messages) { msg in
                                        MessageBubble(message: msg)
                                            .id(msg.id)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: ws.messages.count) {
                            if let last = ws.messages.last {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Floating Glass Input Bar
                    inputSection
                }
            }
            .navigationTitle("Live Messaging")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !ws.messages.isEmpty {
                        Button("Clear", role: .destructive) {
                            ws.clearMessages()
                        }
                        .font(.caption.bold())
                    }
                }
            }
        }
    }

    private var connectionWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Disconnected — Connect in the 'Connect' tab first")
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo.gradient)
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("Real-Time Frame Stream")
                    .font(.title3.bold())
                Text("Type any text message below to send a WebSocket text frame. The server will respond instantly in real-time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if ws.connectionState.isConnected {
                VStack(spacing: 10) {
                    Text("TRY QUICK PRESETS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        PresetPill(text: "Hello Echo Server!", ws: ws)
                        PresetPill(text: "⚡ Testing Latency", ws: ws)
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    private var inputSection: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                HStack {
                    TextField("Send text frame...", text: $inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .font(.subheadline)
                        .disabled(!ws.connectionState.isConnected)
                        .onSubmit { sendMessage() }

                    if !inputText.isEmpty {
                        Button {
                            inputText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Color.blue.gradient : Color.gray.gradient)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var canSend: Bool {
        ws.connectionState.isConnected && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        ws.send(text)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct PresetPill: View {
    let text: String
    let ws: WebSocketManager

    var body: some View {
        Button(text) {
            ws.send(text)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .font(.caption.bold())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.indigo.opacity(0.12), in: Capsule())
        .foregroundStyle(.indigo)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.sender == .me { Spacer(minLength: 60) }
            if message.sender == .system { Spacer() }

            VStack(alignment: message.sender == .me ? .trailing : .leading, spacing: 4) {
                if message.sender == .server {
                    HStack(spacing: 4) {
                        Image(systemName: "desktopcomputer")
                        Text("Server Response")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                } else if message.sender == .system {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("System Event")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                }

                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundStyle(message.sender == .me ? .white : .primary)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

                Text(message.formattedTime)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if message.sender == .server || message.sender == .system { Spacer(minLength: 60) }
            if message.sender == .system { Spacer() }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch message.sender {
        case .me:
            LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .server:
            Color(.secondarySystemGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .system:
            Color.orange.opacity(0.15)
                .clipShape(Capsule())
        }
    }
}
