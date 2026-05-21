import ArgumentParser
import LokaliteCore

struct DeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a secret."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt.")
    var force: Bool = false

    func run() throws {
        if !force {
            print("Delete '\(name)'? This cannot be undone. [y/N] ", terminator: "")
            let input = readLine() ?? ""
            guard input.lowercased() == "y" else {
                print("Cancelled.")
                return
            }
        }
        try withVault { try $0.delete(name: name) }
        print("Deleted \(name).")
    }
}
