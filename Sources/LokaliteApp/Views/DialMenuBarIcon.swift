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
            let cx = rect.width / 2
            let cy = rect.height / 2
            let outerR = min(cx, cy) - 1.25

            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Outer bezel ring
            let outerPath = NSBezierPath(ovalIn: CGRect(
                x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
            outerPath.lineWidth = 2.0
            outerPath.stroke()

            // 12 tick marks
            for i in 0..<12 {
                let angle = Double(i) * (.pi * 2 / 12) - .pi / 2
                let major = i % 3 == 0
                let r1 = outerR - 1.0
                let r2 = r1 - (major ? 4.0 : 2.5)
                let tick = NSBezierPath()
                tick.move(to: CGPoint(x: cx + r1 * cos(angle), y: cy + r1 * sin(angle)))
                tick.line(to: CGPoint(x: cx + r2 * cos(angle), y: cy + r2 * sin(angle)))
                tick.lineWidth = major ? 1.5 : 1.1
                tick.stroke()
            }

            // Inner dial ring
            let dialR = outerR * 0.46
            let dialPath = NSBezierPath(ovalIn: CGRect(
                x: cx - dialR, y: cy - dialR, width: dialR * 2, height: dialR * 2))
            dialPath.lineWidth = 1.5
            dialPath.stroke()

            // Centre dot
            let dotR: CGFloat = 2.25
            NSBezierPath(ovalIn: CGRect(
                x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)).fill()

            return true
        }
        image.isTemplate = true
        return image
    }
}
