import SwiftUI

/// Simplified combination-dial icon for the menu bar.
/// Uses Canvas so it renders crisp at any display density.
struct DialMenuBarIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let outerR = min(cx, cy) - 1.0

            // Outer bezel ring
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR,
                                       width: outerR * 2, height: outerR * 2)),
                with: .foreground, lineWidth: 1.5
            )

            // 12 tick marks evenly spaced around the bezel
            for i in 0..<12 {
                let angle = Double(i) * (.pi * 2 / 12) - .pi / 2
                let major  = i % 3 == 0
                let r1 = outerR - 0.5
                let r2 = r1 - (major ? 3.5 : 2.0)
                var tick = Path()
                tick.move(to:    CGPoint(x: cx + r1 * cos(angle), y: cy + r1 * sin(angle)))
                tick.addLine(to: CGPoint(x: cx + r2 * cos(angle), y: cy + r2 * sin(angle)))
                ctx.stroke(tick, with: .foreground, lineWidth: major ? 1.2 : 0.8)
            }

            // Inner dial ring
            let dialR = outerR * 0.56
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - dialR, y: cy - dialR,
                                       width: dialR * 2, height: dialR * 2)),
                with: .foreground, lineWidth: 1.0
            )

            // Centre dot
            let dotR = 2.0
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR,
                                       width: dotR * 2, height: dotR * 2)),
                with: .foreground
            )
        }
        .frame(width: 18, height: 18)
    }
}
