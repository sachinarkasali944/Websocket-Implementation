//
//  ChatView.swift
//  Websocket
//
//  Created by Sachin Arkasali on 08/05/26.
//
//  This screen teaches:
//    • Sending text frames to the server
//    • Receiving echo / server responses in real time
//    • Full-duplex: both sides can send without waiting for the other

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var ws: WebSocketManager
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Connection banner ──────────────────────────────────────────
                if !ws.connectionState.isConnected {
                    disconnectedBanner
                }

                // ── Message list ───────────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
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
                        .padding(.vertical, 8)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: ws.messages.count) {
                        if let last = ws.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // ── Input bar ──────────────────────────────────────────────────
                inputBar
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !ws.messages.isEmpty {
                        Button("Clear", role: .destructive) { ws.clearMessages() }
                    }
                }
            }
        }
    }

    // ── Disconnected banner ───────────────────────────────────────────────────

    private var disconnectedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Not connected — go to the Connect tab first")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.orange)
    }

    // ── Empty state ───────────────────────────────────────────────────────────

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("No messages yet")
                    .font(.headline)
                Text("Type something — the echo server will send it right back.\nThis demonstrates full-duplex communication.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }

    // ── Input bar ─────────────────────────────────────────────────────────────

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Type a message…", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    .disabled(!ws.connectionState.isConnected)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? .blue : .gray)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }

    private var canSend: Bool {
        ws.connectionState.isConnected && !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        ws.send(text)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.sender == .me { Spacer(minLength: 60) }
            if message.sender == .system { Spacer() }

            VStack(alignment: message.sender == .me ? .trailing : .leading, spacing: 3) {
                // Sender label
                if message.sender == .system {
                    Text("⚡ System")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                } else if message.sender == .server {
                    Text("🖥 Server (echo)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                // Bubble
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(message.sender == .me ? .white : .primary)

                // Timestamp
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.sender == .server || message.sender == .system { Spacer(minLength: 60) }
            if message.sender == .system { Spacer() }
        }
    }

    private var bubbleColor: Color {
        switch message.sender {
        case .me:     return .blue
        case .server: return Color(.secondarySystemFill)
        case .system: return .orange.opacity(0.15)
        }
    }
}

#Preview {
    ChatView().environmentObject({
        let m = WebSocketManager()
        m.messages = [
            ChatMessage(text: "Hello server!", sender: .me, timestamp: Date()),
            ChatMessage(text: "Hello server!", sender: .server, timestamp: Date()),
        ]
        return m
    }())
}
