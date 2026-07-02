import Foundation

public enum RemoteVaultError: Error, LocalizedError {
    /// The daemon ran the operation and returned an error (e.g. secret not found).
    case daemon(String)
    /// The daemon returned a response that doesn't match the request.
    case unexpectedResponse

    public var errorDescription: String? {
        switch self {
        case .daemon(let message): return message
        case .unexpectedResponse: return "Unexpected response from the Lokalite daemon."
        }
    }
}

/// A `VaultService` that runs every operation in the daemon instead of in this
/// process, so the CLI and MCP server never hold the vault key (ADR 0014).
///
/// The actual byte transport is injected: the socket client provides one in
/// production; tests inject an in-process dispatcher so the whole request →
/// dispatch → response → result loop is exercised without a socket.
public final class RemoteVaultService: VaultService {
    public typealias Transport = (VaultRequest) throws -> VaultResponse

    private let transport: Transport

    public init(transport: @escaping Transport) {
        self.transport = transport
    }

    private func send(_ request: VaultRequest) throws -> VaultResponse {
        let response = try transport(request)
        if case let .failure(message) = response {
            throw RemoteVaultError.daemon(message)
        }
        return response
    }

    public func unlock() throws {
        _ = try send(.unlock)
    }

    public func resolveProject(name: String?, workingDirectory: String?) throws -> Project {
        guard case let .project(project) = try send(.resolveProject(name: name, workingDirectory: workingDirectory)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return project
    }

    public func listProjects() throws -> [Project] {
        guard case let .projects(projects) = try send(.listProjects) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return projects
    }

    public func add(name: String, value: String, description: String?, icon: String?, category: SecretCategory?, projectId: String, environmentName: String?) throws -> Secret {
        guard case let .secret(secret) = try send(.add(name: name, value: value, description: description, icon: icon, category: category, projectId: projectId, environmentName: environmentName)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return secret
    }

    public func get(name: String, projectId: String, environmentName: String?) throws -> Secret {
        guard case let .secret(secret) = try send(.get(name: name, projectId: projectId, environmentName: environmentName)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return secret
    }

    public func set(name: String, value: String, projectId: String, environmentName: String?) throws -> Secret {
        guard case let .secret(secret) = try send(.set(name: name, value: value, projectId: projectId, environmentName: environmentName)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return secret
    }

    public func delete(name: String, projectId: String) throws {
        _ = try send(.delete(name: name, projectId: projectId))
    }

    public func list(projectId: String, environmentName: String?) throws -> [Secret] {
        guard case let .secrets(secrets) = try send(.list(projectId: projectId, environmentName: environmentName)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return secrets
    }

    public func listInfo(projectId: String) throws -> [SecretInfo] {
        guard case let .secretInfos(infos) = try send(.listInfo(projectId: projectId)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return infos
    }

    public func listEnvironments(projectId: String) throws -> [VaultEnvironment] {
        guard case let .environments(environments) = try send(.listEnvironments(projectId: projectId)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return environments
    }

    public func setActiveEnvironment(name: String?, projectId: String) throws {
        _ = try send(.setActiveEnvironment(name: name, projectId: projectId))
    }

    public func importEnv(pairs: [(name: String, value: String)], projectId: String, environmentName: String?, overwrite: Bool) throws -> ImportSummary {
        let wirePairs = pairs.map { EnvPair(name: $0.name, value: $0.value) }
        guard case let .importSummary(summary) = try send(.importEnv(pairs: wirePairs, projectId: projectId, environmentName: environmentName, overwrite: overwrite)) else {
            throw RemoteVaultError.unexpectedResponse
        }
        return summary
    }

    /// Logging is best-effort, mirroring the local `Vault.logAccess` (non-throwing).
    /// `agent` is intentionally not sent — the daemon stamps the caller's agent
    /// from the kernel peer-PID, which the client cannot forge.
    public func logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource, agent: String? = nil, peerTeamID: String? = nil, action: ActivityLogEntry.Action = .read) {
        // `agent` and `peerTeamID` are intentionally not sent — the daemon stamps
        // both from the kernel peer-PID / its code signature, which the client
        // cannot forge.
        _ = try? send(.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName, source: source, action: action))
    }
}
