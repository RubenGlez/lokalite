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
        let ctx = try resolveContext(projectFlag: project, envFlag: env)
        let secret = try withVault { vault in
            let s = try vault.get(name: name, projectId: ctx.project.id, environmentName: ctx.environmentName)
            vault.logAccess(secretName: s.name, projectName: ctx.project.name,
                            environmentName: ctx.environmentName ?? "default", source: .cli)
            return s
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
