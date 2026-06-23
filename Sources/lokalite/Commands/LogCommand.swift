import ArgumentParser
import Foundation
import LokaliteCore

struct LogCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "log",
        abstract: "Show the secret access log."
    )

    @Option(name: .shortAndLong, help: "Maximum number of entries to show.")
    var limit: Int = 50

    @Option(name: .shortAndLong, help: "Filter by source: app, cli, or mcp.")
    var source: String?

    func run() throws {
        let filter = try source.map { raw -> ActivityLogEntry.AccessSource in
            guard let value = ActivityLogEntry.AccessSource(rawValue: raw.lowercased()) else {
                print("Error: invalid source '\(raw)'. Use app, cli, or mcp.")
                throw ExitCode.failure
            }
            return value
        }

        var entries = try withVault { try $0.listActivity(limit: limit) }
        if let filter {
            entries = entries.filter { $0.source == filter }
        }

        if entries.isEmpty {
            print("No activity recorded yet.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for entry in entries {
            let timestamp = formatter.string(from: entry.accessedAt)
            let scope = "\(entry.projectName)/\(entry.environmentName)"
            print("\(timestamp)  \(entry.source.rawValue.padding(toLength: 3, withPad: " ", startingAt: 0))  \(scope)  \(entry.secretName)")
        }
    }
}
