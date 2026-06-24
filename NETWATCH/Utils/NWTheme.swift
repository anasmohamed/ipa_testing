// NETWATCH — NWTheme.swift
// Exact colour tokens ported from the web simulation's CSS variables.
// Phosphor-teal on deep navy-black — cyberpunk war-room aesthetic.

import SwiftUI

enum NWTheme {

    // ── Base ──────────────────────────────────────────────
    static let ink      = Color(hex: "#030508")   // page background
    static let panel    = Color(hex: "#060D14")   // panel fill
    static let panel2   = Color(hex: "#09141F")   // panel header / elevated
    static let wire     = Color(hex: "#0A1E2E")   // border / gap colour
    static let gridCol  = Color(hex: "#0D2236")   // subtle grid lines

    // ── Signature accent — phosphor teal ──────────────────
    static let glow     = Color(hex: "#00FFD4")
    static let glow2    = Color(hex: "#00C4A4")
    static let glowDim  = Color(hex: "#00FFD4").opacity(0.08)

    // ── Risk palette ──────────────────────────────────────
    static let critical = Color(hex: "#FF2244")
    static let high     = Color(hex: "#FF6B00")
    static let medium   = Color(hex: "#FFE000")
    static let safe     = Color(hex: "#00FFD4")   // reuse glow for clean

    // ── Text hierarchy ────────────────────────────────────
    static let t1 = Color(hex: "#C8E8E0")   // primary
    static let t2 = Color(hex: "#5A8A7E")   // secondary
    static let t3 = Color(hex: "#2A4840")   // muted / labels

    // ── Typography ────────────────────────────────────────
    // Display / headings  → rounded system (closest to Orbitron on iOS)
    // Data / mono readouts → monospaced system (closest to Share Tech Mono)
    static func displayFont(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // ── Risk helpers ──────────────────────────────────────
    static func riskColor(_ r: RiskLevel) -> Color {
        switch r {
        case .critical: return critical
        case .high:     return high
        case .medium:   return medium
        case .clean:    return safe
        }
    }

    static func riskGlow(_ r: RiskLevel) -> Color { riskColor(r).opacity(0.25) }
}

// ── Color from hex ────────────────────────────────────────
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >>  8) & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// ── Shared view modifiers ─────────────────────────────────
extension View {

    /// Tactical panel card with corner brackets
    func nwPanel() -> some View {
        self
            .background(NWTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(NWTheme.wire, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Phosphor glow shadow
    func nwGlow(color: Color = NWTheme.glow, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.6), radius: radius)
    }

    /// CRT scanline overlay
    func scanlineOverlay() -> some View {
        self.overlay(ScanlineView().allowsHitTesting(false))
    }
}

// ── CRT Scanline view ─────────────────────────────────────
struct ScanlineView: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var y: CGFloat = offset
                while y < size.height {
                    ctx.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                        with: .color(NWTheme.glow.opacity(0.025))
                    )
                    y += 3
                }
            }
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    offset = -300
                }
            }
        }
    }
}

// ── Corner bracket decoration ──────────────────────────────
struct CornerBrackets: View {
    var color: Color = NWTheme.glow
    var size: CGFloat = 14
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                bracket(corner: .topLeft)
                bracket(corner: .topRight)
                bracket(corner: .bottomLeft)
                bracket(corner: .bottomRight)
            }
        }
    }

    private func bracket(corner: Corner) -> some View {
        Canvas { ctx, size in
            let s = self.size
            let lw = lineWidth
            var path = Path()
            switch corner {
            case .topLeft:
                path.move(to: CGPoint(x: s, y: 0))
                path.addLine(to: .zero)
                path.addLine(to: CGPoint(x: 0, y: s))
            case .topRight:
                path.move(to: CGPoint(x: size.width - s, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: s))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: size.height - s))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: s, y: size.height))
            case .bottomRight:
                path.move(to: CGPoint(x: size.width - s, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height - s))
            }
            ctx.stroke(path, with: .color(color.opacity(0.5)), lineWidth: lw)
        }
    }

    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
}
