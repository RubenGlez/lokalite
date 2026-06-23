import ArgumentParser
import Foundation
import LokaliteCore

@main
struct LokaliteCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lokalite",
        abstract: "A local-first secrets workspace for developers.",
        subcommands: [
            AddCommand.self,
            GetCommand.self,
            SetCommand.self,
            DeleteCommand.self,
            CopyCommand.self,
            ListCommand.self,
            ExportCommand.self,
            RunCommand.self,
            ProjectCommand.self,
            EnvCommand.self,
            MCPCommand.self,
            InstallCommand.self,
            ImportCommand.self,
            BackupCommand.self,
            RestoreCommand.self,
            ShellCommand.self,
            StatusCommand.self,
            InitCommand.self,
            SeedCommand.self,
        ]
    )
}

// MARK: - Shared helpers

func withVault<T>(_ body: (Vault) throws -> T) throws -> T {
    let vault = Vault.shared
    try vault.unlock()
    return try body(vault)
}

func withWorkspace<T>(_ body: (SecretWorkspace) throws -> T) throws -> T {
    let workspace = SecretWorkspace()
    try workspace.unlock()
    return try body(workspace)
}

func resolveContext(
    projectFlag: String?,
    envFlag: String?,
    using workspace: SecretWorkspace
) throws -> SecretWorkspaceContext {
    let projectName = projectFlag ?? ProcessInfo.processInfo.environment["LOKALITE_PROJECT"]
    let envName = envFlag ?? ProcessInfo.processInfo.environment["LOKALITE_ENV"]

    return try workspace.resolveContext(
        projectName: projectName,
        environmentName: envName,
        workingDirectory: FileManager.default.currentDirectoryPath
    )
}

func resolveContext(projectFlag: String?, envFlag: String?) throws -> SecretWorkspaceContext {
    try withWorkspace { workspace in
        try resolveContext(projectFlag: projectFlag, envFlag: envFlag, using: workspace)
    }
}

/// Resolves a secret value from an optional argument. When the argument is
/// omitted or `-`, reads the value from stdin instead so it never appears in
/// shell history or the process argument list.
func resolveSecretValue(_ argument: String?) throws -> String {
    if let argument, argument != "-" { return argument }

    let value: String
    if isatty(STDIN_FILENO) == 1 {
        print("Enter secret value: ", terminator: "")
        var term = termios()
        tcgetattr(STDIN_FILENO, &term)
        var noEcho = term
        noEcho.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &noEcho)
        value = readLine() ?? ""
        tcsetattr(STDIN_FILENO, TCSANOW, &term)
        print()
    } else {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        var piped = String(data: data, encoding: .utf8) ?? ""
        if piped.hasSuffix("\n") { piped.removeLast() }
        value = piped
    }

    guard !value.isEmpty else {
        print("Error: secret value cannot be empty.")
        throw ExitCode.failure
    }
    return value
}
