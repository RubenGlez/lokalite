import ArgumentParser
import Foundation
import LokaliteCore

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a command with secrets injected as environment variables."
    )

    @Option(name: .shortAndLong, help: "Comma-separated secret names to inject. Defaults to all secrets.")
    var keys: String?

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    @Flag(name: .long, help: "Only resolve lokalite:// references in the environment; skip the bulk injection of project secrets.")
    var refsOnly = false

    @Flag(name: .long, help: "Resolve lokalite:// references in-process instead of brokering through the Lokalite app. Use for CI/headless; approval-tier secrets are then unavailable to AI agents.")
    var local = false

    @Flag(name: [.customShort("h"), .customLong("help")], help: .hidden)
    var help: Bool = false

    @Argument(parsing: .captureForPassthrough, help: "Command and arguments to run.")
    var command: [String]

    func run() throws {
        if help {
            print(Self.helpMessage())
            return
        }

        guard !command.isEmpty else {
            print("Error: no command specified.")
            throw ExitCode.failure
        }

        // Parse lokalite:// references up front: a malformed reference aborts
        // before any vault access and before the child spawns (fail closed,
        // ADR 0017).
        let inherited = ProcessInfo.processInfo.environment
        let references: [(variable: String, reference: SecretReference)]
        do {
            references = try SecretReference.scan(inherited)
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        var environment = inherited

        if !refsOnly {
            let secrets = try withWorkspace { workspace -> [Secret] in
                let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
                if let keys {
                    let names = keys.split(separator: ",").map(String.init)
                    return try workspace.secrets(named: names, context: ctx, accessSource: .cli)
                }
                return try workspace.secrets(named: nil, context: ctx, accessSource: .cli)
            }
            for secret in secrets {
                environment[secret.name] = secret.value
            }
        }

        if !references.isEmpty {
            // Applied after bulk injection so a resolved reference wins over a
            // bulk-injected secret of the same name.
            do {
                environment = try resolveReferences(in: environment)
            } catch let error as SecretReferenceSubstitutionError {
                print("Error: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        throw ExitCode(process.terminationStatus)
    }

    /// Substitutes every `lokalite://` reference in `environment` with the
    /// secret's value. Throws `SecretReferenceSubstitutionError` (naming the
    /// env var and the reference, never a value) on the first failure.
    private func resolveReferences(in environment: [String: String]) throws -> [String: String] {
        let workspace = SecretWorkspace(vault: try referenceVaultService())
        try workspace.unlock()
        let workingDirectory = FileManager.default.currentDirectoryPath
        // `--local` bypasses the daemon chokepoint, so mirror its agent policy
        // here (ADR 0017): blocked and approval-requiring secrets fail closed
        // when an AI agent is in the calling process tree — the CLI cannot
        // broker the consent prompt. A human resolves without a prompt.
        let detectedAgent = local ? AgentDetection.detectAgent() : nil

        return try SecretReference.substitute(in: environment) { reference in
            let context = try workspace.resolveContext(
                projectName: reference.projectName,
                environmentName: reference.environmentName,
                workingDirectory: workingDirectory
            )
            let secret = try workspace.get(name: reference.key, context: context, accessSource: .cli)
            if let agent = detectedAgent {
                if secret.agentAccess.blocksAgents {
                    throw ReferencePolicyError(message: "secret '\(secret.name)' is off-limits to AI agents (\(agent) detected).")
                }
                if secret.agentAccess.requiresApprovalForAgents {
                    throw ReferencePolicyError(message: "secret '\(secret.name)' requires approval to release to an AI agent (\(agent) detected), which --local cannot broker. Drop --local to resolve through the Lokalite app.")
                }
            }
            return secret.value
        }
    }

    /// Default: resolve references through the Lokalite app (the vault daemon)
    /// so agent-access tiers, consent prompts, and the activity log are
    /// enforced at the chokepoint (ADR 0014/0017) — same wiring as
    /// `MCPCommand.vaultService()`. `--local` opts into in-process resolution
    /// for headless/CI.
    private func referenceVaultService() throws -> VaultService {
        if local { return Vault.shared }
        let socketPath = VaultConfiguration.daemonSocketURL.path
        do {
            try VaultDaemonLauncher.ensureRunning(socketPath: socketPath)
        } catch {
            throw ValidationError("Could not reach or start the Lokalite app (the vault daemon): \(error.localizedDescription) Open Lokalite, or run with --local to resolve references in-process.")
        }
        return RemoteVaultService(transport: VaultSocketClient(socketPath: socketPath).send)
    }
}

/// A `--local` agent-policy refusal for one reference; the surrounding
/// substitution wraps it with the env var name and reference text.
private struct ReferencePolicyError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
