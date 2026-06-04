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

struct VaultContext {
    let project: Project
    let environmentName: String?
}

func resolveContext(projectFlag: String?, envFlag: String?) throws -> VaultContext {
    let projectName = projectFlag ?? ProcessInfo.processInfo.environment["LOKALITE_PROJECT"]
    let envName = envFlag ?? ProcessInfo.processInfo.environment["LOKALITE_ENV"]

    return try withVault { vault in
        let project = try vault.resolveProject(
            name: projectName,
            workingDirectory: FileManager.default.currentDirectoryPath
        )
        let resolvedEnv = envName ?? project.activeEnvironment
        return VaultContext(project: project, environmentName: resolvedEnv)
    }
}
