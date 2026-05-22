import ArgumentParser
import LokaliteCore

struct MCPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start the MCP stdio server for agent and Claude Code integration."
    )

    @Flag(name: .long, help: "Expose write tools (add_secret, set_secret, delete_secret). Off by default.")
    var readWrite = false

    func run() throws {
        let server = MCPServer(allowWrites: readWrite)
        try server.run()
    }
}
