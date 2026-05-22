import ArgumentParser
import Foundation

struct InstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install the lokalite binary to PATH and register it as an MCP server."
    )

    @Option(name: .long, help: "Directory to install the binary into.")
    var binDir: String = "/usr/local/bin"

    @Flag(name: .long, help: "Skip writing the Claude Code MCP config.")
    var skipMcp = false

    func run() throws {
        let destination = URL(fileURLWithPath: binDir)
            .appendingPathComponent("lokalite")

        try installBinary(to: destination)
        print("✓ Binary installed to \(destination.path)")

        if !skipMcp {
            let configURL = try registerMCPServer()
            print("✓ MCP server registered in \(configURL.abbreviatingWithTildeInPath)")
        }

        print("\nRestart Claude Code to pick up the new server.")
    }

    // MARK: - Binary installation

    private func installBinary(to destination: URL) throws {
        let source = resolvedBinaryURL()
        let fm = FileManager.default

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            try fm.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destination.path
            )
        } catch CocoaError.fileWriteNoPermission {
            throw InstallError.permissionDenied(destination.path)
        }
    }

    private func resolvedBinaryURL() -> URL {
        URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    }

    // MARK: - MCP config

    @discardableResult
    private func registerMCPServer() throws -> URL {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")

        var config = readJSON(at: configURL)
        var mcpServers = config["mcpServers"] as? [String: Any] ?? [:]
        mcpServers["lokalite"] = ["command": "lokalite", "args": ["mcp"]]
        config["mcpServers"] = mcpServers

        let data = try JSONSerialization.data(
            withJSONObject: config,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: configURL, options: .atomic)
        return configURL
    }

    private func readJSON(at url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }
}

// MARK: - Errors

private enum InstallError: LocalizedError {
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return """
            Permission denied writing to \(path).
            Run with sudo, or choose a user-writable directory:
              sudo .build/release/lokalite install
              lokalite install --bin-dir ~/.local/bin
            """
        }
    }
}

// MARK: - URL helper

private extension URL {
    var abbreviatingWithTildeInPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
