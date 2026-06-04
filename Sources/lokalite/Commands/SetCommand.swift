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
        try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            _ = try workspace.set(name: name, value: value, context: ctx)
        }
        print("Updated \(name).")
    }
}
