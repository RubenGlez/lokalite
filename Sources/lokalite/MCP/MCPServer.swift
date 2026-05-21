import Foundation
import LokaliteCore

final class MCPServer {
    private let vault = Vault.shared

    func run() throws {
        try vault.unlock()

        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let response = handle(json) {
                let out = try JSONSerialization.data(withJSONObject: response)
                FileHandle.standardOutput.write(out)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        }
    }

    // MARK: - Dispatch

    private func handle(_ req: [String: Any]) -> [String: Any]? {
        let id = req["id"]
        let method = req["method"] as? String ?? ""
        let params = req["params"] as? [String: Any]

        // Notifications have no id and need no response.
        guard req.keys.contains("id") else { return nil }

        switch method {
        case "initialize":
            return ok(id, [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "lokalite", "version": "1.0.0"]
            ])

        case "tools/list":
            return ok(id, ["tools": toolDefinitions])

        case "tools/call":
            let name = params?["name"] as? String ?? ""
            let args = params?["arguments"] as? [String: Any] ?? [:]
            return callTool(id: id, name: name, args: args)

        case "ping":
            return ok(id, [:])

        default:
            return err(id, code: -32601, message: "Method not found: \(method)")
        }
    }

    // MARK: - Tools

    private func callTool(id: Any?, name: String, args: [String: Any]) -> [String: Any] {
        switch name {
        case "get_secret":
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return err(id, code: -32602, message: "Missing required argument: name")
            }
            do {
                let secret = try vault.get(name: secretName)
                return ok(id, content(secret.value))
            } catch {
                return ok(id, contentError(error.localizedDescription))
            }

        case "list_secrets":
            let tag = args["tag"] as? String
            do {
                let secrets = try vault.list(tag: tag)
                if secrets.isEmpty {
                    return ok(id, content("No secrets found."))
                }
                let text = secrets.map { s -> String in
                    var line = s.name
                    if !s.tags.isEmpty { line += "  [\(s.tags.joined(separator: ", "))]" }
                    if let d = s.description { line += "  \(d)" }
                    return line
                }.joined(separator: "\n")
                return ok(id, content(text))
            } catch {
                return ok(id, contentError(error.localizedDescription))
            }

        default:
            return err(id, code: -32602, message: "Unknown tool: \(name)")
        }
    }

    // MARK: - Tool definitions

    private var toolDefinitions: [[String: Any]] {
        [
            [
                "name": "get_secret",
                "description": "Retrieve a secret value from the Lokalite vault by name.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Secret name, e.g. OPENAI_API_KEY"]
                    ],
                    "required": ["name"]
                ] as [String: Any]
            ],
            [
                "name": "list_secrets",
                "description": "List secret names stored in the Lokalite vault. Returns names only, not values.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "tag": ["type": "string", "description": "Filter by tag (optional)"]
                    ]
                ] as [String: Any]
            ]
        ]
    }

    // MARK: - Helpers

    private func ok(_ id: Any?, _ result: [String: Any]) -> [String: Any] {
        var r: [String: Any] = ["jsonrpc": "2.0", "result": result]
        if let id { r["id"] = id }
        return r
    }

    private func err(_ id: Any?, code: Int, message: String) -> [String: Any] {
        var r: [String: Any] = ["jsonrpc": "2.0", "error": ["code": code, "message": message] as [String: Any]]
        if let id { r["id"] = id }
        return r
    }

    private func content(_ text: String) -> [String: Any] {
        ["content": [["type": "text", "text": text]]]
    }

    private func contentError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }
}
