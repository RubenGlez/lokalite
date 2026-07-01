import ArgumentParser
import Foundation
import LokaliteCore

/// DLP guard: reads text from stdin, redacts any known secret value, and writes
/// the result to stdout — so an AI agent's output can be filtered before it
/// reaches a model's context or a log (ROADMAP, P0). Exits non-zero when a leak
/// is found so it can gate a pipeline.
struct GuardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "guard",
        abstract: "Redact leaked secret values from piped text (DLP guard for AI agents).",
        discussion: """
        Reads text from stdin, replaces any known secret value with a
        [redacted:NAME] marker, and writes the result to stdout. Exits non-zero
        when a leak is found, so it can gate a pipeline:

            some-agent-command | lokalite guard

        Values are matched across every project and environment in the vault.
        """
    )

    @Flag(name: .long, help: "Suppress all output when a leak is found, instead of passing through redacted text.")
    var block = false

    @Flag(name: .long, help: "Exit 0 even when leaks are found (still redacts or blocks).")
    var noFail = false

    func run() throws {
        let secrets = try withVault { vault in try collectAllSecretValues(vault: vault) }
        let scanner = SecretLeakScanner(secrets: secrets)

        let data = FileHandle.standardInput.readDataToEndOfFile()
        let input = String(data: data, encoding: .utf8) ?? ""
        let result = scanner.scan(input)

        guard result.hasLeaks else {
            FileHandle.standardOutput.write(data)
            return
        }

        if !block {
            FileHandle.standardOutput.write(Data(result.redactedText.utf8))
        }

        let summary = result.findings
            .map { "\($0.secretNames.joined(separator: "|"))×\($0.occurrences)" }
            .joined(separator: ", ")
        let verb = block ? "blocked output" : "redacted output"
        FileHandle.standardError.write(
            Data("lokalite guard: \(verb) — leaked secret values detected: \(summary)\n".utf8)
        )

        if !noFail { throw ExitCode.failure }
    }
}

/// Gathers every secret value across all projects and environments so the DLP
/// guard can recognise any of them in scanned text.
func collectAllSecretValues(vault: Vault) throws -> [(name: String, value: String)] {
    var result: [(name: String, value: String)] = []
    for project in try vault.listProjects() {
        for environment in try vault.listEnvironments(projectId: project.id) {
            let secrets = try vault.list(projectId: project.id, environmentName: environment.name)
            for secret in secrets {
                result.append((secret.name, secret.value))
            }
        }
    }
    return result
}
