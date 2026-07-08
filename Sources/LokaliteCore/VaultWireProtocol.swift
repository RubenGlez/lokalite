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

/// Wire wrapper adding a tighten-only client agent hint to a request (ADR 0018):
/// a client may declare "I am (fronting) an agent" via `agentContext`. The daemon
/// decodes the envelope first and falls back to a bare `VaultRequest` frame, so
/// legacy clients keep working; hint-less clients keep sending bare frames.
public struct VaultEnvelope: Codable, Equatable {
    public let agentContext: String?
    public let request: VaultRequest

    public init(agentContext: String?, request: VaultRequest) {
        self.agentContext = agentContext
        self.request = request
    }
}

/// Identity of a socket peer, resolved by the daemon from the kernel (ADR 0014):
/// the connecting PID and, if an AI agent is in its process tree, the agent token.
/// `clientAgentHint` is the client-asserted envelope hint (ADR 0018): tighten-only,
/// so it can turn a human-classified caller into an agent but never the reverse,
/// and kernel detection wins the attribution label when both are present.
public struct CallerContext {
    public let pid: pid_t?
    public let agent: String?
    public let clientAgentHint: String?
    /// The peer's Developer ID code signature, resolved daemon-side from the pid
    /// (ADR 0019). Attribution only — never consulted for an access decision. Nil
    /// when unverified (dev builds skip it, or the pid yielded no `SecCode`).
    public let peerSignature: PeerCodeSignature?
    /// The attribution label: kernel detection wins; the hint fills a miss.
    public var effectiveAgent: String? { agent ?? clientAgentHint }
    public var isAgent: Bool { effectiveAgent != nil }

    public init(pid: pid_t?, agent: String?, clientAgentHint: String? = nil, peerSignature: PeerCodeSignature? = nil) {
        self.pid = pid
        self.agent = agent
        self.clientAgentHint = clientAgentHint
        self.peerSignature = peerSignature
    }

    /// Tighten-only merge of a frame's envelope hint: the hint can add agent
    /// classification, but a kernel-detected agent stays an agent regardless.
    /// The daemon-resolved peer signature is preserved across the merge.
    public func merging(clientAgentHint: String?) -> CallerContext {
        CallerContext(pid: pid, agent: agent, clientAgentHint: clientAgentHint, peerSignature: peerSignature)
    }

    /// An in-process caller (no socket); used by tests and non-brokered paths.
    public static let local = CallerContext(pid: nil, agent: nil)
}

/// A daemon's consent-on-read request for an approval-tier secret (ADR 0014):
/// who is asking (the agent token; nil means the human CLI, ADR 0018) and what
/// would be released — secret, environment, and project by name — so the prompt
/// can state exactly what the user is approving. `perCall` is true for `strict`
/// secrets, whose approvals must never be cached for the session.
public struct ApprovalRequest {
    public let secretID: String
    public let secretName: String
    public let projectID: String
    public let projectName: String
    public let environmentName: String
    public let perCall: Bool
    public let agent: String?

    public init(secretID: String, secretName: String, projectID: String, projectName: String, environmentName: String, perCall: Bool, agent: String?) {
        self.secretID = secretID
        self.secretName = secretName
        self.projectID = projectID
        self.projectName = projectName
        self.environmentName = environmentName
        self.perCall = perCall
        self.agent = agent
    }
}

/// Session-grant bookkeeping for approval-tier secrets, factored out of the
/// app's Touch ID coordinator so the caching decision is testable without
/// `LocalAuthentication`. A grant is keyed by secret id and lasts until
/// `clear()` (the vault locking). Per-call (`strict`) requests bypass the cache
/// entirely — never read, never recorded — so every read re-prompts.
public final class ApprovalGrantCache {
    private let lock = NSLock()
    private var grantedSecretIDs: Set<String> = []

    public init() {}

    /// True if a cached session grant releases this request without prompting.
    public func isGranted(_ request: ApprovalRequest) -> Bool {
        guard !request.perCall else { return false }
        lock.lock(); defer { lock.unlock() }
        return grantedSecretIDs.contains(request.secretID)
    }

    /// Records a successful approval. Per-call requests are never cached.
    public func recordGrant(_ request: ApprovalRequest) {
        guard !request.perCall else { return }
        lock.lock(); defer { lock.unlock() }
        grantedSecretIDs.insert(request.secretID)
    }

    /// Drops all session grants (the vault locked or the session timed out).
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        grantedSecretIDs.removeAll()
    }
}

/// Decides whether to release an approval-tier secret to a caller — any caller,
/// human CLI included (ADR 0018; the "Agent" in the name is historical). The app
/// injects a Touch ID implementation; it may block while the user responds.
/// Returns true to release the value.
public typealias AgentApprovalHandler = (ApprovalRequest) -> Bool

/// Brokers a vault unlock with user presence when a request arrives while the
/// vault is locked. The argument is the caller's agent label (nil = the human
/// CLI), for the prompt text. The handler must obtain consent AND unlock the
/// vault, returning true only once it is unlocked; it may block on the prompt.
/// Defaults to deny (fail closed) so any path without a GUI broker refuses.
public typealias VaultUnlockHandler = (String?) -> Bool

/// Applies a decoded request to a local `VaultService` and produces a response.
/// Used by the daemon's socket server; pure and testable without any socket.
/// `caller` lets the daemon enforce agent policy independently of the client —
/// defense in depth, since the MCP layer also checks. `approveAgentAccess` brokers
/// consent for approval-tier (`requiresApproval`/`strict`) secrets — for EVERY
/// caller, not only agents (ADR 0018); it defaults to deny (fail closed) so any
/// path without a GUI broker — `--local`, headless, tests — refuses them.
/// `requestUnlock` brokers user presence when the vault is locked: a request that
/// needs the key prompts once and is retried, so auto-lock gates every caller
/// instead of being silently bypassed.
public enum VaultRequestDispatcher {
    public static func handle(
        _ request: VaultRequest,
        using service: VaultService,
        caller: CallerContext = .local,
        approveAgentAccess: AgentApprovalHandler = { _ in false },
        requestUnlock: VaultUnlockHandler = { _ in false }
    ) -> VaultResponse {
        do {
            return try dispatch(request, using: service, caller: caller, approveAgentAccess: approveAgentAccess)
        } catch VaultError.vaultLocked {
            // The operation needs the key and the vault is locked. Broker user
            // presence (Touch ID in the app) and retry once. The handler runs
            // while no vault lock is held (M3), like the approval prompt.
            guard requestUnlock(caller.effectiveAgent) else {
                return .failure(message: "The vault is locked and the unlock request was not approved. Unlock Lokalite and retry.")
            }
            do {
                return try dispatch(request, using: service, caller: caller, approveAgentAccess: approveAgentAccess)
            } catch {
                return .failure(message: error.localizedDescription)
            }
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    private static func dispatch(
        _ request: VaultRequest,
        using service: VaultService,
        caller: CallerContext,
        approveAgentAccess: AgentApprovalHandler
    ) throws -> VaultResponse {
            switch request {
            case .unlock:
                // Reachability handshake only — deliberately NOT service.unlock().
                // Loading the vault key requires user presence, brokered by
                // `requestUnlock` on the operation that actually needs it; a wire
                // request must never silently re-open a locked vault.
                return .ok
            case let .resolveProject(name, workingDirectory):
                return .project(try service.resolveProject(name: name, workingDirectory: workingDirectory))
            case .listProjects:
                return .projects(try service.listProjects())
            case let .add(name, value, description, icon, category, projectId, environmentName):
                return .secret(try service.add(name: name, value: value, description: description, icon: icon, category: category, projectId: projectId, environmentName: environmentName))
            case let .get(name, projectId, environmentName):
                let secret = try service.get(name: name, projectId: projectId, environmentName: environmentName)
                if caller.isAgent, secret.agentAccess.blocksAgents {
                    logDenial(service, secretName: name, projectId: projectId, environmentName: environmentName, agent: caller.effectiveAgent, peerTeamID: caller.peerSignature?.verifiedTeamID)
                    return .failure(message: "Secret '\(name)' is marked off-limits to AI agents.")
                }
                if secret.agentAccess.requiresApprovalForAgents {
                    // Consent is caller-independent (ADR 0018): the approval tiers
                    // mean "every read needs approval", so this branch does NOT
                    // consult caller.isAgent — a human CLI read prompts too. The
                    // agent label (nil for the human CLI) is attribution only.
                    // Resolve display names daemon-side (the service is in-process
                    // here) so the consent prompt can say exactly what it releases.
                    let project = (try? service.listProjects())?.first { $0.id == projectId }
                    let approval = ApprovalRequest(
                        secretID: secret.id,
                        secretName: name,
                        projectID: projectId,
                        projectName: project?.name ?? projectId,
                        environmentName: environmentName ?? project?.activeEnvironment ?? "Default",
                        perCall: secret.agentAccess.promptsPerCall,
                        agent: caller.effectiveAgent
                    )
                    guard approveAgentAccess(approval) else {
                        logDenial(service, secretName: name, projectId: projectId, environmentName: environmentName, agent: caller.effectiveAgent, peerTeamID: caller.peerSignature?.verifiedTeamID)
                        let recipient = caller.isAgent ? " to an AI agent" : ""
                        return .failure(message: "Access to '\(name)' was denied — approval is required to release it\(recipient).")
                    }
                }
                return .secret(secret)
            case let .set(name, value, projectId, environmentName):
                if let refusal = try governAgentWrite(name: name, action: "modify", projectId: projectId, environmentName: environmentName, using: service, caller: caller, approveAgentAccess: approveAgentAccess) {
                    return refusal
                }
                return .secret(try service.set(name: name, value: value, projectId: projectId, environmentName: environmentName))
            case let .delete(name, projectId):
                if let refusal = try governAgentWrite(name: name, action: "delete", projectId: projectId, environmentName: nil, using: service, caller: caller, approveAgentAccess: approveAgentAccess) {
                    return refusal
                }
                try service.delete(name: name, projectId: projectId)
                return .ok
            case let .list(projectId, environmentName):
                var secrets = try service.list(projectId: projectId, environmentName: environmentName)
                if caller.isAgent {
                    // An agent never receives off-limits values, even via bulk
                    // list. Approval-tier secrets are excluded too (M2): a bulk
                    // list can't broker per-secret consent, so it mirrors the CLI
                    // `bulkRevealSecrets` exclusion — the daemon stays a real
                    // chokepoint rather than only filtering `blocked`.
                    secrets = secrets.filter {
                        !$0.agentAccess.blocksAgents && !$0.agentAccess.requiresApprovalForAgents
                    }
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
                // Agent attribution is the caller's, never the request body's —
                // override whatever the client sent with caller.effectiveAgent
                // (kernel detection wins; the envelope hint fills a miss).
                service.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName, source: source, agent: caller.effectiveAgent, peerTeamID: caller.peerSignature?.verifiedTeamID, action: action)
                return .ok
            }
    }

    /// Governs a write (`set`/`delete`) against the target secret's agent-access
    /// tier, mirroring the read governance on `.get` (H3 / ADR 0020). Returns a
    /// `.failure` response to refuse the write, or nil to allow it:
    /// - `blocked`: refused for an agent caller (blocked is agent-scoped; a human
    ///   may still edit it), matching `.get`.
    /// - `requiresApproval`/`strict`: consent is brokered for EVERY caller (ADR
    ///   0018), like an approval-tier read. A write always prompts (`perCall`), so
    ///   a cached read grant never silently authorizes a destructive change.
    /// A secret that doesn't exist yet is not governed here — `set`/`delete` will
    /// surface their own not-found error.
    private static func governAgentWrite(
        name: String,
        action: String,
        projectId: String,
        environmentName: String?,
        using service: VaultService,
        caller: CallerContext,
        approveAgentAccess: AgentApprovalHandler
    ) throws -> VaultResponse? {
        guard let info = try service.listInfo(projectId: projectId).first(where: { $0.name == name }) else {
            return nil
        }
        let policy = info.agentAccess
        if caller.isAgent, policy.blocksAgents {
            logDenial(service, secretName: name, projectId: projectId, environmentName: environmentName, agent: caller.effectiveAgent, peerTeamID: caller.peerSignature?.verifiedTeamID)
            return .failure(message: "Secret '\(name)' is marked off-limits to AI agents and cannot be modified.")
        }
        if policy.requiresApprovalForAgents {
            let project = (try? service.listProjects())?.first { $0.id == projectId }
            let approval = ApprovalRequest(
                secretID: info.name,
                secretName: name,
                projectID: projectId,
                projectName: project?.name ?? projectId,
                environmentName: environmentName ?? project?.activeEnvironment ?? "Default",
                perCall: true,
                agent: caller.effectiveAgent
            )
            guard approveAgentAccess(approval) else {
                logDenial(service, secretName: name, projectId: projectId, environmentName: environmentName, agent: caller.effectiveAgent, peerTeamID: caller.peerSignature?.verifiedTeamID)
                let recipient = caller.isAgent ? " for an AI agent" : ""
                return .failure(message: "Access to \(action) '\(name)' was denied — approval is required to change it\(recipient).")
            }
        }
        return nil
    }

    /// Records a `.denied` audit entry when a caller is refused a secret at the
    /// daemon (a nil agent renders as the human/CLI). Resolves the project name
    /// from its id (the request carries only the id); best-effort, so a lookup
    /// failure falls back to the id.
    private static func logDenial(_ service: VaultService, secretName: String, projectId: String, environmentName: String?, agent: String?, peerTeamID: String?) {
        let projects = (try? service.listProjects()) ?? []
        let projectName = projects.first { $0.id == projectId }?.name ?? projectId
        service.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName ?? "Default", source: .mcp, agent: agent, peerTeamID: peerTeamID, action: .denied)
    }
}
