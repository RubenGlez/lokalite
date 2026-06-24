import Foundation

public struct SecretWorkspaceContext {
    public let project: Project
    public let environmentName: String?

    public init(project: Project, environmentName: String?) {
        self.project = project
        self.environmentName = environmentName
    }

    public var displayEnvironmentName: String {
        environmentName ?? "Default"
    }
}

public final class SecretWorkspace {
    private let vault: Vault

    public init(vault: Vault = .shared) {
        self.vault = vault
    }

    public func unlock() throws {
        try vault.unlock()
    }

    public func resolveContext(
        projectName: String? = nil,
        environmentName: String? = nil,
        workingDirectory: String? = nil
    ) throws -> SecretWorkspaceContext {
        let project = try vault.resolveProject(name: projectName, workingDirectory: workingDirectory)
        return SecretWorkspaceContext(
            project: project,
            environmentName: environmentName ?? project.activeEnvironment
        )
    }

    public func add(
        name: String,
        value: String,
        description: String? = nil,
        category: SecretCategory? = nil,
        context: SecretWorkspaceContext
    ) throws -> Secret {
        try vault.add(
            name: name,
            value: value,
            description: description,
            category: category,
            projectId: context.project.id,
            environmentName: context.environmentName
        )
    }

    public func get(
        name: String,
        context: SecretWorkspaceContext,
        accessSource: ActivityLogEntry.AccessSource? = nil
    ) throws -> Secret {
        let secret = try vault.get(
            name: name,
            projectId: context.project.id,
            environmentName: context.environmentName
        )
        if let accessSource {
            logAccess(secretName: secret.name, context: context, source: accessSource)
        }
        return secret
    }

    public func list(context: SecretWorkspaceContext) throws -> [Secret] {
        try vault.list(projectId: context.project.id, environmentName: context.environmentName)
    }

    public func listInfo(context: SecretWorkspaceContext) throws -> [SecretInfo] {
        try vault.listInfo(projectId: context.project.id)
    }

    public func set(
        name: String,
        value: String,
        context: SecretWorkspaceContext
    ) throws -> Secret {
        try vault.set(
            name: name,
            value: value,
            projectId: context.project.id,
            environmentName: context.environmentName
        )
    }

    public func delete(name: String, context: SecretWorkspaceContext) throws {
        try vault.delete(name: name, projectId: context.project.id)
    }

    @discardableResult
    public func importEnv(
        pairs: [(name: String, value: String)],
        context: SecretWorkspaceContext,
        overwrite: Bool = false
    ) throws -> ImportSummary {
        try vault.importEnv(
            pairs: pairs,
            projectId: context.project.id,
            environmentName: context.environmentName,
            overwrite: overwrite
        )
    }

    public func secrets(named names: [String]?, context: SecretWorkspaceContext, accessSource: ActivityLogEntry.AccessSource? = nil) throws -> [Secret] {
        if let names {
            return try names.map { try get(name: $0, context: context, accessSource: accessSource) }
        }
        let secrets = try list(context: context)
        if let accessSource {
            for secret in secrets {
                logAccess(secretName: secret.name, context: context, source: accessSource)
            }
        }
        return secrets
    }

    public func logAccess(secretName: String, context: SecretWorkspaceContext, source: ActivityLogEntry.AccessSource) {
        vault.logAccess(
            secretName: secretName,
            projectName: context.project.name,
            environmentName: context.displayEnvironmentName,
            source: source
        )
    }
}
