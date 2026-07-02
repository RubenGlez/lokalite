import ArgumentParser
import Foundation
import LokaliteCore

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export secrets. Encrypted by default."
    )

    @Option(name: .shortAndLong, help: "Output file path. Defaults to stdout.")
    var output: String?

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    @Flag(help: "Export as plaintext. Requires confirmation.")
    var plain: Bool = false

    @Option(name: .long, help: "Output format: json (default) or env.")
    var format: String = "json"

    @Flag(name: .long, help: "Allow running even when an AI agent is detected in the calling process tree.")
    var allowAgent = false

    func run() throws {
        // Plaintext export (env format or --plain) reveals raw values; guard it
        // against AI-agent callers. Encrypted export stays passphrase-protected.
        if format == "env" || plain {
            try ensureNotAgentExfil(allowAgent: allowAgent, action: "export secret values as plaintext")
        }

        let ctx = try resolveContext(projectFlag: project, envFlag: env)

        if format == "env" {
            print("Warning: env format writes secret values unencrypted.")
            print("Type 'yes' to confirm: ", terminator: "")
            guard readLine() == "yes" else {
                print("Cancelled.")
                return
            }
            // Approval-tier secrets are excluded from plaintext exports
            // (ADR 0018); the skip notice goes to stderr, never the env output.
            let (secrets, skipped) = try withWorkspace { workspace in
                try bulkRevealSecrets(named: nil, context: ctx, workspace: workspace, accessSource: nil)
            }
            printApprovalTierSkipNotice(skipped)
            let lines = secrets.map { EnvFileFormat.line(name: $0.name, value: $0.value) }.joined(separator: "\n")
            if let outputPath = output {
                try (lines + "\n").write(toFile: outputPath, atomically: true, encoding: .utf8)
                print("Exported to \(outputPath).")
            } else {
                print(lines)
            }
            return
        }

        let data: Data

        if plain {
            print("Warning: plain export writes secret values unencrypted.")
            print("Type 'yes' to confirm: ", terminator: "")
            guard readLine() == "yes" else {
                print("Cancelled.")
                return
            }
            // Plain export excludes approval-tier secrets (ADR 0018); the
            // encrypted (passphrase) export below is unchanged and keeps them.
            let result = try withVault { try $0.exportExcludingApprovalTier(projectId: ctx.project.id, passphrase: nil) }
            printApprovalTierSkipNotice(result.skippedNames)
            data = result.data
        } else {
            print("Enter passphrase for encrypted export: ", terminator: "")
            let passphrase = readPassphrase()
            guard !passphrase.isEmpty else {
                print("Passphrase cannot be empty.")
                return
            }
            data = try withVault { try $0.export(projectId: ctx.project.id, passphrase: passphrase) }
        }

        if let outputPath = output {
            try data.write(to: URL(fileURLWithPath: outputPath))
            print("Exported to \(outputPath).")
        } else {
            if plain {
                print(String(data: data, encoding: .utf8) ?? "")
            } else {
                print(data.base64EncodedString())
            }
        }
    }

    private func readPassphrase() -> String {
        var term = termios()
        tcgetattr(STDIN_FILENO, &term)
        var noEcho = term
        noEcho.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &noEcho)
        let passphrase = readLine() ?? ""
        tcsetattr(STDIN_FILENO, TCSANOW, &term)
        print()
        return passphrase
    }
}
