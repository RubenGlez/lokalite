import Foundation

final class MCPServer {
    private let tools: LokaliteMCPTools

    static let instructions = """
    Lokalite is an encrypted local vault for a project's secrets (API keys, tokens, credentials).

    Core principle: a secret's value must never enter this conversation. You load secrets into your shell environment and run programs there; you do not read values into context or write them to disk.

    To use a secret:
      1. Call get_secret. It does NOT return the value — it returns a one-time `source '<path>'` command.
      2. Run that command in your shell (Bash). It sets the environment variable, then deletes itself.
      3. Run your program in the SAME shell so it inherits the variable (e.g. `npm run dev`, `node script.js`).
    The raw value never appears here. Do not print a loaded variable, and never copy a secret into a .env file, config, or source — and never commit one.

    Discovery (no secret values are returned):
      list_secrets  — names and descriptions of the secrets in a project.
      list_projects — available projects and their linked directories. Call this when a tool reports that no project could be resolved.

    Project resolution: tools auto-resolve the project from your working directory (the `path` argument). If resolution fails, call list_projects and pass `project` explicitly.
    """

    init(allowWrites: Bool = false) {
        tools = LokaliteMCPTools(allowWrites: allowWrites)
    }

    func run() throws {
        try tools.unlock()

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

        guard req.keys.contains("id") else { return nil }

        switch method {
        case "initialize":
            return ok(id, [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "lokalite", "version": "1.0.0"],
                "instructions": Self.instructions
            ])

        case "tools/list":
            return ok(id, ["tools": tools.definitions])

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
        switch tools.call(name: name, args: args) {
        case .success(let result):
            return ok(id, result)
        case .invalidArguments(let message):
            return err(id, code: -32602, message: message)
        case .unknownTool(let name):
            return err(id, code: -32602, message: "Unknown tool: \(name)")
        }
    }

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
}
