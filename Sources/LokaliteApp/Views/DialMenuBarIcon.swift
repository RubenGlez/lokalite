import AppKit
import SwiftUI

struct DialMenuBarIcon: View {
    var body: some View {
        Image(nsImage: Self.templateImage())
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(.primary)
    }

    static func templateImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawArmadillo(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    // Armadillo side profile: domed shell, integrated ear spike, pointed snout, leg bumps.
    // SVG source: viewBox 0 0 18 16 (square-ish to fill the 18pt menu bar slot).
    private static func drawArmadillo(in rect: CGRect) {
        let svgW: CGFloat = 18
        let svgH: CGFloat = 16
        let scale = min(rect.width / svgW, rect.height / svgH) * 0.96
        let xOff = rect.minX + (rect.width  - svgW * scale) / 2
        let yOff = rect.minY + (rect.height - svgH * scale) / 2

        // SVG top-left / y-down → CG bottom-left / y-up
        func p(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
            CGPoint(x: xOff + px * scale,
                    y: rect.maxY - yOff - py * scale)
        }

        let path = NSBezierPath()
        path.move(to: p(0.5, 13.5))
        // Up the back
        path.curve(to: p(1.5, 8.5),  controlPoint1: p(0.5, 12),   controlPoint2: p(1, 10))
        path.curve(to: p(9, 1.5),    controlPoint1: p(3, 5),       controlPoint2: p(5.5, 2))
        // Up to ear base
        path.curve(to: p(14.5, 5),   controlPoint1: p(12, 1),      controlPoint2: p(14, 2.5))
        // Ear spike
        path.line(to: p(15.5, 2))
        path.line(to: p(17, 5))
        // Down into head/neck then snout
        path.curve(to: p(15.5, 10),  controlPoint1: p(17.5, 6.5),  controlPoint2: p(17, 9))
        path.curve(to: p(18, 11.5),  controlPoint1: p(16.5, 9.8),  controlPoint2: p(17.5, 10.5))
        path.curve(to: p(16.5, 12.5), controlPoint1: p(18.5, 12.5), controlPoint2: p(17.5, 13))
        // Back along underside
        path.curve(to: p(13.5, 12.5), controlPoint1: p(15.5, 12),  controlPoint2: p(14.5, 12.5))
        path.curve(to: p(10.5, 13),  controlPoint1: p(12.5, 13),   controlPoint2: p(11.5, 13.5))
        // Leg bumps
        path.curve(to: p(6, 14),     controlPoint1: p(8.5, 13),    controlPoint2: p(7, 14))
        path.curve(to: p(3.5, 13),   controlPoint1: p(5, 14),      controlPoint2: p(4, 13))
        path.curve(to: p(0.5, 14),   controlPoint1: p(2.5, 13.5),  controlPoint2: p(1.5, 14))
        path.curve(to: p(0.5, 13.5), controlPoint1: p(-0.2, 14),   controlPoint2: p(-0.2, 14))
        path.close()

        NSColor.black.setFill()
        path.fill()
    }
}
