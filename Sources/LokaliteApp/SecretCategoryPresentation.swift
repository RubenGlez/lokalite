import SwiftUI
import LokaliteCore

extension SecretCategory {
    var systemImage: String {
        switch self {
        case .token: return "ticket"
        case .apiKey: return "key"
        case .password: return "lock"
        case .secret: return "text.badge.key"
        case .certificate: return "checkmark.seal"
        case .database: return "cylinder.split.1x2"
        case .webhook: return "point.3.connected.trianglepath.dotted"
        case .other: return "note.text"
        }
    }

    /// Semantic accent for the category, drawn from the shared Theme palette.
    /// Color here is information: it lets a list of secrets be scanned by type
    /// at a glance. Brand green and red are reserved (active/linked, destructive).
    var color: Color {
        switch self {
        case .token: return Theme.violet
        case .apiKey: return Theme.blue
        case .password: return Theme.amber
        case .secret: return Theme.pink
        case .certificate: return Theme.mint
        case .database: return Theme.orange
        case .webhook: return Theme.slate
        case .other: return Theme.textMuted
        }
    }
}

/// Rounded tile holding a category's SF Symbol in its semantic color.
/// The single source of truth for how a secret's type is shown across the app.
struct CategoryIconTile: View {
    let category: SecretCategory
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(category.color.opacity(0.16))
            Image(systemName: category.systemImage)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(category.color)
        }
        .frame(width: size, height: size)
    }
}
