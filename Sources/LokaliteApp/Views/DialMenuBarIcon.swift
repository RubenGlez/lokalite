import SwiftUI

struct DialMenuBarIcon: View {
    var body: some View {
        Canvas(renderer: render)
            .frame(width: 18, height: 18)
    }

    private func render(ctx: inout GraphicsContext, size: CGSize) {
        let cx: Double = size.width / 2
        let cy: Double = size.height / 2
        let outerR: Double = min(cx, cy) - 1.0

        drawOuterRing(ctx: &ctx, cx: cx, cy: cy, r: outerR)
        drawTicks(ctx: &ctx, cx: cx, cy: cy, r: outerR)
        drawDialRing(ctx: &ctx, cx: cx, cy: cy, r: outerR * 0.56)
        drawCenterDot(ctx: &ctx, cx: cx, cy: cy)
    }

    private func drawOuterRing(ctx: inout GraphicsContext, cx: Double, cy: Double, r: Double) {
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
            with: .foreground,
            lineWidth: 1.5
        )
    }

    private func drawTicks(ctx: inout GraphicsContext, cx: Double, cy: Double, r: Double) {
        for i in 0..<12 {
            let angle: Double = Double(i) * (.pi * 2 / 12) - .pi / 2
            let major: Bool = i % 3 == 0
            let r1: Double = r - 0.5
            let r2: Double = r1 - (major ? 3.5 : 2.0)
            var tick = Path()
            tick.move(to:    CGPoint(x: cx + r1 * cos(angle), y: cy + r1 * sin(angle)))
            tick.addLine(to: CGPoint(x: cx + r2 * cos(angle), y: cy + r2 * sin(angle)))
            ctx.stroke(tick, with: .foreground, lineWidth: major ? 1.2 : 0.8)
        }
    }

    private func drawDialRing(ctx: inout GraphicsContext, cx: Double, cy: Double, r: Double) {
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
            with: .foreground,
            lineWidth: 1.0
        )
    }

    private func drawCenterDot(ctx: inout GraphicsContext, cx: Double, cy: Double) {
        let dotR: Double = 2.0
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)),
            with: .foreground
        )
    }
}
