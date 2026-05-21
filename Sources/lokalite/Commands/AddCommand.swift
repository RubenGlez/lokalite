import ArgumentParser
import LokaliteCore

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new secret."
    )

    @Argument(help: "Secret name (e.g. OPENAI_API_KEY).")
    var name: String

    @Argument(help: "Secret value.")
    var value: String

    @Option(name: .shortAndLong, help: "Optional description.")
    var description: String?

    @Option(name: .shortAndLong, help: "Comma-separated tags (e.g. ai,cloud).")
    var tags: String?

    func run() throws {
        let tagList = tags.map { $0.split(separator: ",").map(String.init) } ?? []
        let secret = try withVault { vault in
            try vault.add(name: name, value: value, description: description, tags: tagList)
        }
        print("Added \(secret.name).")
    }
}
