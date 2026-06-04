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

    @Flag(help: "Export as plaintext JSON. Requires confirmation.")
    var plain: Bool = false

    @Option(name: .long, help: "Output format: json (default) or env.")
    var format: String = "json"

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: env)

        if format == "env" {
            let secrets = try withWorkspace { workspace in
                try workspace.list(context: ctx)
            }
            let lines = secrets.map { envLine($0.name, $0.value) }.joined(separator: "\n")
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
            data = try withVault { try $0.export(projectId: ctx.project.id, passphrase: nil) }
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

    private func envLine(_ key: String, _ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(key)=\"\(escaped)\""
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
