import ArgumentParser
import Foundation
import LokaliteCore

@main
struct LokaliteCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lokalite",
        abstract: "A local-first secrets workspace for developers.",
        subcommands: [
            AddCommand.self,
            GetCommand.self,
            SetCommand.self,
            DeleteCommand.self,
            CopyCommand.self,
            ListCommand.self,
            ExportCommand.self,
            RunCommand.self,
            ProjectCommand.self,
            EnvCommand.self,
            MCPCommand.self,
            InstallCommand.self,
            ImportCommand.self,
            BackupCommand.self,
            RestoreCommand.self,
            ShellCommand.self,
            StatusCommand.self,
            LogCommand.self,
            InitCommand.self,
            SeedCommand.self,
            AgentAccessCommand.self,
        ]
    )
}

// MARK: - Shared helpers

func withVault<T>(_ body: (Vault) throws -> T) throws -> T {
    let vault = Vault.shared
    try vault.unlock()
    return try body(vault)
}

func withWorkspace<T>(_ body: (SecretWorkspace) throws -> T) throws -> T {
    let workspace = SecretWorkspace()
    try workspace.unlock()
    return try body(workspace)
}

/// Refuses a bulk secret-reveal action when an AI agent is detected in the
/// calling process tree (ADR 0014). Agents should inject with `lokalite run`
/// or use the MCP handoff, never read raw values to stdout or a file.
func ensureNotAgentExfil(allowAgent: Bool, action: String) throws {
    guard !allowAgent, let agent = AgentDetection.detectAgent() else { return }
    print("Refusing to \(action): an AI agent (\(agent)) was detected in the calling process tree.")
    print("Secrets exposed this way can leak into the agent's context or a file on disk.")
    print("Use `lokalite run -- <command>` to inject secrets without revealing them, or pass --allow-agent to override.")
    throw ExitCode.failure
}

/// Enforces a secret's `blocked` agent policy on the CLI's in-process reveal
/// paths (`get`, `copy`) when an AI agent is detected in the calling tree
/// (ADR 0014) — the same refusal the MCP and daemon enforce. The value has
/// already been fetched but is never printed. Approval-tier secrets never reach
/// this check: `CLIReveal` routes them through the daemon, which brokers the
/// consent prompt for every caller (ADR 0018).
func enforceAgentRevealPolicy(_ secret: Secret) throws {
    guard let agent = AgentDetection.detectAgent() else { return }
    if secret.agentAccess.blocksAgents {
        print("Secret '\(secret.name)' is off-limits to AI agents (\(agent) detected); refusing to reveal it.")
        print("Run `lokalite agent-access \(secret.name) allow` if this should be readable by agents.")
        throw ExitCode.failure
    }
}

// MARK: - CLI reveal routing (ADR 0018)

/// Routes a CLI reveal (`get`, `copy`) by the secret's agent-access tier, read
/// from `listInfo` (metadata only — nothing is decrypted until the route is
/// known). Approval-tier (`requiresApproval`/`strict`) secrets are brokered
/// through the daemon — where the Touch ID prompt lives — for EVERY caller,
/// humans included, and are never decrypted in this process. Every other tier
/// keeps the existing in-process path.
enum CLIReveal {
    static func secret(
        named name: String,
        in workspace: SecretWorkspace,
        context: SecretWorkspaceContext,
        daemonFetch: (String, SecretWorkspaceContext) throws -> Secret = CLIReveal.fetchThroughDaemon
    ) throws -> Secret {
        let info = try workspace.listInfo(context: context).first { $0.name == name }
        if info?.agentAccess.requiresApprovalForAgents == true {
            return try daemonFetch(name, context)
        }
        return try workspace.get(name: name, context: context, accessSource: .cli)
    }

    /// The fail-closed refusal when the daemon is unreachable. Deliberately no
    /// override flag (ADR 0018): headless/CI cannot read approval-tier secrets.
    static func daemonUnreachableMessage(secretName: String) -> String {
        "Secret '\(secretName)' requires approval to release, and the consent prompt can only be shown by the Lokalite app, which could not be reached. Open Lokalite and try again."
    }

    /// Production daemon route: same wiring as `MCPCommand.vaultService()`, with
    /// `RunCommand.socketClient` supplying the tighten-only agent hint when the
    /// CLI's own detection fires — an agent driving `lokalite get` stays
    /// classified and attributed at the daemon; a human sends bare frames. The
    /// read is logged with source `.cli`; the daemon stamps the agent (or none).
    static func fetchThroughDaemon(name: String, context: SecretWorkspaceContext) throws -> Secret {
        let socketPath = VaultConfiguration.daemonSocketURL.path
        do {
            try VaultDaemonLauncher.ensureRunning(socketPath: socketPath)
        } catch {
            print(daemonUnreachableMessage(secretName: name))
            throw ExitCode.failure
        }
        let remote = SecretWorkspace(vault: RemoteVaultService(transport: RunCommand.socketClient(socketPath: socketPath).send))
        return try remote.get(name: name, context: context, accessSource: .cli)
    }
}

// MARK: - Bulk reveal exclusions (ADR 0018)

/// Fetches the secrets a bulk reveal path (`shell`, `export --format env`,
/// bulk `run` injection) may release: approval-tier secrets are excluded —
/// per-secret consent lives on `get`/`copy`/`lokalite://` refs — and returned
/// by name so the caller can print a skip notice. Only released secrets are
/// stamped into the activity log (a nil `accessSource` skips logging, matching
/// each path's existing behavior).
func bulkRevealSecrets(
    named names: [String]?,
    context: SecretWorkspaceContext,
    workspace: SecretWorkspace,
    accessSource: ActivityLogEntry.AccessSource? = .cli
) throws -> (released: [Secret], skippedApprovalTier: [String]) {
    let approvalTier = Set(
        try workspace.listInfo(context: context)
            .filter { $0.agentAccess.requiresApprovalForAgents }
            .map(\.name)
    )
    if let names {
        let skipped = names.filter { approvalTier.contains($0) }
        let released = try workspace.secrets(named: names.filter { !approvalTier.contains($0) }, context: context, accessSource: accessSource)
        return (released, skipped)
    }
    let all = try workspace.list(context: context)
    let released = all.filter { !approvalTier.contains($0.name) }
    let skipped = all.map(\.name).filter { approvalTier.contains($0) }
    if let accessSource {
        for secret in released {
            workspace.logAccess(secretName: secret.name, context: context, source: accessSource)
        }
    }
    return (released, skipped)
}

/// The notice naming the approval-tier secrets a bulk path skipped — names and
/// the reason only, never a value. Nil when nothing was skipped.
func approvalTierSkipNotice(_ names: [String]) -> String? {
    guard !names.isEmpty else { return nil }
    let noun = names.count == 1 ? "secret" : "secrets"
    return """
    Skipped \(names.count) \(noun) requiring approval: \(names.joined(separator: ", ")).
    Each release needs consent — use `lokalite get`/`lokalite copy` or a lokalite:// reference to approve per secret.
    """
}

/// Prints the skip notice to stderr: `shell`'s stdout is eval'd and `run`'s
/// belongs to the child, so the notice must never contaminate stdout.
func printApprovalTierSkipNotice(_ names: [String]) {
    guard let notice = approvalTierSkipNotice(names) else { return }
    FileHandle.standardError.write(Data((notice + "\n").utf8))
}

/// One-line summary printed by `import` and `init --from-env`.
func importSummaryLine(_ summary: ImportSummary) -> String {
    var parts: [String] = []
    if summary.added > 0 { parts.append("\(summary.added) added") }
    if summary.updated > 0 { parts.append("\(summary.updated) updated") }
    if summary.skipped > 0 {
        parts.append("\(summary.skipped) skipped (already exist — use --overwrite to replace)")
    }
    return parts.isEmpty ? "Nothing to import." : parts.joined(separator: ", ") + "."
}

func resolveContext(
    projectFlag: String?,
    envFlag: String?,
    pathFlag: String? = nil,
    using workspace: SecretWorkspace
) throws -> SecretWorkspaceContext {
    let projectName = projectFlag ?? ProcessInfo.processInfo.environment["LOKALITE_PROJECT"]
    let envName = envFlag ?? ProcessInfo.processInfo.environment["LOKALITE_ENV"]

    return try workspace.resolveContext(
        projectName: projectName,
        environmentName: envName,
        workingDirectory: pathFlag ?? FileManager.default.currentDirectoryPath
    )
}

func resolveContext(projectFlag: String?, envFlag: String?) throws -> SecretWorkspaceContext {
    try withWorkspace { workspace in
        try resolveContext(projectFlag: projectFlag, envFlag: envFlag, using: workspace)
    }
}

/// Resolves a secret value from an optional argument. When the argument is
/// omitted or `-`, reads the value from stdin instead so it never appears in
/// shell history or the process argument list.
func resolveSecretValue(_ argument: String?) throws -> String {
    if let argument, argument != "-" { return argument }

    let value: String
    if isatty(STDIN_FILENO) == 1 {
        print("Enter secret value: ", terminator: "")
        var term = termios()
        tcgetattr(STDIN_FILENO, &term)
        var noEcho = term
        noEcho.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &noEcho)
        value = readLine() ?? ""
        tcsetattr(STDIN_FILENO, TCSANOW, &term)
        print()
    } else {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        var piped = String(data: data, encoding: .utf8) ?? ""
        if piped.hasSuffix("\n") { piped.removeLast() }
        value = piped
    }

    guard !value.isEmpty else {
        print("Error: secret value cannot be empty.")
        throw ExitCode.failure
    }
    return value
}
