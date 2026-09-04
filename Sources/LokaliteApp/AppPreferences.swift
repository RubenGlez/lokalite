import Foundation

final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Session timeout before auto-lock. 0 means never — the vault stays
    /// unlocked while the app runs. The key's absence (fresh install) defaults
    /// to 300; a stored 0 is a real value, not the default.
    var sessionTimeoutSeconds: Double {
        get {
            guard defaults.object(forKey: "sessionTimeoutSeconds") != nil else { return 300 }
            return defaults.double(forKey: "sessionTimeoutSeconds")
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
