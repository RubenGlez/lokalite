import ArgumentParser
import Foundation
import LokaliteCore

struct CopyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "copy",
        abstract: "Copy a secret value to the clipboard."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let secret = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try workspace.get(name: name, context: ctx, accessSource: .cli)
        }
        try copyToPasteboard(secret.value)
        print("Copied \(name) to clipboard.")
    }

    private func copyToPasteboard(_ value: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe
        try process.run()
        pipe.fileHandleForWriting.write(Data(value.utf8))
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
    }
}
