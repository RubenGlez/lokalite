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
        action: ActivityLogEntry.Action
    )
}

extension Vault: VaultService {}
