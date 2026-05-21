import ArgumentParser
import LokaliteCore

struct MCPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start the MCP stdio server for agent and Claude Code integration."
    )

    func run() throws {
        let server = MCPServer()
        try server.run()
    }
}
