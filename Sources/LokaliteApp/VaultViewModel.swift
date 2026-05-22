import AppKit
import LocalAuthentication
import ServiceManagement
import SwiftUI
import LokaliteCore

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var secrets: [Secret] = []
    @Published var projects: [Project] = []
    @Published var activeProject: Project?
    @Published var isLocked = true
    @Published var errorMessage: String?

    var sessionTimeoutSeconds: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "sessionTimeoutSeconds")
            return v > 0 ? v : 300
        }
        set { UserDefaults.standard.set(newValue, forKey: "sessionTimeoutSeconds") }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
        Task { [weak self] in
            let context = LAContext()
            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
                self?.performUnlock()
                return
            }
            do {
                try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                 localizedReason: "Unlock Lokalite vault")
                self?.performUnlock()
            } catch {
                let code = (error as NSError).code
                if code != LAError.userCancel.rawValue && code != LAError.systemCancel.rawValue {
                    self?.errorMessage = error.localizedDescription
                }
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

    @MainActor
    private func performUnlock() {
        do {
            try Vault.shared.unlock()
            isLocked = false
            refresh()
            startLockTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
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
            projects = try Vault.shared.listProjects()
            if let activeId = try Vault.shared.activeProjectId() {
                activeProject = projects.first { $0.id == activeId }
            } else {
                activeProject = projects.first
            }
            if let project = activeProject {
                secrets = try Vault.shared.list(projectId: project.id,
                                                environmentName: project.activeEnvironment)
            } else {
                secrets = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(name: String, value: String, description: String?) {
        guard let project = activeProject else { return }
        do {
            _ = try Vault.shared.add(name: name, value: value, description: description,
                                     projectId: project.id,
                                     environmentName: project.activeEnvironment)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(name: String, value: String) {
        guard let project = activeProject else { return }
        do {
            _ = try Vault.shared.set(name: name, value: value, projectId: project.id,
                                     environmentName: project.activeEnvironment)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ secret: Secret) {
        guard let project = activeProject else { return }
        do {
            try Vault.shared.delete(name: secret.name, projectId: project.id)
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
