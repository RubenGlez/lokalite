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
        // Approval-tier secrets are brokered through the daemon (Touch ID for
        // every caller, ADR 0018); everything else stays in-process.
        let secret = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try CLIReveal.secret(named: name, in: workspace, context: ctx)
        }
        try enforceAgentRevealPolicy(secret)
        print(secret.value, terminator: "")
    }
}
