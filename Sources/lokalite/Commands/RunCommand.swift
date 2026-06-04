import ArgumentParser
import Foundation
import LokaliteCore

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a command with secrets injected as environment variables."
    )

    @Option(name: .shortAndLong, help: "Comma-separated secret names to inject. Defaults to all secrets.")
    var keys: String?

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    @Flag(name: [.customShort("h"), .customLong("help")], help: .hidden)
    var help: Bool = false

    @Argument(parsing: .captureForPassthrough, help: "Command and arguments to run.")
    var command: [String]

    func run() throws {
        if help {
            print(Self.helpMessage())
            return
        }

        guard !command.isEmpty else {
            print("Error: no command specified.")
            throw ExitCode.failure
        }

        let secrets = try withWorkspace { workspace -> [Secret] in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            if let keys {
                let names = keys.split(separator: ",").map(String.init)
                return try workspace.secrets(named: names, context: ctx, accessSource: .cli)
            }
            return try workspace.secrets(named: nil, context: ctx, accessSource: .cli)
        }

        var environment = ProcessInfo.processInfo.environment
        for secret in secrets {
            environment[secret.name] = secret.value
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        throw ExitCode(process.terminationStatus)
    }
}
