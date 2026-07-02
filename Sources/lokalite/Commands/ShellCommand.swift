import ArgumentParser
import Foundation
import LokaliteCore

// Security note: `eval $(lokalite shell)` injects secrets into the current shell
// environment, making them visible to all child processes and `env` output for
// the duration of the session. Use `lokalite run` to scope secrets to a single
// subprocess instead.
struct ShellCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shell",
        abstract: "Print export statements to inject secrets into the current shell."
    )

    @Option(name: .shortAndLong, help: "Comma-separated secret names to export. Defaults to all.")
    var keys: String?

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    @Flag(name: .long, help: "Allow running even when an AI agent is detected in the calling process tree.")
    var allowAgent = false

    func run() throws {
        try ensureNotAgentExfil(allowAgent: allowAgent, action: "print secret values as shell exports")

        // Approval-tier secrets are excluded from bulk reveals (ADR 0018);
        // the skip notice goes to stderr because stdout is eval'd.
        let (secrets, skipped) = try withWorkspace { workspace -> ([Secret], [String]) in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            let names = keys.map { $0.split(separator: ",").map(String.init) }
            return try bulkRevealSecrets(named: names, context: ctx, workspace: workspace)
        }
        printApprovalTierSkipNotice(skipped)
        for secret in secrets {
            let escaped = secret.value.replacingOccurrences(of: "'", with: "'\\''")
            print("export \(secret.name)='\(escaped)'")
        }
    }
}
