import ArgumentParser
import LokaliteCore

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Update the value of an existing secret."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Argument(help: "New value.")
    var value: String

    func run() throws {
        try withVault { vault in
            _ = try vault.set(name: name, value: value)
        }
        print("Updated \(name).")
    }
}
