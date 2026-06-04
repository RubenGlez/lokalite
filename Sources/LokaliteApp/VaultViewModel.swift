import AppKit
import LocalAuthentication
import ServiceManagement
import SwiftUI
import LokaliteCore

@Observable
@MainActor
final class VaultViewModel {
    var projects: [Project] = []
    var selectedProject: Project?
    var environments: [VaultEnvironment] = []
    var selectedEnvironment: VaultEnvironment?  // nil = default values
    var secrets: [Secret] = []
    var environmentSecretCounts: [String: Int] = [:]
    var secretEnvironmentNames: [String: [String]] = [:]
    var projectSecretCount = 0
    var isLocked = true
    var errorMessage: String?
    var activityEntries: [ActivityLogEntry] = []

    var sessionTimeoutSeconds: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "sessionTimeoutSeconds")
            return v > 0 ? v : 300
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sessionTimeoutSeconds")
            if !isLocked { renewSession() }
        }
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

    var appearanceMode: String = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system" {
        didSet { UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode") }
    }

    var hotkeyShortcutID: String = UserDefaults.standard.string(forKey: "hotkeyShortcutID") ?? "cmdShiftSpace" {
        didSet {
            UserDefaults.standard.set(hotkeyShortcutID, forKey: "hotkeyShortcutID")
            NotificationCenter.default.post(name: .hotkeyShortcutChanged, object: hotkeyShortcutID)
        }
    }

    var recentSecretNames: [String] = UserDefaults.standard.stringArray(forKey: "recentSecretNames") ?? [] {
        didSet { UserDefaults.standard.set(recentSecretNames, forKey: "recentSecretNames") }
    }

    var environmentColors: [String: Color] {
        Dictionary(uniqueKeysWithValues: environments.map { ($0.name, Theme.color(hex: $0.color)) })
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var lockTimer: Timer?

    // MARK: - Lock / Unlock

    func unlock() {
        guard isLocked else {
            renewSession()
            return
        }
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
        projects = []
        selectedProject = nil
        selectedEnvironment = nil
        secrets = []
        environments = []
        environmentSecretCounts = [:]
        secretEnvironmentNames = [:]
        projectSecretCount = 0
        activityEntries = []
        isLocked = true
        closeVisibleSurfaces()
    }

    private func closeVisibleSurfaces() {
        DispatchQueue.main.async {
            NSApp.windows
                .filter(\.isVisible)
                .forEach { window in
                    if window.styleMask.contains(.titled) {
                        window.close()
                    } else {
                        window.orderOut(nil)
                    }
                }
        }
    }

    @MainActor
    private func performUnlock() {
        do {
            try Vault.shared.unlock()
            isLocked = false
            refresh()
            renewSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renewSession() {
        guard !isLocked else { return }
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeoutSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.lock() }
        }
    }

    // MARK: - Selection

    func selectProject(_ project: Project?) {
        renewSession()
        selectedProject = project
        selectedEnvironment = nil
        reloadEnvironments()
        if selectedEnvironment == nil {
            selectedEnvironment = environments.first
        }
        reloadSecrets()
        reloadDashboardSummaries()
    }

    func selectEnvironment(_ env: VaultEnvironment?) {
        renewSession()
        selectedEnvironment = env
        reloadSecrets()
    }

    // MARK: - Data loading

    func refresh() {
        guard !isLocked else { return }
        renewSession()
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
            if selectedEnvironment == nil {
                selectedEnvironment = environments.first
            }
            reloadSecrets()
            reloadDashboardSummaries()
            reloadActivity()
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

    private func reloadDashboardSummaries() {
        guard let project = selectedProject else {
            projectSecretCount = 0
            environmentSecretCounts = [:]
            secretEnvironmentNames = [:]
            return
        }

        do {
            projectSecretCount = try Vault.shared.totalSecretCount(projectId: project.id)
            var counts = ["default": try Vault.shared.secretCount(projectId: project.id, environmentName: nil)]
            for environment in environments {
                counts[environment.id] = try Vault.shared.secretCount(
                    projectId: project.id,
                    environmentName: environment.name
                )
            }
            environmentSecretCounts = counts
            secretEnvironmentNames = try Vault.shared.secretEnvironmentNames(projectId: project.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Project CRUD

    func addProject(name: String, icon: String? = "folder") {
        renewSession()
        do {
            let project = try Vault.shared.addProject(name: name, icon: icon)
            projects.append(project)
            _ = try? Vault.shared.addEnvironment(name: "Default", projectId: project.id, color: nil)
            selectProject(project)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProject(_ project: Project) {
        renewSession()
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

    func addEnvironment(name: String, color: String? = nil) {
        renewSession()
        guard let project = selectedProject else {
            errorMessage = "Select a project before adding an environment."
            return
        }
        do {
            let env = try Vault.shared.addEnvironment(name: name, projectId: project.id, color: color)
            environments.append(env)
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEnvironment(_ env: VaultEnvironment) {
        renewSession()
        do {
            try Vault.shared.deleteEnvironment(name: env.name, projectId: env.projectId)
            environments.removeAll { $0.id == env.id }
            if selectedEnvironment?.id == env.id {
                selectEnvironment(nil)
            }
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameProject(_ project: Project, newName: String) {
        renewSession()
        do {
            try Vault.shared.renameProject(id: project.id, newName: newName)
            let renamed = Project(id: project.id, name: newName, path: project.path,
                                  activeEnvironment: project.activeEnvironment, icon: project.icon)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = renamed }
            if selectedProject?.id == project.id { selectedProject = renamed }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameEnvironment(_ env: VaultEnvironment, newName: String) {
        renewSession()
        do {
            try Vault.shared.renameEnvironment(id: env.id, newName: newName, projectId: env.projectId)
            let renamed = VaultEnvironment(id: env.id, projectId: env.projectId, name: newName, color: env.color)
            if let idx = environments.firstIndex(where: { $0.id == env.id }) { environments[idx] = renamed }
            if selectedEnvironment?.id == env.id { selectedEnvironment = renamed }
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveSecret(_ secret: Secret, toEnvironmentName: String?) {
        renewSession()
        guard let project = selectedProject else { return }
        do {
            try Vault.shared.moveSecretToEnvironment(
                name: secret.name, projectId: project.id,
                fromEnvironmentName: selectedEnvironment?.name,
                toEnvironmentName: toEnvironmentName)
            reloadSecrets()
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveSecret(_ secret: Secret, toProjectId: String) {
        renewSession()
        guard let project = selectedProject else { return }
        do {
            try Vault.shared.moveSecretToProject(
                name: secret.name, fromProjectId: project.id, toProjectId: toProjectId,
                fromEnvironmentName: selectedEnvironment?.name)
            reloadSecrets()
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Secret CRUD

    func setProjectIcon(_ project: Project, icon: String?) {
        renewSession()
        do {
            try Vault.shared.setProjectIcon(id: project.id, icon: icon)
            let updated = Project(id: project.id, name: project.name, path: project.path,
                                  activeEnvironment: project.activeEnvironment, icon: icon)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = updated }
            if selectedProject?.id == project.id { selectedProject = updated }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setEnvironmentColor(_ env: VaultEnvironment, color: String?) {
        renewSession()
        do {
            try Vault.shared.setEnvironmentColor(id: env.id, color: color)
            let updated = VaultEnvironment(id: env.id, projectId: env.projectId, name: env.name, color: color)
            if let idx = environments.firstIndex(where: { $0.id == env.id }) { environments[idx] = updated }
            if selectedEnvironment?.id == env.id { selectedEnvironment = updated }
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(
        name: String,
        value: String,
        description: String?,
        category: SecretCategory? = nil
    ) {
        renewSession()
        guard let project = selectedProject else {
            errorMessage = "Create or select a project before adding a secret."
            return
        }
        guard selectedEnvironment != nil else {
            errorMessage = "Select an environment before adding a secret."
            return
        }
        do {
            _ = try Vault.shared.add(name: name, value: value, description: description, category: category,
                                     projectId: project.id,
                                     environmentName: selectedEnvironment?.name)
            reloadSecrets()
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(
        name: String,
        value: String,
        description: String?,
        category: SecretCategory
    ) {
        renewSession()
        guard let project = selectedProject else { return }
        do {
            let desc = description.flatMap { $0.isEmpty ? nil : $0 }
            try Vault.shared.setDescription(name: name, description: desc, projectId: project.id)
            _ = try Vault.shared.set(name: name, value: value, projectId: project.id,
                                     environmentName: selectedEnvironment?.name)
            try Vault.shared.setSecretCategory(name: name, category: category, projectId: project.id)
            reloadSecrets()
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ secret: Secret) {
        renewSession()
        guard let project = selectedProject else { return }
        do {
            try Vault.shared.delete(name: secret.name, projectId: project.id)
            secrets.removeAll { $0.id == secret.id }
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func linkProject(_ project: Project, path: String?) {
        renewSession()
        do {
            try Vault.shared.linkProject(id: project.id, path: path)
            let updated = Project(id: project.id, name: project.name, path: path,
                                  activeEnvironment: project.activeEnvironment, icon: project.icon)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = updated }
            if selectedProject?.id == project.id { selectedProject = updated }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ secret: Secret) {
        renewSession()
        recordRecent(secret)
        Vault.shared.logAccess(
            secretName: secret.name,
            projectName: selectedProject?.name ?? "unknown",
            environmentName: selectedEnvironment?.name ?? "Default",
            source: .app
        )
        reloadActivity()
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

    private func reloadActivity() {
        activityEntries = (try? Vault.shared.listActivity()) ?? []
    }

    private func recordRecent(_ secret: Secret) {
        var recents = recentSecretNames
        recents.removeAll { $0 == secret.name }
        recents.insert(secret.name, at: 0)
        recentSecretNames = Array(recents.prefix(5))
    }
}
