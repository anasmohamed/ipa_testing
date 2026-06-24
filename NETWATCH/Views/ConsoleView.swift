// NETWATCH — ConsoleView.swift
// Main war-room console: radar sweep, live stats, threat feed, scan control.

import SwiftUI

struct ConsoleView: View {
    @ObservedObject var scanner: NWScanner

    var body: some View {
        ZStack {
            NWTheme.ink.ignoresSafeArea()
            ScanlineView().ignoresSafeArea().allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    commandBar
                    statStrip
                    radarPanel
                    threatFeedPanel
                    scanButton
                    Spacer(minLength: 80)
                }
            }
        }
    }

    // ── Command Bar ───────────────────────────────────────
    private var commandBar: some View {
        HStack(spacing: 0) {
            // Logo
            VStack(alignment: .leading, spacing: 1) {
                Text("NETWATCH")
                    .font(NWTheme.displayFont(size: 18))
                    .foregroundColor(NWTheme.glow)
                    .shadow(color: NWTheme.glow.opacity(0.8), radius: 6)
                Text("THREAT INTEL v2.1")
                    .font(NWTheme.monoFont(size: 8))
                    .foregroundColor(NWTheme.t2)
                    .tracking(2)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Live dot
            HStack(spacing: 5) {
                Circle()
                    .fill(scanner.isScanning ? NWTheme.glow : NWTheme.t3)
                    .frame(width: 6, height: 6)
                    .shadow(color: scanner.isScanning ? NWTheme.glow : .clear, radius: 4)
                    .scaleEffect(scanner.isScanning ? 1.3 : 1)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                               value: scanner.isScanning)
                Text(scanner.phase.rawValue)
                    .font(NWTheme.monoFont(size: 8, weight: .bold))
                    .foregroundColor(scanner.isScanning ? NWTheme.glow : NWTheme.t3)
                    .tracking(1)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(NWTheme.panel2)
        .overlay(Rectangle().frame(height: 1).foregroundColor(NWTheme.glow).shadow(color: NWTheme.glow.opacity(0.4), radius: 4), alignment: .bottom)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
    }

    // ── Stat Strip ────────────────────────────────────────
    private var statStrip: some View {
        HStack(spacing: 1) {
            StatCell(label: "SUBNET",
                     value: subnetLabel,
                     color: NWTheme.t2)
            StatCell(label: "HOSTS",
                     value: "\(scanner.devices.count)",
                     color: NWTheme.glow)
            StatCell(label: "THREATS",
                     value: "\(scanner.devices.filter { $0.highestRisk != .clean }.count)",
                     color: scanner.devices.contains { $0.highestRisk != .clean } ? NWTheme.high : NWTheme.t3)
            StatCell(label: "CRITICAL",
                     value: "\(scanner.devices.filter { $0.highestRisk == .critical }.count)",
                     color: scanner.devices.contains { $0.highestRisk == .critical } ? NWTheme.critical : NWTheme.t3)
        }
        .background(NWTheme.panel)
    }

    // ── Radar Panel ───────────────────────────────────────
    private var radarPanel: some View {
        VStack(spacing: 0) {
            PanelHeader(tag: "SECTOR RADAR", sub: scanner.isScanning ? scanner.currentIP : "\(scanner.devices.count) HOSTS")

            RadarView(devices: scanner.devices, isScanning: scanner.isScanning)
                .frame(height: 260)
                .padding(16)
        }
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
        .padding(.horizontal, 2)
    }

    // ── Threat Feed Panel ─────────────────────────────────
    private var threatFeedPanel: some View {
        VStack(spacing: 0) {
            PanelHeader(tag: "LIVE THREAT FEED",
                        sub: "\(scanner.devices.filter { $0.highestRisk != .clean }.count) EVENTS")

            if scanner.devices.isEmpty {
                Text("AWAITING SCAN INITIATION")
                    .font(NWTheme.monoFont(size: 10))
                    .foregroundColor(NWTheme.t3)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                VStack(spacing: 4) {
                    ForEach(scanner.devices.sorted { $0.highestRisk < $1.highestRisk }.prefix(8)) { device in
                        ThreatFeedRow(device: device)
                    }
                }
                .padding(10)
            }
        }
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
        .padding(.horizontal, 2)
    }

    // ── Scan Button ───────────────────────────────────────
    private var scanButton: some View {
        VStack(spacing: 8) {
            Button {
                if scanner.isScanning { scanner.stopScan() }
                else { scanner.startScan() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: scanner.isScanning ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(scanner.isScanning ? "ABORT SCAN" : "INITIATE SCAN")
                        .font(NWTheme.displayFont(size: 14))
                        .tracking(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(scanner.isScanning ? NWTheme.critical : NWTheme.ink)
                .background(
                    scanner.isScanning
                    ? NWTheme.critical.opacity(0.1)
                    : NWTheme.glow
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(scanner.isScanning ? NWTheme.critical : NWTheme.glow, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: (scanner.isScanning ? NWTheme.critical : NWTheme.glow).opacity(0.4), radius: 12)
            }
            .padding(.horizontal, 16)

            if scanner.isScanning || scanner.progress > 0 {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(NWTheme.wire)
                            Rectangle()
                                .fill(NWTheme.glow)
                                .frame(width: geo.size.width * scanner.progress)
                                .shadow(color: NWTheme.glow.opacity(0.8), radius: 4)
                        }
                    }
                    .frame(height: 3)
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)

                    Text("\(Int(scanner.progress * 100))% · \(scanner.phase.rawValue)")
                        .font(NWTheme.monoFont(size: 9))
                        .foregroundColor(NWTheme.t2)
                        .tracking(1)
                }
                .animation(.linear(duration: 0.2), value: scanner.progress)
            }
        }
    }

    private var subnetLabel: String {
        guard let ip = scanner.localIPAddress() else { return "NOT CONNECTED" }
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return ip }
        return "\(parts[0]).\(parts[1]).\(parts[2]).x"
    }
}

// ── Shared sub-views ──────────────────────────────────────

struct PanelHeader: View {
    let tag: String
    let sub: String
    var body: some View {
        HStack {
            Text(tag)
                .font(NWTheme.monoFont(size: 9, weight: .bold))
                .foregroundColor(NWTheme.glow)
                .tracking(2)
                .shadow(color: NWTheme.glow.opacity(0.5), radius: 4)
            Spacer()
            Text(sub)
                .font(NWTheme.monoFont(size: 9))
                .foregroundColor(NWTheme.t3)
                .tracking(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(NWTheme.panel2)
        .overlay(Rectangle().frame(height: 1).foregroundColor(NWTheme.wire), alignment: .bottom)
    }
}

struct StatCell: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(NWTheme.displayFont(size: 20))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.6), radius: 6)
            Text(label)
                .font(NWTheme.monoFont(size: 7))
                .foregroundColor(NWTheme.t3)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(NWTheme.panel2)
        .overlay(Rectangle().frame(width: 1).foregroundColor(NWTheme.wire), alignment: .leading)
    }
}

struct ThreatFeedRow: View {
    let device: NetworkDevice
    @State private var appeared = false

    private var riskColor: Color { NWTheme.riskColor(device.highestRisk) }

    var body: some View {
        HStack(spacing: 10) {
            // Left accent bar
            Rectangle()
                .fill(riskColor)
                .frame(width: 3)
                .shadow(color: riskColor.opacity(0.8), radius: 3)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(device.highestRisk.rawValue)
                        .font(NWTheme.monoFont(size: 8, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(riskColor.opacity(0.12))
                        .foregroundColor(riskColor)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(riskColor.opacity(0.3), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    Spacer()

                    Text(device.ipAddress)
                        .font(NWTheme.monoFont(size: 11, weight: .medium))
                        .foregroundColor(NWTheme.t1)
                }

                Text(device.hostname ?? device.ipAddress)
                    .font(NWTheme.monoFont(size: 9))
                    .foregroundColor(NWTheme.t2)

                if !device.suspiciousPorts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(device.suspiciousPorts, id: \.port) { p in
                                Text(":\(p.port)/\(p.service)")
                                    .font(NWTheme.monoFont(size: 8))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(NWTheme.riskColor(p.risk).opacity(0.08))
                                    .foregroundColor(NWTheme.riskColor(p.risk))
                                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(NWTheme.riskColor(p.risk).opacity(0.3), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                        }
                    }
                } else {
                    Text("✓ NO SUSPICIOUS PORTS")
                        .font(NWTheme.monoFont(size: 8))
                        .foregroundColor(NWTheme.glow.opacity(0.6))
                }
            }
            .padding(.vertical, 8)
            .padding(.trailing, 8)
        }
        .background(NWTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(NWTheme.wire, lineWidth: 1))
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
    }
}
