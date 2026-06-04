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
        let secrets = try withWorkspace { workspace -> [Secret] in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            if let keys {
                let names = keys.split(separator: ",").map(String.init)
                return try workspace.secrets(named: names, context: ctx, accessSource: .cli)
            }
            return try workspace.secrets(named: nil, context: ctx, accessSource: .cli)
        }
        for secret in secrets {
            let escaped = secret.value.replacingOccurrences(of: "'", with: "'\\''")
            print("export \(secret.name)='\(escaped)'")
        }
    }
}
