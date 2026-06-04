import Foundation

final class MCPServer {
    private let tools: LokaliteMCPTools

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
                "serverInfo": ["name": "lokalite", "version": "1.0.0"]
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
