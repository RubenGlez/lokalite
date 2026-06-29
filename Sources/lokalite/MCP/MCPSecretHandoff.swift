import Foundation

/// Delivers a secret to an agent's shell *environment* without ever placing the
/// raw value in the MCP tool response (and therefore never in the model's
/// context). `get_secret` returns a `source '<path>'` command; the agent runs it
/// in its own shell, the script `export`s the value, then deletes itself.
///
/// The script stays plain shell so `source` can read it, so confidentiality
/// rests on owner-only file permissions (0600 in a 0700 directory), single-use
/// self-deletion on first source, and a short TTL sweep for scripts that are
/// never sourced — not on encrypting the file at rest.
enum MCPSecretHandoff {
    /// How long an unsourced handoff script may linger before it is swept.
    static let ttl: TimeInterval = 120

    private static var root: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("lokalite-mcp", isDirectory: true)
    }

    /// Writes the export script and returns the `source '<path>'` command the
    /// agent must run in its shell to load the secrets into its environment.
    static func write(_ secrets: [(name: String, value: String)]) throws -> String {
        sweepStale()

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let path = root.appendingPathComponent("secret-\(UUID().uuidString).sh")

        var lines = secrets.map { "export \($0.name)='\(escape($0.value))'" }
        lines.append("rm -f -- '\(path.path)'") // single-use: remove self when sourced
        let script = lines.joined(separator: "\n") + "\n"

        guard fileManager.createFile(
            atPath: path.path,
            contents: Data(script.utf8),
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw HandoffError.writeFailed
        }

        return "source '\(path.path)'"
    }

    /// Removes handoff scripts older than `ttl` that were never sourced.
    static func sweepStale() {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-ttl)
        for url in entries {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let created, created < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Escapes a value for single-quoted shell context (matches `lokalite shell`).
    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\\''")
    }

    enum HandoffError: Error, LocalizedError {
        case writeFailed
        var errorDescription: String? { "Failed to write the secret handoff script." }
    }
}
