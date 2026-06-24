// NETWATCH — HeatmapView.swift
// 254-cell subnet heatmap + Port Fingerprint Matrix (threat DNA).
// Cells light up from dark → risk colour as each host is discovered.

import SwiftUI

struct HeatmapView: View {
    @ObservedObject var scanner: NWScanner

    var body: some View {
        ZStack {
            NWTheme.ink.ignoresSafeArea()
            ScanlineView().ignoresSafeArea().allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    heatmapPanel
                    dnaPanel
                    scalePanel
                    Spacer(minLength: 80)
                }
            }
        }
    }

    // ── Heatmap ───────────────────────────────────────────
    private var heatmapPanel: some View {
        VStack(spacing: 0) {
            PanelHeader(tag: "SUBNET HEATMAP — 192.168.1.0/24", sub: "254 ADDRESSES")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 25),
                spacing: 2
            ) {
                ForEach(1...254, id: \.self) { octet in
                    HeatCell(octet: octet, devices: scanner.devices)
                }
            }
            .padding(10)
        }
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
        .padding(.horizontal, 2)
    }

    // ── Port Fingerprint Matrix ───────────────────────────
    private let ports = [21,22,23,80,111,135,445,2049,3306,3389,5900,6379,8080,27017]
    private let portRisk: [Int: RiskLevel] = [
        21:.high, 22:.medium, 23:.critical, 80:.clean, 111:.medium,
        135:.high, 445:.critical, 2049:.medium, 3306:.high, 3389:.critical,
        5900:.high, 6379:.medium, 8080:.high, 27017:.high
    ]

    private var dnaPanel: some View {
        VStack(spacing: 0) {
            PanelHeader(tag: "PORT FINGERPRINT MATRIX", sub: "THREAT DNA")

            if scanner.devices.isEmpty {
                Text("NO DATA — RUN A SCAN")
                    .font(NWTheme.monoFont(size: 10))
                    .foregroundColor(NWTheme.t3)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                VStack(spacing: 0) {
                    // Port header row
                    HStack(spacing: 1) {
                        // Device icon column header
                        Text("DEV")
                            .font(NWTheme.monoFont(size: 6))
                            .foregroundColor(NWTheme.t3)
                            .frame(width: 24)

                        ForEach(ports, id: \.self) { p in
                            Text(":\(p)")
                                .font(NWTheme.monoFont(size: 5))
                                .foregroundColor(NWTheme.t3)
                                .rotationEffect(.degrees(-60))
                                .frame(maxWidth: .infinity)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    // Device rows
                    ForEach(scanner.devices) { device in
                        DNARow(device: device, ports: ports, portRisk: portRisk)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
            }
        }
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
        .padding(.horizontal, 2)
    }

    // ── Risk Scale ────────────────────────────────────────
    private var scalePanel: some View {
        HStack(spacing: 8) {
            Text("CLEAN")
                .font(NWTheme.monoFont(size: 8))
                .foregroundColor(NWTheme.t3)
            LinearGradient(
                colors: [NWTheme.panel2, NWTheme.glow, NWTheme.medium, NWTheme.high, NWTheme.critical],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 4)
            .clipShape(Capsule())
            Text("CRITICAL")
                .font(NWTheme.monoFont(size: 8))
                .foregroundColor(NWTheme.t3)
        }
        .padding(14)
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
        .padding(.horizontal, 2)
    }
}

// ── Heat Cell ─────────────────────────────────────────────
struct HeatCell: View {
    let octet:   Int
    let devices: [NetworkDevice]

    @State private var appeared = false

    private var match: NetworkDevice? {
        devices.first { $0.lastOctet == octet }
    }

    private var cellColor: Color {
        guard let d = match else { return NWTheme.wire }
        return NWTheme.riskColor(d.highestRisk)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor.opacity(appeared ? 1 : 0))
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: match != nil ? cellColor.opacity(0.5) : .clear, radius: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(match != nil ? cellColor.opacity(0.3) : NWTheme.wire.opacity(0.4), lineWidth: 0.5)
            )
            .overlay(
                Group {
                    if match?.isCurrentDevice == true {
                        Text("★")
                            .font(.system(size: 5))
                            .foregroundColor(NWTheme.ink)
                    }
                }
            )
            .onChange(of: match?.id) { _ in
                withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            }
            .onAppear {
                if match != nil { appeared = true }
            }
    }
}

// ── DNA Row ───────────────────────────────────────────────
struct DNARow: View {
    let device:   NetworkDevice
    let ports:    [Int]
    let portRisk: [Int: RiskLevel]

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 1) {
            // Device icon
            Text(device.tacticalIcon)
                .font(NWTheme.monoFont(size: 8, weight: .bold))
                .foregroundColor(NWTheme.riskColor(device.highestRisk))
                .frame(width: 24)

            // Port cells
            ForEach(ports, id: \.self) { p in
                let hasPort = device.openPorts.contains(p)
                let risk    = portRisk[p] ?? .clean
                let col     = hasPort ? NWTheme.riskColor(risk) : NWTheme.wire

                RoundedRectangle(cornerRadius: 2)
                    .fill(col.opacity(hasPort ? 0.8 : 0.15))
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
                    .shadow(color: hasPort ? col.opacity(0.5) : .clear, radius: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(col.opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
        .padding(.vertical, 1)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.3)) { appeared = true } }
    }
}
