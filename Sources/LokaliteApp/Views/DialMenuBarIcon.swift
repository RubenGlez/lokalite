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
            drawTemplateIcon(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawTemplateIcon(in rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2 - 1.25

        NSColor.black.setStroke()
        NSColor.black.setFill()

        drawRing(center: center, radius: outerRadius, lineWidth: 2.0)
        drawTicks(center: center, radius: outerRadius)
        drawRing(center: center, radius: outerRadius * 0.46, lineWidth: 1.5)
        drawDot(center: center, radius: 2.25)
    }

    private static func drawRing(center: CGPoint, radius: CGFloat, lineWidth: CGFloat) {
        let diameter = radius * 2
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: diameter,
            height: diameter
        )
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func drawTicks(center: CGPoint, radius: CGFloat) {
        for index in 0..<12 {
            let angle = CGFloat(index) * (.pi * 2 / 12) - .pi / 2
            let isMajorTick = index % 3 == 0
            let outerTickRadius = radius - 1.0
            let innerTickRadius = outerTickRadius - (isMajorTick ? 4.0 : 2.5)
            let tick = NSBezierPath()

            tick.move(to: point(on: center, radius: outerTickRadius, angle: angle))
            tick.line(to: point(on: center, radius: innerTickRadius, angle: angle))
            tick.lineWidth = isMajorTick ? 1.5 : 1.1
            tick.stroke()
        }
    }

    private static func drawDot(center: CGPoint, radius: CGFloat) {
        let diameter = radius * 2
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: diameter,
            height: diameter
        )
        NSBezierPath(ovalIn: rect).fill()
    }

    private static func point(on center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}
