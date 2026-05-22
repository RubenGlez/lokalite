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
        let ctx = try resolveContext(projectFlag: project, envFlag: env)
        let secret = try withVault { vault in
            try vault.get(name: name, projectId: ctx.project.id, environmentName: ctx.environmentName)
        }
        print(secret.value, terminator: "")
    }
}
