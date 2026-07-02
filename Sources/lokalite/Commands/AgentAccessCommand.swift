import ArgumentParser
import LokaliteCore

struct AgentAccessCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-access",
        abstract: "Control whether AI agents can read a secret via MCP."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Argument(help: "allow, block, approve (consent once per session), or strict (consent on every read).")
    var state: State

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    enum State: String, ExpressibleByArgument {
        case allow, block, approve, strict
        var policy: AgentAccessPolicy {
            switch self {
            case .allow: return .allowed
            case .block: return .blocked
            case .approve: return .requiresApproval
            case .strict: return .strict
            }
        }
    }

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: nil)
        try withVault { vault in
            try vault.setAgentAccess(name: name, projectId: ctx.project.id, policy: state.policy)
        }
        let status: String
        switch state {
        case .block: status = "off-limits to AI agents"
        case .approve: status = "released only after Touch ID approval, whoever asks"
        case .strict: status = "released only after Touch ID approval on every read, whoever asks"
        case .allow: status = "readable by AI agents"
        }
        print("Secret '\(name)' is now \(status).")
    }
}
