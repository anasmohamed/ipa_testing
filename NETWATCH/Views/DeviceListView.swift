// NETWATCH — DeviceListView.swift
// Filterable list of discovered devices + full detail drill-down.

import SwiftUI

@available(iOS 16.0, *)
struct DeviceListView: View {
    @ObservedObject var scanner: NWScanner
    @State private var filter: RiskLevel? = nil
    @State private var search = ""

    private var filtered: [NetworkDevice] {
        scanner.devices
            .filter { filter == nil || $0.highestRisk == filter }
            .filter {
                search.isEmpty ||
                $0.ipAddress.contains(search) ||
                ($0.hostname ?? "").localizedCaseInsensitiveContains(search)
            }
            .sorted { $0.highestRisk < $1.highestRisk }
    }

    var body: some View {
        NavigationView {
            ZStack {
                NWTheme.ink.ignoresSafeArea()
                ScanlineView().ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    filterBar
                    if filtered.isEmpty { emptyState }
                    else { deviceList }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .searchable(text: $search, prompt: "SEARCH IP / HOSTNAME")
        }
        .tint(NWTheme.glow)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "ALL", color: NWTheme.glow, active: filter == nil) { filter = nil }
                ForEach([RiskLevel.critical, .high, .medium, .clean], id: \.self) { r in
                    FilterChip(label: r.rawValue, color: NWTheme.riskColor(r), active: filter == r) { filter = r }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(NWTheme.panel2)
        .overlay(Rectangle().frame(height: 1).foregroundColor(NWTheme.wire), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 36))
                .foregroundColor(NWTheme.t3)
            Text("NO DEVICES FOUND")
                .font(NWTheme.monoFont(size: 11))
                .foregroundColor(NWTheme.t3)
                .tracking(2)
            Text("Run a scan from the Console tab")
                .font(NWTheme.monoFont(size: 10))
                .foregroundColor(NWTheme.t3.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deviceList: some View {
        List(filtered) { device in
            NavigationLink(destination: DeviceDetailView(device: device)) {
                DeviceRow(device: device)
            }
            .listRowBackground(NWTheme.ink)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
        }
        .listStyle(.plain)
        
    }
}

struct FilterChip: View {
    let label: String
    let color: Color
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(NWTheme.monoFont(size: 9, weight: .bold))
                .tracking(1)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(active ? color : color.opacity(0.08))
                .foregroundColor(active ? NWTheme.ink : color)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(active ? 0 : 0.3), lineWidth: 1))
        }
    }
}

struct DeviceRow: View {
    let device: NetworkDevice
    private var col: Color { NWTheme.riskColor(device.highestRisk) }

    var body: some View {
        HStack(spacing: 12) {
            // Icon box
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(col.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(col.opacity(0.3), lineWidth: 1))
                Text(device.tacticalIcon)
                    .font(NWTheme.monoFont(size: 18, weight: .bold))
                    .foregroundColor(col)
            }
            .shadow(color: col.opacity(0.3), radius: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(device.ipAddress)
                        .font(NWTheme.monoFont(size: 13, weight: .semibold))
                        .foregroundColor(NWTheme.t1)
                    if device.isCurrentDevice {
                        Text("YOU")
                            .font(NWTheme.monoFont(size: 7, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(NWTheme.glow.opacity(0.1))
                            .foregroundColor(NWTheme.glow)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                if let h = device.hostname {
                    Text(h)
                        .font(NWTheme.monoFont(size: 10))
                        .foregroundColor(NWTheme.t2)
                }
                Text(device.suspiciousPorts.isEmpty ? "✓ CLEAN" : "\(device.suspiciousPorts.count) SUSPICIOUS PORTS")
                    .font(NWTheme.monoFont(size: 9))
                    .foregroundColor(device.suspiciousPorts.isEmpty ? NWTheme.glow.opacity(0.6) : col)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: device.highestRisk.icon)
                    .foregroundColor(col).font(.system(size: 14))
                Text(device.highestRisk.rawValue)
                    .font(NWTheme.monoFont(size: 7, weight: .bold))
                    .tracking(1)
                    .foregroundColor(col)
            }
        }
        .padding(12)
        .background(NWTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(col.opacity(0.15), lineWidth: 1))
        .overlay(CornerBrackets(color: col, size: 8))
    }
}

// ── Device Detail ─────────────────────────────────────────
@available(iOS 16.0, *)
struct DeviceDetailView: View {
    let device: NetworkDevice
    private var col: Color { NWTheme.riskColor(device.highestRisk) }

    var body: some View {
        ZStack {
            NWTheme.ink.ignoresSafeArea()
            ScanlineView().ignoresSafeArea().allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    deviceHeader
                    suspiciousSection
                    openPortsSection
                    metaSection
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 2)
            }
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var deviceHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(col.opacity(0.12)).frame(width: 64, height: 64)
                    .overlay(Circle().strokeBorder(col.opacity(0.4), lineWidth: 1.5))
                Text(device.tacticalIcon)
                    .font(NWTheme.monoFont(size: 28, weight: .bold))
                    .foregroundColor(col)
            }
            .shadow(color: col.opacity(0.5), radius: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.ipAddress)
                    .font(NWTheme.monoFont(size: 20, weight: .bold))
                    .foregroundColor(NWTheme.t1)
                if let h = device.hostname {
                    Text(h).font(NWTheme.monoFont(size: 11)).foregroundColor(NWTheme.t2)
                }
                HStack(spacing: 6) {
                    Image(systemName: device.highestRisk.icon)
                    Text(device.highestRisk.rawValue)
                }
                .font(NWTheme.monoFont(size: 10, weight: .bold))
                .foregroundColor(col)
                .tracking(1)
            }
            Spacer()
        }
        .padding(16)
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: col, size: 12))
    }

    private var suspiciousSection: some View {
        Group {
            if !device.suspiciousPorts.isEmpty {
                VStack(spacing: 0) {
                    PanelHeader(tag: "SUSPICIOUS PORTS [\(device.suspiciousPorts.count)]",
                                sub: device.highestRisk.rawValue)
                    VStack(spacing: 4) {
                        ForEach(device.suspiciousPorts, id: \.port) { p in
                            PortDetailRow(port: p)
                        }
                    }
                    .padding(10)
                }
                .background(NWTheme.panel)
                .overlay(CornerBrackets(color: NWTheme.riskColor(device.highestRisk), size: 10))
            }
        }
    }

    private var openPortsSection: some View {
        VStack(spacing: 0) {
            PanelHeader(tag: "OPEN PORTS [\(device.openPorts.count)]", sub: "")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(device.openPorts, id: \.self) { p in
                    let susp = SuspiciousPort.lookup(p)
                    let c = susp.map { NWTheme.riskColor($0.risk) } ?? NWTheme.glow.opacity(0.3)
                    VStack(spacing: 2) {
                        Text(":\(p)").font(NWTheme.monoFont(size: 12, weight: .bold)).foregroundColor(c)
                        Text(susp?.service ?? "TCP").font(NWTheme.monoFont(size: 8)).foregroundColor(NWTheme.t3)
                    }
                    .frame(maxWidth: .infinity).padding(8)
                    .background(c.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(c.opacity(0.25), lineWidth: 1))
                }
            }
            .padding(10)
        }
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
    }

    private var metaSection: some View {
        VStack(spacing: 0) {
            PanelHeader(tag: "DEVICE INTEL", sub: "")
            VStack(spacing: 0) {
                MetaRow(k: "IP ADDRESS", v: device.ipAddress)
                MetaRow(k: "HOSTNAME",   v: device.hostname ?? "UNKNOWN")
                MetaRow(k: "LAST OCTET", v: ".\(device.lastOctet)")
                MetaRow(k: "FIRST SEEN", v: formatted(device.firstSeen))
                MetaRow(k: "THIS DEVICE",v: device.isCurrentDevice ? "YES" : "NO")
            }
        }
        .background(NWTheme.panel)
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: d).uppercased()
    }
}

struct MetaRow: View {
    let k: String; let v: String
    var body: some View {
        HStack {
            Text(k).font(NWTheme.monoFont(size: 9)).foregroundColor(NWTheme.t3).tracking(1)
            Spacer()
            Text(v).font(NWTheme.monoFont(size: 11, weight: .medium)).foregroundColor(NWTheme.t1)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(NWTheme.wire), alignment: .bottom)
    }
}

struct PortDetailRow: View {
    let port: SuspiciousPort
    @State private var expanded = false
    private var col: Color { NWTheme.riskColor(port.risk) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { expanded.toggle() } } label: {
                HStack(spacing: 10) {
                    Text(":\(port.port)")
                        .font(NWTheme.monoFont(size: 14, weight: .bold))
                        .foregroundColor(col)
                        .frame(width: 56, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(port.service)
                            .font(NWTheme.monoFont(size: 11, weight: .semibold))
                            .foregroundColor(NWTheme.t1)
                        Text(port.risk.rawValue)
                            .font(NWTheme.monoFont(size: 8))
                            .foregroundColor(col)
                            .tracking(1)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(NWTheme.t3)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded {
                Text(port.reason)
                    .font(NWTheme.monoFont(size: 10))
                    .foregroundColor(NWTheme.t2)
                    .padding(.horizontal, 12).padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(col.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(col.opacity(0.25), lineWidth: 1))
    }
}
