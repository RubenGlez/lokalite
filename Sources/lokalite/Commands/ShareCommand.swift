import ArgumentParser
import Foundation
import LokaliteCore

/// End-to-end-encrypted secret sharing (ROADMAP, P1). `share create` writes a
/// passphrase-encrypted `.lok` file with a chosen subset of secrets; the
/// recipient runs `share open` to import them into their own vault. The
/// passphrase travels out of band (Signal, in person, a password manager), so
/// the file alone never exposes the values.
struct ShareCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "share",
        abstract: "Create and open end-to-end-encrypted secret share files (.lok).",
        subcommands: [Create.self, Open.self]
    )

    struct Create: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Write selected secrets to an encrypted .lok share file."
        )

        @Argument(help: "Comma-separated secret names to share. Omit to share every secret in the environment.")
        var names: String?

        @Option(name: .shortAndLong, help: "Output file path. Defaults to a timestamped .lok file.")
        var output: String?

        @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
        var project: String?

        @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
        var env: String?

        func run() throws {
            let pairs = try withWorkspace { workspace -> [String: String] in
                let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
                let requested = names?.split(separator: ",").map(String.init)
                let secrets = try workspace.secrets(named: requested, context: ctx, accessSource: .cli)
                return Dictionary(uniqueKeysWithValues: secrets.map { ($0.name, $0.value) })
            }

            guard !pairs.isEmpty else {
                print("No secrets to share.")
                throw ExitCode.failure
            }

            print("Enter a passphrase to encrypt the share: ", terminator: "")
            let passphrase = promptHiddenLine()
            guard !passphrase.isEmpty else {
                print("Passphrase cannot be empty.")
                throw ExitCode.failure
            }

            let data = try withVault { try $0.encryptSecrets(pairs, passphrase: passphrase) }
            let path = output ?? Self.defaultSharePath()
            try data.write(to: URL(fileURLWithPath: path))

            print("Wrote \(pairs.count) secret(s) to encrypted share \(path).")
            print("Send the file over a channel you trust and share the passphrase separately.")
            print("The recipient opens it with `lokalite share open \((path as NSString).lastPathComponent)`.")
        }

        private static func defaultSharePath() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date())
            let dir = FileManager.default.currentDirectoryPath
            return (dir as NSString).appendingPathComponent("lokalite-share-\(stamp).lok")
        }
    }

    struct Open: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Import secrets from an encrypted .lok share file."
        )

        @Argument(help: "Path to the .lok share file.")
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
                print("Could not read share file at \(path).")
                throw ExitCode.failure
            }

            print("Enter the share passphrase: ", terminator: "")
            let passphrase = promptHiddenLine()
            guard !passphrase.isEmpty else {
                print("Passphrase cannot be empty.")
                throw ExitCode.failure
            }

            let secrets: [String: String]
            do {
                secrets = try withVault { try $0.decryptExport(envelope, passphrase: passphrase) }
            } catch {
                print("Could not open share: wrong passphrase or not a valid Lokalite share file.")
                throw ExitCode.failure
            }

            guard !secrets.isEmpty else {
                print("Share contained no secrets.")
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
            if added > 0 { parts.append("\(added) added") }
            if updated > 0 { parts.append("\(updated) updated") }
            if skipped > 0 { parts.append("\(skipped) skipped (already exist — use --overwrite to replace)") }
            print("Opened share: " + parts.joined(separator: ", ") + ".")
            print("Delete the share file when you're done: rm \(path)")
        }
    }
}
