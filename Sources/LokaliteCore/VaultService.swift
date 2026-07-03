import Foundation

/// The vault operations that out-of-process clients (the CLI and the MCP server)
/// depend on. `Vault` is the in-process implementation used by the menu-bar app
/// (the daemon). A socket-backed `RemoteVaultService` will conform to the same
/// protocol so the CLI and MCP server can run without ever holding the vault key
/// (ADR 0014, phase 2). This protocol is the seam that swap targets.
///
/// Requirements list every parameter explicitly — protocol requirements cannot
/// carry default argument values — so callers pass all arguments. `Vault`'s
/// methods (which do declare defaults) satisfy these signatures unchanged.
public protocol VaultService: AnyObject {
    func unlock() throws

    func resolveProject(name: String?, workingDirectory: String?) throws -> Project
    func listProjects() throws -> [Project]

    func add(
        name: String,
        value: String,
        description: String?,
        icon: String?,
        category: SecretCategory?,
        projectId: String,
        environmentName: String?
    ) throws -> Secret
    func get(name: String, projectId: String, environmentName: String?) throws -> Secret
    func set(name: String, value: String, projectId: String, environmentName: String?) throws -> Secret
    func delete(name: String, projectId: String) throws
    func list(projectId: String, environmentName: String?) throws -> [Secret]
    func listInfo(projectId: String) throws -> [SecretInfo]
    func listEnvironments(projectId: String) throws -> [VaultEnvironment]
    func setActiveEnvironment(name: String?, projectId: String) throws
    func importEnv(
        pairs: [(name: String, value: String)],
        projectId: String,
        environmentName: String?,
        overwrite: Bool
    ) throws -> ImportSummary
    func logAccess(
        secretName: String,
        projectName: String,
        environmentName: String,
        source: ActivityLogEntry.AccessSource,
        agent: String?,
        peerTeamID: String?,
        action: ActivityLogEntry.Action
    )
}

extension Vault: VaultService {}

/// Serializes access to a wrapped `VaultService` with a single lock held only for
/// the duration of each individual call (M3). The daemon uses this so the vault
/// store — which is not assumed thread-safe — is never touched concurrently,
/// while the *between-call* work in the dispatcher (notably the blocking Touch ID
/// consent prompt for an approval-tier read/write) runs holding no lock. That
/// stops a human deliberating over a prompt from head-of-line-blocking every other
/// client and tripping the daemon's liveness ping. The wrapper never calls back
/// into itself, so a plain non-recursive lock is sufficient.
final class SynchronizedVaultService: VaultService {
    private let base: VaultService
    private let lock = NSLock()

    init(_ base: VaultService) { self.base = base }

    private func sync<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    func unlock() throws { try sync { try base.unlock() } }
    func resolveProject(name: String?, workingDirectory: String?) throws -> Project {
        try sync { try base.resolveProject(name: name, workingDirectory: workingDirectory) }
    }
    func listProjects() throws -> [Project] { try sync { try base.listProjects() } }
    func add(name: String, value: String, description: String?, icon: String?, category: SecretCategory?, projectId: String, environmentName: String?) throws -> Secret {
        try sync { try base.add(name: name, value: value, description: description, icon: icon, category: category, projectId: projectId, environmentName: environmentName) }
    }
    func get(name: String, projectId: String, environmentName: String?) throws -> Secret {
        try sync { try base.get(name: name, projectId: projectId, environmentName: environmentName) }
    }
    func set(name: String, value: String, projectId: String, environmentName: String?) throws -> Secret {
        try sync { try base.set(name: name, value: value, projectId: projectId, environmentName: environmentName) }
    }
    func delete(name: String, projectId: String) throws { try sync { try base.delete(name: name, projectId: projectId) } }
    func list(projectId: String, environmentName: String?) throws -> [Secret] {
        try sync { try base.list(projectId: projectId, environmentName: environmentName) }
    }
    func listInfo(projectId: String) throws -> [SecretInfo] { try sync { try base.listInfo(projectId: projectId) } }
    func listEnvironments(projectId: String) throws -> [VaultEnvironment] { try sync { try base.listEnvironments(projectId: projectId) } }
    func setActiveEnvironment(name: String?, projectId: String) throws { try sync { try base.setActiveEnvironment(name: name, projectId: projectId) } }
    func importEnv(pairs: [(name: String, value: String)], projectId: String, environmentName: String?, overwrite: Bool) throws -> ImportSummary {
        try sync { try base.importEnv(pairs: pairs, projectId: projectId, environmentName: environmentName, overwrite: overwrite) }
    }
    func logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource, agent: String?, peerTeamID: String?, action: ActivityLogEntry.Action) {
        sync { base.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName, source: source, agent: agent, peerTeamID: peerTeamID, action: action) }
    }
}
