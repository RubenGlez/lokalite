import ArgumentParser
import Foundation
import LokaliteCore

struct RestoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Restore secrets from an encrypted backup."
    )

    @Argument(help: "Path to the backup file.")
    var path: String

    @Flag(name: .long, help: "Overwrite existing secrets instead of skipping them.")
    var overwrite = false

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let envelope: Data
        do {
            envelope = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            print("Could not read backup file at \(path).")
            throw ExitCode.failure
        }

        print("Enter passphrase to decrypt the backup: ", terminator: "")
        let passphrase = readPassphrase()
        guard !passphrase.isEmpty else {
            print("Passphrase cannot be empty.")
            throw ExitCode.failure
        }

        let secrets: [String: String]
        do {
            secrets = try withVault { try $0.decryptExport(envelope, passphrase: passphrase) }
        } catch {
            print("Restore failed: wrong passphrase or the file is not a valid encrypted backup.")
            throw ExitCode.failure
        }

        guard !secrets.isEmpty else {
            print("Backup contained no secrets.")
            return
        }

        var added = 0, updated = 0, skipped = 0

        try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            for (key, value) in secrets {
                do {
                    _ = try workspace.add(name: key, value: value, context: ctx)
                    added += 1
                } catch VaultError.secretAlreadyExists {
                    if overwrite {
                        _ = try workspace.set(name: key, value: value, context: ctx)
                        updated += 1
                    } else {
                        skipped += 1
                    }
                }
            }
        }

        var parts: [String] = []
        if added > 0   { parts.append("\(added) added") }
        if updated > 0 { parts.append("\(updated) updated") }
        if skipped > 0 { parts.append("\(skipped) skipped (already exist — use --overwrite to replace)") }
        print("Restored: " + parts.joined(separator: ", ") + ".")
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
