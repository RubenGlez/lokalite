import ArgumentParser
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
        ]
    )
}

// Shared helper used by all commands.
func withVault<T>(_ body: (Vault) throws -> T) throws -> T {
    let vault = Vault.shared
    try vault.unlock()
    return try body(vault)
}
