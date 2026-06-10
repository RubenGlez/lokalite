import AppKit
import SwiftUI
import LokaliteCore
import SymbolPicker

// MARK: - Identifiable

extension Secret: Identifiable {}
extension Project: Identifiable {}
extension VaultEnvironment: Identifiable {}

// MARK: - Theme

enum Theme {
    static let controlHeight: CGFloat = 30
    static let rowHeight: CGFloat = 44
    static let tableHeaderHeight: CGFloat = 36
    static let brand      = dynamic(light: (0.133, 0.545, 0.235), dark: (0.349, 0.722, 0.369))
    static let brandSubtle = brand.opacity(0.12)
    static let neutralSubtle = neutral(0.06)
    static let sep        = dynamic(light: (0.871, 0.886, 0.902), dark: (0.102, 0.129, 0.157))
    static let windowBackground = dynamic(light: (0.973, 0.976, 0.980), dark: (0.039, 0.055, 0.075))
    static let sidebarBackground = dynamic(light: (0.925, 0.933, 0.945), dark: (0.075, 0.094, 0.114))
    static let panelBackground = sidebarBackground
    static let text       = dynamic(light: (0.110, 0.122, 0.137), dark: (0.961, 0.961, 0.961))
    static let textMuted  = dynamic(light: (0.392, 0.420, 0.451), dark: (0.627, 0.627, 0.627))
    static let textDim    = dynamic(light: (0.557, 0.580, 0.604), dark: (0.420, 0.420, 0.420))
    static let bgHigh     = neutral(0.055)
    static let red        = dynamic(light: (0.788, 0.208, 0.165), dark: (1.000, 0.482, 0.447))
    static let green      = brand
    static let blue       = dynamic(light: (0.067, 0.408, 0.745), dark: (0.427, 0.686, 0.945))
    static let mint       = dynamic(light: (0.063, 0.522, 0.467), dark: (0.384, 0.824, 0.765))
    static let violet     = dynamic(light: (0.408, 0.310, 0.788), dark: (0.608, 0.529, 0.945))
    static let pink       = dynamic(light: (0.753, 0.224, 0.420), dark: (0.929, 0.522, 0.690))
    static let orange     = dynamic(light: (0.702, 0.522, 0.055), dark: (0.949, 0.800, 0.376))
    static let amber      = dynamic(light: (0.749, 0.420, 0.110), dark: (0.925, 0.635, 0.365))
    static let slate      = dynamic(light: (0.373, 0.435, 0.494), dark: (0.565, 0.624, 0.690))

    /// Contrast color for glyphs drawn on top of the accent colors above
    /// (light-mode accents are dark, dark-mode accents are pastel).
    static let onAccent   = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor.black.withAlphaComponent(0.72)
            : NSColor.white.withAlphaComponent(0.92)
    })

    /// Neutral overlay: white-based in dark mode, black-based in light mode.
    static func neutral(_ opacity: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            (appearance.isDark ? NSColor.white : NSColor.black).withAlphaComponent(opacity)
        })
    }

    private static func dynamic(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.isDark ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    static let environmentPalette = ["#6DAFF1", "#F2CC60", "#FF7B72", "#9B87F1", "#ED85B0", "#ECB15D", "#62D2C3", "#909FAF"]

    static func envCircle(_ color: Color) -> Image {
        let size: CGFloat = 8
        let nsImage = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor(color).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        nsImage.isTemplate = false
        return Image(nsImage: nsImage)
    }

    static func color(hex: String?) -> Color {
        guard let hex else { return brand }
        switch hex {
        case "#6DAFF1", "#8FD3FF": return blue
        case "#F2CC60": return orange
        case "#FF7B72": return red
        case "#9B87F1": return violet
        case "#ED85B0": return pink
        case "#ECB15D": return amber
        case "#62D2C3": return mint
        case "#909FAF": return slate
        case "#A0A0A0": return textMuted
        default: return brand
        }
    }
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}


// MARK: - Shared control helpers

struct BorderedActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(height: Theme.controlHeight)
                .padding(.horizontal, 10)
                .background(Theme.bgHigh, in: .rect(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.sep, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func toolbarSearch(text: Binding<String>, isPresented: Binding<Bool>) -> some View {
        searchable(
            text: text,
            isPresented: isPresented,
            placement: .toolbar,
            prompt: "Filter secrets"
        )
    }

    @ViewBuilder
    func optionallyFocused(_ binding: FocusState<Bool>.Binding?) -> some View {
        if let binding { focused(binding) } else { self }
    }
}

func shortPath(_ path: String?) -> String? {
    guard let path, !path.isEmpty else { return nil }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return path.replacingOccurrences(of: home, with: "~")
}

@MainActor
func withCopyFeedback(_ copied: Binding<Bool>, action: () -> Void) {
    action()
    withAnimation { copied.wrappedValue = true }
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(1.4))
        withAnimation { copied.wrappedValue = false }
    }
}

func isCLIInstalled() -> Bool {
    let paths = ["/usr/local/bin/lokalite", "/opt/homebrew/bin/lokalite", "/usr/bin/lokalite"]
    return paths.contains { FileManager.default.fileExists(atPath: $0) }
}

