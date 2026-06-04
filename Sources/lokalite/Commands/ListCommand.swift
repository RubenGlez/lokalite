import ArgumentParser
import LokaliteCore

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List secrets in a project."
    )

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let secrets = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try workspace.list(context: ctx)
        }
        if secrets.isEmpty {
            print("No secrets found.")
            return
        }
        for secret in secrets {
            print(secret.name)
        }
    }
}
