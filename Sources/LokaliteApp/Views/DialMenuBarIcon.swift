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
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2 - 0.5

        NSColor.black.setFill()
        NSColor.black.setStroke()

        // Outer ring with 8 rounded notches cut from the inner edge
        let outerR = R
        let innerR = R * 0.65
        let notchCount = 8
        let notchW = R * 0.18
        let notchLen = R * 0.30

        let ringPath = NSBezierPath()
        ringPath.windingRule = .evenOdd

        // Outer filled disk
        ringPath.appendOval(in: CGRect(x: c.x - outerR, y: c.y - outerR,
                                       width: outerR * 2, height: outerR * 2))

        // Inner hole of ring
        ringPath.appendOval(in: CGRect(x: c.x - innerR, y: c.y - innerR,
                                       width: innerR * 2, height: innerR * 2))

        // Notches: capsule shapes placed at inner edge, pointing radially inward
        for i in 0..<notchCount {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(notchCount))
            let notchCenterDist = innerR + notchLen * 0.30

            // Rotation: unrotated capsule points along +Y; rotate so it points in `angle` direction
            let cosR = cos(angle - .pi / 2)
            let sinR = sin(angle - .pi / 2)

            let unrotated = CGRect(x: -notchW / 2, y: -notchLen * 0.15,
                                   width: notchW, height: notchLen)
            let notchPath = NSBezierPath(roundedRect: unrotated,
                                         xRadius: notchW / 2, yRadius: notchW / 2)
            let xform = AffineTransform(
                m11: cosR, m12: sinR,
                m21: -sinR, m22: cosR,
                tX: c.x + notchCenterDist * cos(angle),
                tY: c.y + notchCenterDist * sin(angle)
            )
            notchPath.transform(using: xform)
            ringPath.append(notchPath)
        }

        ringPath.fill()

        // Inner concentric ring (stroke only, hollow center)
        let innerRingR = R * 0.36
        let innerRingPath = NSBezierPath(ovalIn: CGRect(
            x: c.x - innerRingR, y: c.y - innerRingR,
            width: innerRingR * 2, height: innerRingR * 2
        ))
        innerRingPath.lineWidth = R * 0.18
        innerRingPath.stroke()
    }
}
