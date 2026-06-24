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

        let summary = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try workspace.importEnv(pairs: pairs, context: ctx, overwrite: overwrite)
        }

        print(importSummaryLine(summary))
    }
}
