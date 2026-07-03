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
            let tier = try workspace.listInfo(context: ctx).first { $0.name == name }?.agentAccess ?? .allowed
            try CLIWrite.perform(
                name: name, tier: tier, context: ctx,
                daemonWrite: { remote, ctx in try remote.delete(name: name, context: ctx, accessSource: .cli) },
                inProcessWrite: { try workspace.delete(name: name, context: ctx, accessSource: .cli) }
            )
        }
        print("Deleted \(name).")
    }
}
