import Foundation

/// One `.env` key/value pair on the wire (tuples aren't `Codable`).
public struct EnvPair: Codable, Equatable {
    public let name: String
    public let value: String
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// A `VaultService` call serialized for transport to the daemon (ADR 0014).
/// One case per protocol method; `Codable` is synthesized for the enum.
public enum VaultRequest: Codable, Equatable {
    case unlock
    case resolveProject(name: String?, workingDirectory: String?)
    case listProjects
    case add(name: String, value: String, description: String?, icon: String?, category: SecretCategory?, projectId: String, environmentName: String?)
    case get(name: String, projectId: String, environmentName: String?)
    case set(name: String, value: String, projectId: String, environmentName: String?)
    case delete(name: String, projectId: String)
    case list(projectId: String, environmentName: String?)
    case listInfo(projectId: String)
    case listEnvironments(projectId: String)
    case setActiveEnvironment(name: String?, projectId: String)
    case importEnv(pairs: [EnvPair], projectId: String, environmentName: String?, overwrite: Bool)
    case logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource, action: ActivityLogEntry.Action)
}

/// The daemon's reply. `.failure` carries a human-readable message; everything
/// else is the typed result of the corresponding request.
public enum VaultResponse: Codable, Equatable {
    case ok
    case secret(Secret)
    case secrets([Secret])
    case project(Project)
    case projects([Project])
    case secretInfos([SecretInfo])
    case environments([VaultEnvironment])
    case importSummary(ImportSummary)
    case failure(message: String)
}

/// Identity of a socket peer, resolved by the daemon from the kernel (ADR 0014):
/// the connecting PID and, if an AI agent is in its process tree, the agent token.
public struct CallerContext {
    public let pid: pid_t?
    public let agent: String?
    public var isAgent: Bool { agent != nil }

    public init(pid: pid_t?, agent: String?) {
        self.pid = pid
        self.agent = agent
    }

    /// An in-process caller (no socket); used by tests and non-brokered paths.
    public static let local = CallerContext(pid: nil, agent: nil)
}

/// A daemon's consent-on-read request for a `requiresApproval` secret (ADR 0014):
/// who is asking (the agent token), and which secret, so the prompt can name both.
public struct ApprovalRequest {
    public let secretID: String
    public let secretName: String
    public let projectID: String
    public let agent: String?

    public init(secretID: String, secretName: String, projectID: String, agent: String?) {
        self.secretID = secretID
        self.secretName = secretName
        self.projectID = projectID
        self.agent = agent
    }
}

/// Decides whether to release a `requiresApproval` secret to an agent caller.
/// The app injects a Touch ID implementation; it may block while the user
/// responds. Returns true to release the value.
public typealias AgentApprovalHandler = (ApprovalRequest) -> Bool

/// Applies a decoded request to a local `VaultService` and produces a response.
/// Used by the daemon's socket server; pure and testable without any socket.
/// `caller` lets the daemon enforce agent policy independently of the client —
/// defense in depth, since the MCP layer also checks. `approveAgentAccess` brokers
/// consent for `requiresApproval` secrets; it defaults to deny (fail closed) so
/// any path without a GUI broker — `--local`, headless, tests — refuses them.
public enum VaultRequestDispatcher {
    public static func handle(
        _ request: VaultRequest,
        using service: VaultService,
        caller: CallerContext = .local,
        approveAgentAccess: AgentApprovalHandler = { _ in false }
    ) -> VaultResponse {
        do {
            switch request {
            case .unlock:
                try service.unlock()
                return .ok
            case let .resolveProject(name, workingDirectory):
                return .project(try service.resolveProject(name: name, workingDirectory: workingDirectory))
            case .listProjects:
                return .projects(try service.listProjects())
            case let .add(name, value, description, icon, category, projectId, environmentName):
                return .secret(try service.add(name: name, value: value, description: description, icon: icon, category: category, projectId: projectId, environmentName: environmentName))
            case let .get(name, projectId, environmentName):
                let secret = try service.get(name: name, projectId: projectId, environmentName: environmentName)
                if caller.isAgent {
                    if secret.agentAccess.blocksAgents {
                        logDenial(service, secretName: name, projectId: projectId, environmentName: environmentName, agent: caller.agent)
                        return .failure(message: "Secret '\(name)' is marked off-limits to AI agents.")
                    }
                    if secret.agentAccess.requiresApprovalForAgents {
                        let approval = ApprovalRequest(secretID: secret.id, secretName: name, projectID: projectId, agent: caller.agent)
                        guard approveAgentAccess(approval) else {
                            logDenial(service, secretName: name, projectId: projectId, environmentName: environmentName, agent: caller.agent)
                            return .failure(message: "Access to '\(name)' was denied — approval is required to release it to an AI agent.")
                        }
                    }
                }
                return .secret(secret)
            case let .set(name, value, projectId, environmentName):
                return .secret(try service.set(name: name, value: value, projectId: projectId, environmentName: environmentName))
            case let .delete(name, projectId):
                try service.delete(name: name, projectId: projectId)
                return .ok
            case let .list(projectId, environmentName):
                var secrets = try service.list(projectId: projectId, environmentName: environmentName)
                if caller.isAgent {
                    // An agent never receives off-limits values, even via bulk list.
                    secrets = secrets.filter { !$0.agentAccess.blocksAgents }
                }
                return .secrets(secrets)
            case let .listInfo(projectId):
                return .secretInfos(try service.listInfo(projectId: projectId))
            case let .listEnvironments(projectId):
                return .environments(try service.listEnvironments(projectId: projectId))
            case let .setActiveEnvironment(name, projectId):
                try service.setActiveEnvironment(name: name, projectId: projectId)
                return .ok
            case let .importEnv(pairs, projectId, environmentName, overwrite):
                let tuples = pairs.map { (name: $0.name, value: $0.value) }
                return .importSummary(try service.importEnv(pairs: tuples, projectId: projectId, environmentName: environmentName, overwrite: overwrite))
            case let .logAccess(secretName, projectName, environmentName, source, action):
                // Agent identity is authoritative from the kernel (peer-PID), not
                // the client — override whatever the client sent with caller.agent.
                service.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName, source: source, agent: caller.agent, action: action)
                return .ok
            }
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    /// Records a `.denied` audit entry when an agent is refused a secret at the
    /// daemon. Resolves the project name from its id (the request carries only
    /// the id); best-effort, so a lookup failure falls back to the id.
    private static func logDenial(_ service: VaultService, secretName: String, projectId: String, environmentName: String?, agent: String?) {
        let projects = (try? service.listProjects()) ?? []
        let projectName = projects.first { $0.id == projectId }?.name ?? projectId
        service.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName ?? "Default", source: .mcp, agent: agent, action: .denied)
    }
}
