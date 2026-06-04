import AppKit
import SwiftUI

struct MenuBarIcon: View {
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
            NSGraphicsContext.current?.shouldAntialias = true
            drawIcon(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawIcon(in rect: CGRect) {
        let s = rect.width / 18

        NSColor.black.setFill()
        NSColor.black.setStroke()

        // Rounded square outline
        let squareRect = CGRect(x: rect.minX + s, y: rect.minY + s, width: 16 * s, height: 16 * s)
        let roundedPath = NSBezierPath(roundedRect: squareRect, xRadius: 3 * s, yRadius: 3 * s)
        roundedPath.lineWidth = 1.5 * s
        roundedPath.stroke()

        // Converts SVG coordinates (y-down, origin top-left) to AppKit (y-up)
        func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x * s, y: rect.minY + (18 - y) * s)
        }

        // Rounded "L" drawn as a stroked path
        let lPath = NSBezierPath()
        lPath.move(to: pt(6, 4.5))
        lPath.line(to: pt(6, 13.5))
        lPath.line(to: pt(12, 13.5))
        lPath.lineWidth = 2 * s
        lPath.lineCapStyle = .round
        lPath.lineJoinStyle = .round
        lPath.stroke()
    }
}
