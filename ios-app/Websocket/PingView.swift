//
//  PingView.swift
//  Websocket
//

import SwiftUI

struct PingView: View {
    @EnvironmentObject var ws: WebSocketManager
    @State private var autoPingEnabled = false
    @State private var autoPingTimer: Timer? = nil
    @State private var autoPingInterval: Double = 2.0

    var completedSamples: [PingSample] {
        ws.pingSamples.filter { $0.latencyMs != nil }
    }

    var lastLatency: Double? { completedSamples.last?.latencyMs }
    var avgLatency: Double? {
        guard !completedSamples.isEmpty else { return nil }
        return completedSamples.compactMap(\.latencyMs).reduce(0, +) / Double(completedSamples.count)
    }

    var minLatency: Double? { completedSamples.compactMap(\.latencyMs).min() }
    var maxLatency: Double? { completedSamples.compactMap(\.latencyMs).max() }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if !ws.connectionState.isConnected {
                            notConnectedBanner
                        }

                        heroLatencyGauge
                        statsGrid
                        controlCard
                        historyChartSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Ping / Pong Latency")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !ws.pingSamples.isEmpty {
                        Button("Clear", role: .destructive) {
                            ws.clearPingSamples()
                        }
                        .font(.caption.bold())
                    }
                }
            }
        }
        .onDisappear { stopAutoPing() }
    }

    private var notConnectedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Not Connected — Connect in the 'Connect' tab first")
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
    }

    // ── Hero RTT Gauge ────────────────────────────────────────────────────────

    private var heroLatencyGauge: some View {
        VStack(spacing: 8) {
            Text("ROUND-TRIP LATENCY (RTT)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let ms = lastLatency {
                    Text(String(format: "%.1f", ms))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(latencyColor(ms))
                    Text("ms")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("ms")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Text("WebSocket Control Frame (0x9 Ping → 0xA Pong)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // ── Metrics Grid ──────────────────────────────────────────────────────────

    private var statsGrid: some View {
        HStack(spacing: 12) {
            MetricCard(title: "Avg RTT", value: avgLatency.map { String(format: "%.1f ms", $0) } ?? "—", color: .blue)
            MetricCard(title: "Min RTT", value: minLatency.map { String(format: "%.1f ms", $0) } ?? "—", color: .green)
            MetricCard(title: "Max RTT", value: maxLatency.map { String(format: "%.1f ms", $0) } ?? "—", color: .red)
            MetricCard(title: "Frames", value: "\(completedSamples.count)", color: .purple)
        }
    }

    // ── Control Card ──────────────────────────────────────────────────────────

    private var controlCard: some View {
        VStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                ws.sendPing()
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Transmit Ping Frame")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(!ws.connectionState.isConnected)

            Divider()

            Toggle(isOn: $autoPingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automated Heartbeat")
                        .font(.subheadline.bold())
                    Text("Pings every \(Int(autoPingInterval))s automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!ws.connectionState.isConnected)
            .onChange(of: autoPingEnabled) { _, newValue in
                newValue ? startAutoPing() : stopAutoPing()
            }

            if autoPingEnabled {
                HStack(spacing: 12) {
                    Text("Interval: \(Int(autoPingInterval))s")
                        .font(.caption.monospacedDigit())
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $autoPingInterval, in: 1...10, step: 1)
                        .onChange(of: autoPingInterval) { _, _ in
                            if autoPingEnabled { startAutoPing() }
                        }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // ── History Chart ─────────────────────────────────────────────────────────

    private var historyChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Latency History Spectrum", systemImage: "chart.bar.fill")
                .font(.subheadline.bold())

            if ws.pingSamples.isEmpty {
                VStack(spacing: 8) {
                    Text("No ping samples recorded")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("Tap 'Transmit Ping Frame' to calculate network round-trip time.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                if !completedSamples.isEmpty {
                    latencyBarChart
                }

                LazyVStack(spacing: 8) {
                    ForEach(ws.pingSamples.reversed()) { sample in
                        SampleRow(sample: sample)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var latencyBarChart: some View {
        let values = completedSamples.suffix(20).compactMap(\.latencyMs)
        let maxVal = max(values.max() ?? 1.0, 1.0)

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.0) { _, val in
                let normalizedHeight = max(6, CGFloat(val / maxVal) * 60)
                RoundedRectangle(cornerRadius: 4)
                    .fill(latencyColor(val))
                    .frame(maxWidth: .infinity)
                    .frame(height: normalizedHeight)
            }
        }
        .frame(height: 70)
        .padding(.vertical, 8)
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 50  { return .green }
        if ms < 150 { return .orange }
        return .red
    }

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

private struct MetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SampleRow: View {
    let sample: PingSample

    var body: some View {
        HStack {
            Text("#\(sample.sequence)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            if let ms = sample.latencyMs {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.teal)
                Text(String(format: "%.1f ms", ms))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(ms < 50 ? .green : ms < 150 ? .orange : .red)
            } else {
                Text("Waiting for Pong...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Text(sample.sentAt, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
