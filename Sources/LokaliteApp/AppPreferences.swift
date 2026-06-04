import Foundation

final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var sessionTimeoutSeconds: Double {
        get {
            let value = defaults.double(forKey: "sessionTimeoutSeconds")
            return value > 0 ? value : 300
        }
        set {
            defaults.set(newValue, forKey: "sessionTimeoutSeconds")
        }
    }

    var clipboardClearSeconds: Double {
        get {
            let value = defaults.double(forKey: "clipboardClearSeconds")
            return value > 0 ? value : 30
        }
        set {
            defaults.set(newValue, forKey: "clipboardClearSeconds")
        }
    }

    var appearanceMode: String {
        get {
            defaults.string(forKey: "appearanceMode") ?? "system"
        }
        set {
            defaults.set(newValue, forKey: "appearanceMode")
        }
    }

    var hotkeyShortcutID: String {
        get {
            defaults.string(forKey: "hotkeyShortcutID") ?? "cmdShiftSpace"
        }
        set {
            defaults.set(newValue, forKey: "hotkeyShortcutID")
            NotificationCenter.default.post(name: .hotkeyShortcutChanged, object: newValue)
        }
    }

    var recentSecretNames: [String] {
        get {
            defaults.stringArray(forKey: "recentSecretNames") ?? []
        }
        set {
            defaults.set(newValue, forKey: "recentSecretNames")
        }
    }
}
