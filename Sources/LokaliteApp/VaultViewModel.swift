import AppKit
import LocalAuthentication
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
            preferences.sessionTimeoutSeconds
        }
        set {
            preferences.sessionTimeoutSeconds = newValue
            if !isLocked { renewSession() }
        }
    }

    var launchAtLogin: Bool {
        get { loginItem.isEnabled }
        set {
            do {
                try loginItem.setEnabled(newValue)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var clipboardClearSeconds: Double {
        get {
            preferences.clipboardClearSeconds
        }
        set { preferences.clipboardClearSeconds = newValue }
    }

    // Stored (not computed) so @Observable tracks it and the UI re-renders on change.
    var appearanceMode: String = AppPreferences().appearanceMode {
        didSet { preferences.appearanceMode = appearanceMode }
    }

    var hotkeyShortcutID: String {
        get { preferences.hotkeyShortcutID }
        set { preferences.hotkeyShortcutID = newValue }
    }

    var recentSecretNames: [String] {
        get { preferences.recentSecretNames }
        set { preferences.recentSecretNames = newValue }
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

    private let preferences = AppPreferences()
    private let loginItem = LoginItemController()
    private let sessionPolicy = SessionPolicy()
    private let clipboard = ClipboardController()
    private let workspace = SecretWorkspace()

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
                self?.errorMessage = authError?.localizedDescription
                    ?? "Device authentication is unavailable. Set a login password to unlock the vault."
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
        sessionPolicy.cancel()
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
        NotificationCenter.default.post(name: .vaultDidLock, object: nil)
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
        sessionPolicy.renew(timeout: sessionTimeoutSeconds) { [weak self] in
            self?.lock()
        }
    }

    // MARK: - Selection

    func selectProject(_ project: Project?) {
        renewSession()
        selectedProject = project
        selectedEnvironment = nil
        reloadEnvironments()
        selectedEnvironment = environments.first { $0.name == project?.activeEnvironment } ?? environments.first
        reloadSecrets()
        reloadDashboardSummaries()
    }

    func selectEnvironment(_ env: VaultEnvironment?) {
        renewSession()
        selectedEnvironment = env
        reloadSecrets()
    }

    /// The environment the CLI, shell, and MCP agents resolve for this project.
    /// Distinct from `selectedEnvironment`, which only drives what the app shows.
    var activeEnvironmentName: String? {
        selectedProject?.activeEnvironment
    }

    func isActiveEnvironment(_ env: VaultEnvironment) -> Bool {
        env.name == selectedProject?.activeEnvironment
    }

    /// Promote an environment to the project's active environment, so terminals
    /// and agents resolve it. Also switches the app's view to match.
    func makeEnvironmentActive(_ env: VaultEnvironment) {
        renewSession()
        guard let project = selectedProject else { return }
        do {
            try Vault.shared.setActiveEnvironment(name: env.name, projectId: project.id)
            let updated = Project(id: project.id, name: project.name, path: project.path,
                                  activeEnvironment: env.name, icon: project.icon,
                                  createdAt: project.createdAt)
            if let idx = projects.firstIndex(where: { $0.id == project.id }) { projects[idx] = updated }
            selectedProject = updated
            selectEnvironment(env)
        } catch {
            errorMessage = error.localizedDescription
        }
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
            selectedEnvironment = environments.first { $0.name == selectedProject?.activeEnvironment } ?? environments.first
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
            var counts: [String: Int] = [:]
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
            selectProject(project)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func deleteProject(_ project: Project, includingContents: Bool = false) -> Bool {
        renewSession()
        do {
            if includingContents {
                try Vault.shared.deleteProjectIncludingContents(id: project.id)
            } else {
                try Vault.shared.deleteProject(id: project.id)
            }
            projects.removeAll { $0.id == project.id }
            if selectedProject?.id == project.id {
                selectProject(projects.first)
            }
            return true
        } catch VaultError.projectContainsSecrets {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return true
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

    @discardableResult
    func deleteEnvironment(_ env: VaultEnvironment, includingContents: Bool = false) -> Bool {
        renewSession()
        do {
            if includingContents {
                try Vault.shared.deleteEnvironmentIncludingContents(name: env.name, projectId: env.projectId)
            } else {
                try Vault.shared.deleteEnvironment(name: env.name, projectId: env.projectId)
            }
            environments.removeAll { $0.id == env.id }
            if selectedEnvironment?.id == env.id {
                selectEnvironment(environments.first)
            }
            reloadDashboardSummaries()
            reloadSecrets()
            return true
        } catch VaultError.environmentContainsSecrets {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return true
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

    /// Builds the workspace context for secret operations from the current
    /// selection. The app resolves context from its own selection rather than
    /// the env-var/working-directory tiers the CLI uses.
    private func makeContext(_ project: Project) -> SecretWorkspaceContext {
        SecretWorkspaceContext(project: project, environmentName: selectedEnvironment?.name)
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
            _ = try workspace.add(name: name, value: value, description: description,
                                  category: category, context: makeContext(project))
            reloadSecrets()
            reloadDashboardSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Import parsed `.env` pairs into an existing project + environment via the
    /// shared core routine. Existing secrets are skipped unless `overwrite` is set.
    @discardableResult
    func importEnv(pairs: [(name: String, value: String)], projectId: String,
                   environmentName: String, overwrite: Bool) -> ImportSummary? {
        renewSession()
        do {
            let summary = try Vault.shared.importEnv(pairs: pairs, projectId: projectId,
                                                     environmentName: environmentName, overwrite: overwrite)
            reloadSecrets()
            reloadDashboardSummaries()
            return summary
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Create a project from parsed `.env` pairs. A non-Default environment name
    /// renames the auto-created Default rather than leaving an empty one behind.
    @discardableResult
    func createProjectFromEnv(name: String, environmentName: String, linkPath: String?,
                              pairs: [(name: String, value: String)], overwrite: Bool) -> ImportSummary? {
        renewSession()
        do {
            let result = try Vault.shared.createProjectFromEnv(
                name: name, environmentName: environmentName, linkPath: linkPath,
                pairs: pairs, overwrite: overwrite)
            projects.append(result.project)
            selectProject(result.project)
            reloadDashboardSummaries()
            return result.summary
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func update(
        name: String,
        value: String,
        description: String?,
        category: SecretCategory,
        agentAccess: AgentAccessPolicy
    ) {
        renewSession()
        guard let project = selectedProject else { return }
        do {
            let desc = description.flatMap { $0.isEmpty ? nil : $0 }
            try Vault.shared.setDescription(name: name, description: desc, projectId: project.id)
            _ = try workspace.set(name: name, value: value, context: makeContext(project))
            try Vault.shared.setSecretCategory(name: name, category: category, projectId: project.id)
            try Vault.shared.setAgentAccess(name: name, projectId: project.id, policy: agentAccess)
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
            try workspace.delete(name: secret.name, context: makeContext(project))
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

    enum CopyFormat {
        case value
        case dotenvLine
        case exportLine
    }

    func copyToClipboard(_ secret: Secret) {
        copyToClipboard(secret, format: .value)
    }

    func copyToClipboard(_ secret: Secret, format: CopyFormat) {
        renewSession()
        recordRecent(secret)
        if let selectedProject {
            workspace.logAccess(secretName: secret.name, context: makeContext(selectedProject), source: .app)
        }
        reloadActivity()
        let text: String
        switch format {
        case .value:
            text = secret.value
        case .dotenvLine:
            text = EnvFileFormat.line(name: secret.name, value: secret.value)
        case .exportLine:
            text = "export " + EnvFileFormat.line(name: secret.name, value: secret.value)
        }
        clipboard.copy(text, clearAfter: clipboardClearSeconds)
    }

    func copyEnvFile() {
        renewSession()
        guard !secrets.isEmpty else { return }
        let lines = secrets.map { EnvFileFormat.line(name: $0.name, value: $0.value) }
        clipboard.copy(lines.joined(separator: "\n") + "\n", clearAfter: clipboardClearSeconds)
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
