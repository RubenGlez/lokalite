import ArgumentParser
import LokaliteCore

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print a secret value to stdout."
    )

    @Argument(help: "Secret name.")
    var name: String

    func run() throws {
        let secret = try withVault { try $0.get(name: name) }
        print(secret.value, terminator: "")
    }
}
