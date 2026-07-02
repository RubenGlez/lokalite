import ArgumentParser
import LokaliteCore

struct MCPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start the MCP stdio server for agent and Claude Code integration."
    )

    @Flag(name: .long, help: "Expose write tools (add_secret, set_secret, delete_secret). Off by default.")
    var readWrite = false

    @Flag(name: .long, help: "Open the vault in-process instead of brokering through the Lokalite app. Use for CI/headless; the secret value then passes through this process.")
    var local = false

    func run() throws {
        let server = MCPServer(allowWrites: readWrite, vault: try vaultService(), daemonBacked: !local)
        try server.run()
    }

    private func vaultService() throws -> VaultService {
        // Default: broker through the Lokalite app so this process never holds the
        // vault key (ADR 0014). `--local` opts back into in-process access.
        if local { return Vault.shared }
        let socketPath = VaultConfiguration.daemonSocketURL.path
        do {
            try VaultDaemonLauncher.ensureRunning(socketPath: socketPath)
        } catch {
            throw ValidationError("Could not reach or start the Lokalite app (the vault daemon): \(error.localizedDescription) Open Lokalite, or run with --local to open the vault in-process.")
        }
        return RemoteVaultService(transport: Self.socketClient(socketPath: socketPath).send)
    }

    /// The daemon client for the MCP server, stamped with a tighten-only agent
    /// hint (ADR 0018). The MCP server fronts agents by definition, so the hint
    /// is NEVER nil: self-detection's token when it fires, the literal "agent"
    /// otherwise — the daemon enforces agent policy even on a detection miss.
    static func socketClient(socketPath: String, detected: String? = AgentDetection.detectAgent()) -> VaultSocketClient {
        VaultSocketClient(socketPath: socketPath, agentContext: detected ?? "agent")
    }
}
