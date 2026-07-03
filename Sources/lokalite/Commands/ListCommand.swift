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

    @Option(name: .shortAndLong, help: "Filter secrets by name or description (case-insensitive substring).")
    var search: String?

    func run() throws {
        // Metadata only — `list` prints names/descriptions, so decrypting every
        // value (as `workspace.list` does) is needless work in the CLI process (L1).
        let secrets = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try workspace.listInfo(context: ctx)
        }
        if secrets.isEmpty {
            print("No secrets found.")
            return
        }
        let matches: [SecretInfo]
        if let term = search {
            let needle = term.lowercased()
            matches = secrets.filter { secret in
                secret.name.lowercased().contains(needle)
                    || (secret.description?.lowercased().contains(needle) ?? false)
            }
            if matches.isEmpty {
                print("No secrets match \"\(term)\".")
                return
            }
        } else {
            matches = secrets
        }
        for secret in matches {
            print(secret.name)
        }
    }
}
