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
