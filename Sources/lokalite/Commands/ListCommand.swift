import ArgumentParser
import LokaliteCore

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List secret names."
    )

    @Option(name: .shortAndLong, help: "Filter by tag.")
    var tag: String?

    func run() throws {
        let secrets = try withVault { try $0.list(tag: tag) }
        if secrets.isEmpty {
            print("No secrets found.")
            return
        }
        for secret in secrets {
            let tagSuffix = secret.tags.isEmpty ? "" : "  [\(secret.tags.joined(separator: ", "))]"
            print(secret.name + tagSuffix)
        }
    }
}
