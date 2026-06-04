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
    static let brand      = Color(red: 0.349, green: 0.722, blue: 0.369)
    static let brandSubtle = brand.opacity(0.12)
    static let neutralSubtle = Color.white.opacity(0.06)
    static let sep        = Color(red: 0.102, green: 0.129, blue: 0.157)
    static let windowBackground = Color(red: 0.039, green: 0.055, blue: 0.075)
    static let sidebarBackground = Color(red: 0.075, green: 0.094, blue: 0.114)
    static let panelBackground = sidebarBackground
    static let text       = Color(red: 0.961, green: 0.961, blue: 0.961)
    static let textMuted  = Color(red: 0.627, green: 0.627, blue: 0.627)
    static let textDim    = Color(red: 0.420, green: 0.420, blue: 0.420)
    static let bgHigh     = Color.white.opacity(0.055)
    static let red        = Color(red: 1.000, green: 0.482, blue: 0.447)
    static let green      = brand
    static let blue       = Color(red: 0.427, green: 0.686, blue: 0.945)
    static let mint       = Color(red: 0.384, green: 0.824, blue: 0.765)
    static let violet     = Color(red: 0.608, green: 0.529, blue: 0.945)
    static let pink       = Color(red: 0.929, green: 0.522, blue: 0.690)
    static let orange     = Color(red: 0.949, green: 0.800, blue: 0.376)
    static let amber      = Color(red: 0.925, green: 0.635, blue: 0.365)
    static let slate      = Color(red: 0.565, green: 0.624, blue: 0.690)

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

