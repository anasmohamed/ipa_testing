// NETWATCH — RadarView.swift
// Phosphor-teal rotating radar sweep with glowing risk-colored device nodes.
// Drawn with SwiftUI Canvas — no UIKit required.

import SwiftUI

struct RadarView: View {
    let devices:    [NetworkDevice]
    let isScanning: Bool

    @State private var angle:     Double = 0
    @State private var blink:     Bool   = false

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r  = min(cx, cy) - 10

            drawBackground(ctx: ctx, cx: cx, cy: cy, r: r, size: size)
            if isScanning { drawSweep(ctx: ctx, cx: cx, cy: cy, r: r) }
            drawNodes(ctx: ctx, cx: cx, cy: cy, r: r)
            drawCentre(ctx: ctx, cx: cx, cy: cy)
        }
        .onAppear  { if isScanning { startAnim() } }
        .onChange(of: isScanning) { active in
            if active { startAnim() } else { stopAnim() }
        }
    }

    // ── Background: rings + crosshair ─────────────────────
    private func drawBackground(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, size: CGSize) {
        // Range rings
        for fraction in [0.25, 0.5, 0.75, 1.0] as [CGFloat] {
            var ring = Path()
            ring.addEllipse(in: CGRect(x: cx - r*fraction, y: cy - r*fraction,
                                       width: r*fraction*2, height: r*fraction*2))
            ctx.stroke(ring, with: .color(NWTheme.glow.opacity(0.06 + fraction*0.04)), lineWidth: 1)
        }

        // Range labels
        for (i, fraction) in [0.25, 0.5, 0.75, 1.0].enumerated() {
            let label = "\((i+1)*64)"
            ctx.draw(
                Text(label).font(NWTheme.monoFont(size: 7)).foregroundColor(NWTheme.glow.opacity(0.25)),
                at: CGPoint(x: cx + r * fraction - 6, y: cy - 4)
            )
        }

        // Crosshair (8 spokes at 45° intervals)
        for spoke in 0..<8 {
            let a = Double(spoke) * .pi / 4
            var line = Path()
            line.move(to: CGPoint(x: cx, y: cy))
            line.addLine(to: CGPoint(x: cx + r * cos(a), y: cy + r * sin(a)))
            ctx.stroke(line, with: .color(NWTheme.glow.opacity(0.05)), lineWidth: 0.5)
        }
    }

    // ── Rotating sweep cone ────────────────────────────────
    private func drawSweep(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        let a = angle * .pi / 180

        // Cone fill
        var cone = Path()
        cone.move(to: CGPoint(x: cx, y: cy))
        cone.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                    startAngle: .radians(a - 0.5), endAngle: .radians(a), clockwise: false)
        cone.closeSubpath()
        ctx.fill(cone, with: .color(NWTheme.glow.opacity(0.12)))

        // Sweep edge line
        var line = Path()
        line.move(to: CGPoint(x: cx, y: cy))
        line.addLine(to: CGPoint(x: cx + r * cos(a), y: cy + r * sin(a)))
        ctx.stroke(line, with: .color(NWTheme.glow.opacity(0.9)), style: StrokeStyle(lineWidth: 1.5))

        // Glow trailing arc
        var arc = Path()
        arc.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                   startAngle: .radians(a - 0.6), endAngle: .radians(a), clockwise: false)
        ctx.stroke(arc, with: .color(NWTheme.glow.opacity(0.04)), lineWidth: r)
    }

    // ── Device nodes ──────────────────────────────────────
    private func drawNodes(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        let count = devices.count
        guard count > 0 else { return }

        for (i, device) in devices.enumerated() {
            let nodeAngle = Double(i) / Double(count) * .pi * 2 - .pi / 2
            let dist: CGFloat = 40 + CGFloat(i % 3) * 24
            let nx = cx + dist * cos(nodeAngle)
            let ny = cy + dist * sin(nodeAngle)
            let col = NWTheme.riskColor(device.highestRisk)

            // Glow halo
            let halo = Path(ellipseIn: CGRect(x: nx-14, y: ny-14, width: 28, height: 28))
            ctx.fill(halo, with: .color(col.opacity(0.15)))

            // Ring
            let ring = Path(ellipseIn: CGRect(x: nx-8, y: ny-8, width: 16, height: 16))
            ctx.stroke(ring, with: .color(col.opacity(0.8)), lineWidth: 1.5)

            // Core dot
            let dot = Path(ellipseIn: CGRect(x: nx-3, y: ny-3, width: 6, height: 6))
            ctx.fill(dot, with: .color(col))

            // Tactical icon
            ctx.draw(
                Text(device.tacticalIcon)
                    .font(NWTheme.monoFont(size: 8, weight: .bold))
                    .foregroundColor(col),
                at: CGPoint(x: nx, y: ny + 16)
            )

            // Last octet
            ctx.draw(
                Text(".\(device.lastOctet)")
                    .font(NWTheme.monoFont(size: 7))
                    .foregroundColor(NWTheme.glow.opacity(0.4)),
                at: CGPoint(x: nx, y: ny + 26)
            )
        }
    }

    // ── Centre ────────────────────────────────────────────
    private func drawCentre(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        // Glow
        let glow = Path(ellipseIn: CGRect(x: cx-12, y: cy-12, width: 24, height: 24))
        ctx.fill(glow, with: .color(NWTheme.glow.opacity(0.15)))
        // Dot
        let dot = Path(ellipseIn: CGRect(x: cx-4, y: cy-4, width: 8, height: 8))
        ctx.fill(dot, with: .color(NWTheme.glow))
        // Label
        ctx.draw(
            Text("YOU")
                .font(NWTheme.monoFont(size: 7, weight: .bold))
                .foregroundColor(NWTheme.glow.opacity(0.5)),
            at: CGPoint(x: cx, y: cy + 14)
        )
    }

    // ── Animation ─────────────────────────────────────────
    private func startAnim() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }

    private func stopAnim() {
        withAnimation(.linear(duration: 0.1)) { angle = 0 }
    }
}
