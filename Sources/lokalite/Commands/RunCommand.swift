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

    @Argument(parsing: .captureForPassthrough, help: "Command and arguments to run.")
    var command: [String]

    func run() throws {
        guard !command.isEmpty else {
            print("Error: no command specified.")
            throw ExitCode.failure
        }

        let secrets = try withVault { vault -> [Secret] in
            if let keys {
                let names = keys.split(separator: ",").map(String.init)
                return try names.map { try vault.get(name: $0) }
            }
            return try vault.list()
        }

        var env = ProcessInfo.processInfo.environment
        for secret in secrets {
            env[secret.name] = secret.value
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.environment = env
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        throw ExitCode(process.terminationStatus)
    }
}
