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

    var defaultIcon: String {
        switch self {
        case .token: return "🎟️"
        case .apiKey: return "🔑"
        case .password: return "🔐"
        case .secret: return "🛡️"
        case .certificate: return "📜"
        case .database: return "🗄️"
        case .webhook: return "🔌"
        case .other: return "📝"
        }
    }
}
