// NETWATCH — HistoryView.swift
// Scan history log in war-room style.

import SwiftUI

@available(iOS 16.0, *)
struct HistoryView: View {
    @ObservedObject private var store = NWScanHistory.shared
    @State private var showClearConfirm = false

    var body: some View {
        ZStack {
            NWTheme.ink.ignoresSafeArea()
            ScanlineView().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Text("SCAN HISTORY")
                        .font(NWTheme.displayFont(size: 16))
                        .foregroundColor(NWTheme.glow)
                        .shadow(color: NWTheme.glow.opacity(0.6), radius: 6)
                        .tracking(3)
                    Spacer()
                    if !store.history.isEmpty {
                        Button("CLEAR") { showClearConfirm = true }
                            .font(NWTheme.monoFont(size: 10, weight: .bold))
                            .foregroundColor(NWTheme.critical)
                            .tracking(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(NWTheme.panel2)
                .overlay(
                    Rectangle().frame(height: 1).foregroundColor(NWTheme.glow)
                        .shadow(color: NWTheme.glow.opacity(0.4), radius: 4),
                    alignment: .bottom
                )
                .overlay(CornerBrackets(color: NWTheme.glow, size: 10))

                if store.history.isEmpty {
                    emptyState
                } else {
                    List(store.history) { result in
                        HistoryRow(result: result)
                            .listRowBackground(NWTheme.ink)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
                    }
                    .listStyle(.plain)
                    
                }
            }
        }
        .confirmationDialog("Clear all scan history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { store.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 44))
                .foregroundColor(NWTheme.t3)
            Text("NO SCAN HISTORY")
                .font(NWTheme.monoFont(size: 11))
                .foregroundColor(NWTheme.t3)
                .tracking(3)
            Text("Completed scans will appear here")
                .font(NWTheme.monoFont(size: 10))
                .foregroundColor(NWTheme.t3.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HistoryRow: View {
    let result: ScanResult

    private var statusColor: Color {
        result.criticalCount > 0 ? NWTheme.critical :
        result.threatCount  > 0 ? NWTheme.high     : NWTheme.glow
    }

    private var formatted: String {
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: result.date).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(statusColor.opacity(0.3), lineWidth: 1))
                Image(systemName: result.criticalCount > 0 ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                    .foregroundColor(statusColor)
                    .font(.system(size: 18))
            }
            .shadow(color: statusColor.opacity(0.3), radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(formatted)
                    .font(NWTheme.monoFont(size: 11, weight: .semibold))
                    .foregroundColor(NWTheme.t1)

                HStack(spacing: 10) {
                    statPill("\(result.devices.count) HOSTS", color: NWTheme.glow)
                    if result.threatCount > 0 {
                        statPill("\(result.threatCount) THREATS", color: NWTheme.high)
                    }
                    if result.criticalCount > 0 {
                        statPill("\(result.criticalCount) CRITICAL", color: NWTheme.critical)
                    }
                    if result.threatCount == 0 {
                        statPill("CLEAR", color: NWTheme.glow)
                    }
                }
            }

            Spacer()

            Text("\(result.openPortCount) PORTS")
                .font(NWTheme.monoFont(size: 8))
                .foregroundColor(NWTheme.t3)
                .tracking(1)
        }
        .padding(12)
        .background(NWTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(statusColor.opacity(0.15), lineWidth: 1))
        .overlay(CornerBrackets(color: statusColor, size: 8))
    }

    private func statPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(NWTheme.monoFont(size: 8, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
