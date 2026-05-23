import AppKit
import LocalAuthentication
import ServiceManagement
import SwiftUI
import LokaliteCore

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var environments: [VaultEnvironment] = []
    @Published var selectedEnvironment: VaultEnvironment?  // nil = default values
    @Published var secrets: [Secret] = []
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
        environments = []
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

    // MARK: - Selection

    func selectProject(_ project: Project?) {
        selectedProject = project
        selectedEnvironment = nil
        reloadEnvironments()
        reloadSecrets()
    }

    func selectEnvironment(_ env: VaultEnvironment?) {
        selectedEnvironment = env
        reloadSecrets()
    }

    // MARK: - Data loading

    func refresh() {
        guard !isLocked else { return }
        do {
            projects = try Vault.shared.listProjects()
            if selectedProject == nil || !projects.contains(where: { $0.id == selectedProject?.id }) {
                if let activeId = try Vault.shared.activeProjectId() {
                    selectedProject = projects.first { $0.id == activeId }
                } else {
                    selectedProject = projects.first
                }
                selectedEnvironment = nil
            }
            reloadEnvironments()
            reloadSecrets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadEnvironments() {
        guard let project = selectedProject else { environments = []; return }
        do {
            environments = try Vault.shared.listEnvironments(projectId: project.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadSecrets() {
        guard let project = selectedProject else { secrets = []; return }
        do {
            secrets = try Vault.shared.list(projectId: project.id,
                                            environmentName: selectedEnvironment?.name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Project CRUD

    func addProject(name: String) {
        do {
            let project = try Vault.shared.addProject(name: name)
            projects.append(project)
            selectProject(project)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProject(_ project: Project) {
        do {
            try Vault.shared.deleteProject(id: project.id)
            projects.removeAll { $0.id == project.id }
            if selectedProject?.id == project.id {
                selectProject(projects.first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Environment CRUD

    func addEnvironment(name: String) {
        guard let project = selectedProject else { return }
        do {
            let env = try Vault.shared.addEnvironment(name: name, projectId: project.id)
            environments.append(env)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEnvironment(_ env: VaultEnvironment) {
        do {
            try Vault.shared.deleteEnvironment(name: env.name, projectId: env.projectId)
            environments.removeAll { $0.id == env.id }
            if selectedEnvironment?.id == env.id {
                selectEnvironment(nil)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameProject(_ project: Project, newName: String) {
        do {
            try Vault.shared.renameProject(id: project.id, newName: newName)
            let renamed = Project(id: project.id, name: newName, path: project.path,
                                  activeEnvironment: project.activeEnvironment)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = renamed }
            if selectedProject?.id == project.id { selectedProject = renamed }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameEnvironment(_ env: VaultEnvironment, newName: String) {
        do {
            try Vault.shared.renameEnvironment(id: env.id, newName: newName, projectId: env.projectId)
            let renamed = VaultEnvironment(id: env.id, projectId: env.projectId, name: newName)
            if let idx = environments.firstIndex(where: { $0.id == env.id }) { environments[idx] = renamed }
            if selectedEnvironment?.id == env.id { selectedEnvironment = renamed }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveSecret(_ secret: Secret, toEnvironmentName: String?) {
        guard let project = selectedProject else { return }
        do {
            try Vault.shared.moveSecretToEnvironment(
                name: secret.name, projectId: project.id,
                fromEnvironmentName: selectedEnvironment?.name,
                toEnvironmentName: toEnvironmentName)
            reloadSecrets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveSecret(_ secret: Secret, toProjectId: String) {
        guard let project = selectedProject else { return }
        do {
            try Vault.shared.moveSecretToProject(
                name: secret.name, fromProjectId: project.id, toProjectId: toProjectId,
                fromEnvironmentName: selectedEnvironment?.name)
            reloadSecrets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Secret CRUD

    func add(name: String, value: String, description: String?) {
        guard let project = selectedProject else { return }
        do {
            _ = try Vault.shared.add(name: name, value: value, description: description,
                                     projectId: project.id,
                                     environmentName: selectedEnvironment?.name)
            reloadSecrets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(name: String, value: String, description: String?) {
        guard let project = selectedProject else { return }
        do {
            _ = try Vault.shared.set(name: name, value: value, projectId: project.id,
                                     environmentName: selectedEnvironment?.name)
            let desc = description.flatMap { $0.isEmpty ? nil : $0 }
            try Vault.shared.setDescription(name: name, description: desc, projectId: project.id)
            reloadSecrets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ secret: Secret) {
        guard let project = selectedProject else { return }
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
