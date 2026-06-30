import ArgumentParser
import LokaliteCore

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print a secret value to stdout."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let secret = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try workspace.get(name: name, context: ctx, accessSource: .cli)
        }
        try enforceAgentRevealPolicy(secret)
        print(secret.value, terminator: "")
    }
}
