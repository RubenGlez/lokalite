import ArgumentParser
import Foundation
import LokaliteCore

struct ImportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import secrets from a .env file."
    )

    @Argument(help: "Path to .env file.")
    var file: String

    @Flag(name: .long, help: "Overwrite existing secrets instead of skipping them.")
    var overwrite = false

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let pairs = EnvFileFormat.parse(content)

        guard !pairs.isEmpty else {
            print("No key=value pairs found in \(file).")
            return
        }

        var added = 0, updated = 0, skipped = 0

        try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            for (key, value) in pairs {
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
        print(parts.joined(separator: ", ") + ".")
    }
}
