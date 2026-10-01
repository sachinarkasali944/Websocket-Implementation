//
//  PingView.swift
//  Websocket
//
//  Created by Sachin Arkasali on 08/05/26.
//
//  This screen teaches:
//    • Ping / Pong control frames — the built-in WebSocket heartbeat mechanism
//    • Round-trip latency measurement
//    • Why heartbeats matter (NAT/firewall keep-alive, detecting dead connections)

import SwiftUI

struct PingView: View {
    @EnvironmentObject var ws: WebSocketManager
    @State private var autoPingEnabled = false
    @State private var autoPingTimer: Timer? = nil
    @State private var autoPingInterval: Double = 2.0

    var completedSamples: [PingSample] {
        ws.pingSamples.filter { $0.latencyMs != nil }
    }

    var avgLatency: Double? {
        guard !completedSamples.isEmpty else { return nil }
        return completedSamples.compactMap(\.latencyMs).reduce(0, +) / Double(completedSamples.count)
    }

    var minLatency: Double? { completedSamples.compactMap(\.latencyMs).min() }
    var maxLatency: Double? { completedSamples.compactMap(\.latencyMs).max() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    explanationCard
                    if !ws.connectionState.isConnected { notConnectedCard }
                    statsCard
                    controlCard
                    historyCard
                }
                .padding()
            }
            .navigationTitle("Ping / Pong")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !ws.pingSamples.isEmpty {
                        Button("Clear", role: .destructive) { ws.clearPingSamples() }
                    }
                }
            }
        }
        .onDisappear { stopAutoPing() }
    }

    // ── Explanation card ──────────────────────────────────────────────────────

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What is Ping/Pong?", systemImage: "dot.radiowaves.left.and.right")
                .font(.subheadline.bold())

            Text("Ping and Pong are **control frames** defined in the WebSocket spec (RFC 6455). They are separate from data frames and are used to:")
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                BulletRow("Keep TCP connections alive through NAT / firewalls")
                BulletRow("Detect broken connections before trying to send data")
                BulletRow("Measure round-trip latency between client and server")
            }

            Text("Apple's URLSession handles Pong responses automatically — you just send a Ping and get a callback when the Pong arrives.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // ── Not-connected banner ──────────────────────────────────────────────────

    private var notConnectedCard: some View {
        Label("Connect first from the Connect tab", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
    }

    // ── Stats card ────────────────────────────────────────────────────────────

    private var statsCard: some View {
        HStack {
            StatBox(title: "Avg", value: avgLatency.map { String(format: "%.1f ms", $0) } ?? "—", color: .blue)
            Divider().frame(height: 40)
            StatBox(title: "Min", value: minLatency.map { String(format: "%.1f ms", $0) } ?? "—", color: .green)
            Divider().frame(height: 40)
            StatBox(title: "Max", value: maxLatency.map { String(format: "%.1f ms", $0) } ?? "—", color: .red)
            Divider().frame(height: 40)
            StatBox(title: "Count", value: "\(completedSamples.count)", color: .purple)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // ── Control card ──────────────────────────────────────────────────────────

    private var controlCard: some View {
        VStack(spacing: 14) {
            // Manual ping
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                ws.sendPing()
            } label: {
                Label("Send Ping", systemImage: "dot.radiowaves.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!ws.connectionState.isConnected)

            Divider()

            // Auto-ping toggle
            Toggle(isOn: $autoPingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto Ping")
                        .font(.subheadline.bold())
                    Text("Sends a ping every \(Int(autoPingInterval))s automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!ws.connectionState.isConnected)
            .onChange(of: autoPingEnabled) { _, newValue in
                newValue ? startAutoPing() : stopAutoPing()
            }

            if autoPingEnabled {
                HStack {
                    Text("Interval: \(Int(autoPingInterval))s")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $autoPingInterval, in: 1...10, step: 1)
                        .onChange(of: autoPingInterval) { _, _ in
                            if autoPingEnabled { startAutoPing() }
                        }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // ── History card ──────────────────────────────────────────────────────────

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("History", systemImage: "chart.bar")
                .font(.subheadline.bold())

            if ws.pingSamples.isEmpty {
                Text("Send a ping to see results here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                // Mini bar chart
                if !completedSamples.isEmpty {
                    latencyChart
                    Divider()
                }

                // Table
                LazyVStack(spacing: 0) {
                    ForEach(ws.pingSamples.reversed()) { sample in
                        PingRow(sample: sample)
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var latencyChart: some View {
        let values = completedSamples.suffix(20).compactMap(\.latencyMs)
        let maxVal  = values.max() ?? 1
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.0) { _, val in
                let height = max(4, CGFloat(val / maxVal) * 60)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor(ms: val))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
        .frame(height: 70)
        .padding(.vertical, 4)
    }

    private func barColor(ms: Double) -> Color {
        if ms < 50  { return .green }
        if ms < 150 { return .orange }
        return .red
    }

    // ── Auto-ping helpers ──────────────────────────────────────────────────────

    private func startAutoPing() {
        stopAutoPing()
        autoPingTimer = Timer.scheduledTimer(withTimeInterval: autoPingInterval, repeats: true) { _ in
            Task { @MainActor in ws.sendPing() }
        }
    }

    private func stopAutoPing() {
        autoPingTimer?.invalidate()
        autoPingTimer = nil
        autoPingEnabled = false
    }
}

// MARK: - Sub-views

private struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.uppercaseSmallCaps())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PingRow: View {
    let sample: PingSample

    var body: some View {
        HStack {
            Text("#\(sample.sequence)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            if let ms = sample.latencyMs {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.teal)
                Text(String(format: "%.1f ms", ms))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ms < 50 ? .green : ms < 150 ? .orange : .red)
            } else {
                Image(systemName: "clock")
                    .foregroundStyle(.orange)
                Text("Waiting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(sample.sentAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct BulletRow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(.secondary)
            Text(text)
        }
        .font(.caption)
    }
}

#Preview {
    PingView().environmentObject(WebSocketManager())
}
