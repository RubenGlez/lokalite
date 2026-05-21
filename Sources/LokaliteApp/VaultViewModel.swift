import AppKit
import SwiftUI
import LokaliteCore

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var secrets: [Secret] = []
    @Published var isLocked = true
    @Published var errorMessage: String?

    // Configurable timeouts stored in UserDefaults.
    var sessionTimeoutSeconds: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "sessionTimeoutSeconds")
            return v > 0 ? v : 300
        }
        set { UserDefaults.standard.set(newValue, forKey: "sessionTimeoutSeconds") }
    }

    var clipboardClearSeconds: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "clipboardClearSeconds")
            return v > 0 ? v : 30
        }
        set { UserDefaults.standard.set(newValue, forKey: "clipboardClearSeconds") }
    }

    private var lockTimer: Timer?

    // MARK: - Lock / Unlock

    func unlock() {
        Task.detached { [weak self] in
            do {
                try Vault.shared.unlock()
                await MainActor.run {
                    self?.isLocked = false
                    self?.refresh()
                    self?.startLockTimer()
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run { self?.errorMessage = msg }
            }
        }
    }

    func lock() {
        lockTimer?.invalidate()
        lockTimer = nil
        Vault.shared.lock()
        secrets = []
        isLocked = true
    }

    private func startLockTimer() {
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeoutSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.lock() }
        }
    }

    // MARK: - CRUD

    func refresh() {
        guard !isLocked else { return }
        do {
            secrets = try Vault.shared.list()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(name: String, value: String, description: String?, tags: [String]) {
        do {
            _ = try Vault.shared.add(name: name, value: value, description: description, tags: tags)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(name: String, value: String) {
        do {
            _ = try Vault.shared.set(name: name, value: value)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ secret: Secret) {
        do {
            try Vault.shared.delete(name: secret.name)
            secrets.removeAll { $0.id == secret.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ secret: Secret) {
        let value = secret.value
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)

        let delay = clipboardClearSeconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            if NSPasteboard.general.string(forType: .string) == value {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
