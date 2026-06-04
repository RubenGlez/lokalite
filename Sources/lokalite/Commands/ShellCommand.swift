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

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: env)
        let secrets = try withVault { vault -> [Secret] in
            if let keys {
                let names = keys.split(separator: ",").map(String.init)
                return try names.map {
                    try vault.get(name: $0, projectId: ctx.project.id,
                                  environmentName: ctx.environmentName)
                }
            }
            return try vault.list(projectId: ctx.project.id, environmentName: ctx.environmentName)
        }
        for secret in secrets {
            Vault.shared.logAccess(secretName: secret.name, projectName: ctx.project.name,
                                   environmentName: ctx.environmentName ?? "default", source: .cli)
            let escaped = secret.value.replacingOccurrences(of: "'", with: "'\\''")
            print("export \(secret.name)='\(escaped)'")
        }
    }
}
