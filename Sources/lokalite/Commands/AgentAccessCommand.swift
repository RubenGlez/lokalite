import ArgumentParser
import LokaliteCore

struct AgentAccessCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-access",
        abstract: "Control whether AI agents can read a secret via MCP."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Argument(help: "allow or block.")
    var state: State

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    enum State: String, ExpressibleByArgument {
        case allow, block
        var policy: AgentAccessPolicy { self == .block ? .blocked : .allowed }
    }

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: nil)
        try withVault { vault in
            try vault.setAgentAccess(name: name, projectId: ctx.project.id, policy: state.policy)
        }
        let status = state == .block ? "off-limits to" : "readable by"
        print("Secret '\(name)' is now \(status) AI agents.")
    }
}
