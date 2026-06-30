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

/// Enforces a secret's per-secret agent policy on the CLI reveal paths (`get`,
/// `copy`) when an AI agent is detected in the calling tree (ADR 0014) — the same
/// policy the MCP and daemon enforce. The value has already been fetched but is
/// never printed. `blocked` secrets are refused outright; `requiresApproval`
/// secrets are also refused here because the CLI cannot broker the consent prompt
/// (only the app daemon can) — the agent should use the MCP `get_secret` path.
func enforceAgentRevealPolicy(_ secret: Secret) throws {
    guard let agent = AgentDetection.detectAgent() else { return }
    if secret.agentAccess.blocksAgents {
        print("Secret '\(secret.name)' is off-limits to AI agents (\(agent) detected); refusing to reveal it.")
        print("Run `lokalite agent-access \(secret.name) allow` if this should be readable by agents.")
        throw ExitCode.failure
    }
    if secret.agentAccess.requiresApprovalForAgents {
        print("Secret '\(secret.name)' requires per-read approval (\(agent) detected); refusing to reveal it on the CLI.")
        print("Approval prompts are shown only through the Lokalite app's MCP broker — use the MCP `get_secret` tool, or run `lokalite agent-access \(secret.name) allow` to remove the restriction.")
        throw ExitCode.failure
    }
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
