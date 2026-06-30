import ArgumentParser
import LokaliteCore

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new secret."
    )

    @Argument(help: "Secret name (e.g. OPENAI_API_KEY).")
    var name: String

    @Argument(help: "Secret value. Omit or pass '-' to read from stdin (keeps the value out of shell history).")
    var value: String?

    @Option(name: .shortAndLong, help: "Optional description.")
    var description: String?

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let resolvedValue = try resolveSecretValue(value)
        let secret = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try workspace.add(name: name, value: resolvedValue, description: description, context: ctx, accessSource: .cli)
        }
        print("Added \(secret.name).")
    }
}
