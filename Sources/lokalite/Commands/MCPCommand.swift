import ArgumentParser
import LokaliteCore

struct MCPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start the MCP stdio server for agent and Claude Code integration."
    )

    @Flag(name: .long, help: "Expose write tools (add_secret, set_secret, delete_secret). Off by default.")
    var readWrite = false

    @Flag(name: .long, help: "Broker vault access through the running Lokalite app instead of opening the vault in-process; auto-launches the app if needed (ADR 0014). Opt-in while the daemon is being rolled out.")
    var remote = false

    func run() throws {
        let server = MCPServer(allowWrites: readWrite, vault: try vaultService())
        try server.run()
    }

    private func vaultService() throws -> VaultService {
        guard remote else { return Vault.shared }
        let socketPath = VaultConfiguration.daemonSocketURL.path
        try VaultDaemonLauncher.ensureRunning(socketPath: socketPath)
        return RemoteVaultService(transport: VaultSocketClient(socketPath: socketPath).send)
    }
}
