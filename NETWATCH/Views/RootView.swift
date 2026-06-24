// NETWATCH — RootView.swift
// Root tab shell with cyberpunk command-bar header.

import SwiftUI

@available(iOS 16.0, *)
struct RootView: View {
    @StateObject private var scanner = NWScanner()
    @State private var selectedTab   = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            NWTheme.ink.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                ConsoleView(scanner: scanner)
                    .tag(0)
                DeviceListView(scanner: scanner)
                    .tag(1)
                HeatmapView(scanner: scanner)
                    .tag(2)
                HistoryView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.none, value: selectedTab)

            // Custom tactical tab bar
            TacticalTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear { Task { await NWNotifications.shared.requestPermission() } }
    }
}

// ── Tactical Tab Bar ──────────────────────────────────────
struct TacticalTabBar: View {
    @Binding var selected: Int

    private let tabs: [(icon: String, label: String)] = [
        ("scope",               "CONSOLE"),
        ("list.bullet.indent",  "DEVICES"),
        ("square.grid.3x3.fill","HEATMAP"),
        ("clock.fill",          "HISTORY"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button { selected = i } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[i].icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(tabs[i].label)
                            .font(NWTheme.monoFont(size: 8, weight: .bold))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selected == i ? NWTheme.glow : NWTheme.t3)
                }
                .overlay(alignment: .top) {
                    if selected == i {
                        Rectangle()
                            .fill(NWTheme.glow)
                            .frame(height: 1)
                            .shadow(color: NWTheme.glow.opacity(0.8), radius: 4)
                    }
                }
            }
        }
        .background(NWTheme.panel.overlay(
            Rectangle().frame(height: 1).foregroundColor(NWTheme.wire), alignment: .top
        ))
        .overlay(CornerBrackets(color: NWTheme.glow, size: 10))
    }
}
