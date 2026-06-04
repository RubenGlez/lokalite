import ArgumentParser
import LokaliteCore

struct DeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a secret."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt.")
    var force: Bool = false

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: nil)
        if !force {
            print("Delete '\(name)'? This cannot be undone. [y/N] ", terminator: "")
            guard readLine()?.lowercased() == "y" else {
                print("Cancelled.")
                return
            }
        }
        try withWorkspace { workspace in
            try workspace.delete(name: name, context: ctx)
        }
        print("Deleted \(name).")
    }
}
