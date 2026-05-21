import SwiftUI
import LokaliteCore

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var secrets: [Secret] = []
    @Published var isLocked = true
    @Published var errorMessage: String?

    func unlock() {
        do {
            try Vault.shared.unlock()
            isLocked = false
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func lock() {
        Vault.shared.lock()
        secrets = []
        isLocked = true
    }

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

    func copyToClipboard(_ secret: Secret) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(secret.value, forType: .string)
    }
}
