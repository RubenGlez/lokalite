import SwiftUI

// MARK: - Interaction system
//
// Every custom control goes through one of these styles so states read the same
// everywhere: rest → hover → pressed, plus selected/on and disabled.
//
// Visual language follows the logo: dark armored "plates" (neutral surfaces with
// hairline borders) and a green glow reserved for what is primary, selected, or
// on. Hover lifts a plate slightly; press sinks it; disabled fades it.

extension Theme {
    // Subtle on purpose: hover is a hint, not a highlight.
    static let restFill     = neutral(0.045)
    static let hoverFill    = neutral(0.06)
    static let pressedFill  = neutral(0.11)
    static let selectedFill = neutral(0.09)
    static let borderStrong = neutral(0.22)
    static let disabledOpacity = 0.4
    /// The logo's eye: a soft brand glow for selected/primary emphasis.
    static let glow = brand.opacity(0.45)
}

/// Hover tracking shared by the styles (ButtonStyle can't hold state itself).
private struct InteractiveBody<Content: View>: View {
    let content: (_ isHovered: Bool, _ isEnabled: Bool) -> Content
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        content(isHovered && isEnabled, isEnabled)
            .opacity(isEnabled ? 1 : Theme.disabledOpacity)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
            }
    }
}

// MARK: Surface (bordered) buttons

/// Bordered "plate" button: the default for actions in toolbars and panels.
struct SurfaceButtonStyle: ButtonStyle {
    enum Kind { case secondary, primary, destructive, ghost }

    var kind: Kind = .secondary
    var height: CGFloat? = Theme.controlHeight
    var horizontalPadding: CGFloat = 10
    var cornerRadius: CGFloat = 7
    /// Toggle-style "on" state (e.g. a panel that's showing).
    var isOn: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        InteractiveBody { hovered, enabled in
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(foreground)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .background(fill(hovered: hovered, pressed: configuration.isPressed && enabled),
                            in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(border(hovered: hovered), lineWidth: 1)
                )
                .shadow(color: kind == .primary && hovered ? Theme.glow : .clear, radius: 8)
                .contentShape(.rect(cornerRadius: cornerRadius))
                .scaleEffect(configuration.isPressed && enabled ? 0.98 : 1)
        }
        .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.onAccent
        case .destructive: return Theme.red
        case .secondary, .ghost: return isOn ? Theme.brand : Theme.text
        }
    }

    private func fill(hovered: Bool, pressed: Bool) -> Color {
        switch kind {
        case .primary:
            return Theme.brand.opacity(pressed ? 0.78 : hovered ? 0.92 : 1)
        case .destructive:
            return Theme.red.opacity(pressed ? 0.22 : hovered ? 0.16 : 0.10)
        case .secondary:
            if pressed { return Theme.pressedFill }
            if isOn { return Theme.brand.opacity(0.14) }
            return hovered ? Theme.neutral(0.08) : Theme.bgHigh
        case .ghost:
            if pressed { return Theme.pressedFill }
            if isOn { return Theme.selectedFill }
            return hovered ? Theme.hoverFill : .clear
        }
    }

    private func border(hovered: Bool) -> Color {
        switch kind {
        case .primary: return .clear
        case .destructive: return Theme.red.opacity(hovered ? 0.45 : 0.25)
        case .ghost: return .clear
        case .secondary:
            if isOn { return Theme.brand.opacity(0.5) }
            return hovered ? Theme.borderStrong : Theme.sep
        }
    }
}

// MARK: Icon buttons

/// Borderless square icon button. `isOn` tints it brand (the "glowing" state).
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 6
    var isOn: Bool = false
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        InteractiveBody { hovered, enabled in
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn ? Theme.brand : (tint ?? (hovered ? Theme.text : Theme.textMuted)))
                .frame(width: size, height: size)
                .background(
                    configuration.isPressed && enabled ? Theme.pressedFill
                        : isOn ? Theme.selectedFill
                        : hovered ? Theme.hoverFill : .clear,
                    in: .rect(cornerRadius: cornerRadius)
                )
                .contentShape(.rect(cornerRadius: cornerRadius))
        }
    }
}

// MARK: Rows

/// Full-width list row (sidebar projects, footer items, tool rows, menu-like
/// panel rows). Selected rows get the brand glow bar on the leading edge.
struct RowButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var cornerRadius: CGFloat = 7
    var showsSelectionBar: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        InteractiveBody { hovered, enabled in
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    configuration.isPressed && enabled ? Theme.pressedFill
                        : isSelected ? Theme.selectedFill
                        : hovered ? Theme.hoverFill : .clear,
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(alignment: .leading) {
                    if isSelected && showsSelectionBar {
                        SelectionGlowBar()
                    }
                }
                .contentShape(.rect(cornerRadius: cornerRadius))
        }
    }
}

/// The logo's glowing eye, as a selection marker.
struct SelectionGlowBar: View {
    var body: some View {
        Capsule()
            .fill(Theme.brand)
            .frame(width: 3, height: 16)
            .shadow(color: Theme.glow, radius: 4)
            .padding(.leading, 2)
    }
}

/// Press-only feedback for content that draws its own hover/selection
/// background (e.g. the popover rows, whose container tracks hover).
struct PressFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: Chips

/// Capsule chip (environment switcher). Selection is neutral; color belongs to
/// the chip's own dot.
struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var height: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        InteractiveBody { hovered, enabled in
            configuration.label
                .frame(height: height)
                .background(
                    configuration.isPressed && enabled ? Theme.pressedFill
                        : isSelected ? Theme.neutral(0.11)
                        : hovered ? Theme.hoverFill : Theme.restFill,
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Theme.neutral(0.28) : hovered ? Theme.borderStrong : Theme.sep,
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
        }
    }
}

// MARK: Text links

/// Inline text action. `.muted` brightens to text color on hover; `.brand` and
/// `.danger` keep their color and dim on press.
struct LinkButtonStyle: ButtonStyle {
    enum Tone { case muted, brand, danger }
    var tone: Tone = .brand

    func makeBody(configuration: Configuration) -> some View {
        InteractiveBody { hovered, enabled in
            configuration.label
                .foregroundStyle(color(hovered: hovered))
                .opacity(configuration.isPressed && enabled ? 0.6 : 1)
                .underline(hovered && tone != .muted)
                .contentShape(.rect)
        }
    }

    private func color(hovered: Bool) -> Color {
        switch tone {
        case .muted: return hovered ? Theme.text : Theme.textMuted
        case .brand: return Theme.brand
        case .danger: return Theme.red
        }
    }
}

// MARK: Swatches

/// Color swatch: hover rings it, selection rings it in the text color.
struct SwatchButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        InteractiveBody { hovered, _ in
            configuration.label
                .padding(2)
                .overlay(
                    Circle().stroke(
                        isSelected ? Theme.text.opacity(0.8) : hovered ? Theme.borderStrong : .clear,
                        lineWidth: 1.5
                    )
                )
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .contentShape(Circle())
        }
    }
}

// MARK: - Logo

/// The armadillo mark. Used where the app introduces itself (lock, first run),
/// not as decoration on working screens.
struct LokaliteLogo: View {
    var size: CGFloat = 96
    /// Soft green halo, echoing the eye; on for hero placements.
    var glows: Bool = true

    var body: some View {
        Image(nsImage: Self.image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            // Transparent artwork: no tile. A faint halo echoes the green rim and eye.
            .shadow(color: glows ? Theme.glow.opacity(0.35) : .clear, radius: size * 0.12)
            .accessibilityLabel("Lokalite")
    }

    private static let image: NSImage = {
        guard let url = Bundle.module.url(forResource: "Logo", withExtension: "png"),  // assets/logo.png at 384px
              let image = NSImage(contentsOf: url) else {
            return NSApp.applicationIconImage ?? NSImage()
        }
        return image
    }()
}
