import Foundation

/// MCP clients Lokalite can register itself with. Shared by `lokalite install`
/// and the app's sidebar, which registers per client without a terminal.
public enum MCPClient: String, CaseIterable, Sendable {
    case claude
    case claudeDesktop = "claude-desktop"
    case cursor
    case windsurf

    public var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .claudeDesktop: return "Claude Desktop"
        case .cursor: return "Cursor"
        case .windsurf: return "Windsurf"
        }
    }

    // All clients use the same `{ "mcpServers": { ... } }` schema; only the
    // config file location differs.
    public func configURL(home: URL) -> URL {
        switch self {
        case .claude:   return home.appendingPathComponent(".claude.json")
        case .claudeDesktop:
            return home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        case .cursor:   return home.appendingPathComponent(".cursor/mcp.json")
        case .windsurf: return home.appendingPathComponent(".codeium/windsurf/mcp_config.json")
        }
    }

    /// Whether this client's config already has a `lokalite` server entry.
    public func isRegistered(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let servers = Self.readJSON(at: configURL(home: home))["mcpServers"] as? [String: Any]
        return servers?["lokalite"] != nil
    }

    /// Adds (or overwrites) the `lokalite` server entry, keeping every other key
    /// in the client's config. `command` is what the client will spawn: `lokalite`
    /// relies on the client's PATH; an absolute path doesn't.
    @discardableResult
    public func register(
        command: String = "lokalite",
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        let url = configURL(home: home)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var config = Self.readJSON(at: url)
        var servers = config["mcpServers"] as? [String: Any] ?? [:]
        servers["lokalite"] = ["command": command, "args": ["mcp"]]
        config["mcpServers"] = servers
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func readJSON(at url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }
}
