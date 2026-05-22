import ArgumentParser
import LokaliteCore

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Update the value of an existing secret."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Argument(help: "New value.")
    var value: String

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: env)
        try withVault { vault in
            _ = try vault.set(name: name, value: value,
                              projectId: ctx.project.id, environmentName: ctx.environmentName)
        }
        print("Updated \(name).")
    }
}
