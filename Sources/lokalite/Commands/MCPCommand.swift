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
        return RemoteVaultService(transport: VaultSocketClient(socketPath: socketPath).send)
    }
}
