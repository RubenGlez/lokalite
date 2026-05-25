import Foundation
import LokaliteCore

final class MCPServer {
    private let vault = Vault.shared
    private let allowWrites: Bool

    init(allowWrites: Bool = false) {
        self.allowWrites = allowWrites
    }

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
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName)
                let secret = try vault.get(name: secretName, projectId: ctx.project.id,
                                           environmentName: ctx.environmentName)
                return ok(id, content(secret.value))
            } catch {
                return ok(id, contentError(error.localizedDescription))
            }

        case "list_secrets":
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName)
                let secrets = try vault.listInfo(projectId: ctx.project.id)
                if secrets.isEmpty {
                    return ok(id, content("No secrets found."))
                }
                let text = secrets.map { s -> String in
                    var line = "[\(s.category.label)] \(s.name)"
                    if let d = s.description { line += "  — \(d)" }
                    return line
                }.joined(separator: "\n")
                return ok(id, content(text))
            } catch {
                return ok(id, contentError(error.localizedDescription))
            }

        case "add_secret":
            guard allowWrites else {
                return ok(id, contentError("Write tools are disabled. Start the MCP server with --read-write to enable them."))
            }
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return err(id, code: -32602, message: "Missing required argument: name")
            }
            guard let value = args["value"] as? String, !value.isEmpty else {
                return err(id, code: -32602, message: "Missing required argument: value")
            }
            let description = args["description"] as? String
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName)
                _ = try vault.add(name: secretName, value: value, description: description,
                                  projectId: ctx.project.id, environmentName: ctx.environmentName)
                return ok(id, content("Secret '\(secretName)' created."))
            } catch {
                return ok(id, contentError(error.localizedDescription))
            }

        case "set_secret":
            guard allowWrites else {
                return ok(id, contentError("Write tools are disabled. Start the MCP server with --read-write to enable them."))
            }
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return err(id, code: -32602, message: "Missing required argument: name")
            }
            guard let value = args["value"] as? String, !value.isEmpty else {
                return err(id, code: -32602, message: "Missing required argument: value")
            }
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName)
                _ = try vault.set(name: secretName, value: value,
                                  projectId: ctx.project.id, environmentName: ctx.environmentName)
                return ok(id, content("Secret '\(secretName)' updated."))
            } catch {
                return ok(id, contentError(error.localizedDescription))
            }

        case "delete_secret":
            guard allowWrites else {
                return ok(id, contentError("Write tools are disabled. Start the MCP server with --read-write to enable them."))
            }
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return err(id, code: -32602, message: "Missing required argument: name")
            }
            let projectName = args["project"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: nil)
                try vault.delete(name: secretName, projectId: ctx.project.id)
                return ok(id, content("Secret '\(secretName)' deleted."))
            } catch {
                return ok(id, contentError(error.localizedDescription))
            }

        default:
            return err(id, code: -32602, message: "Unknown tool: \(name)")
        }
    }

    // MARK: - Tool definitions

    private var toolDefinitions: [[String: Any]] {
        var tools: [[String: Any]] = [
            [
                "name": "get_secret",
                "description": "Retrieve a secret value from the Lokalite vault by name. Use this when you need the actual value of a credential, API key, or other secret. Call list_secrets first if you don't know the exact name.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Exact secret name, e.g. OPENAI_API_KEY"],
                        "project": ["type": "string", "description": "Project name. Omit to use the active project."],
                        "environment": ["type": "string", "description": "Environment name (e.g. production). Omit to use the active environment."]
                    ],
                    "required": ["name"]
                ] as [String: Any]
            ],
            [
                "name": "list_secrets",
                "description": "List secrets stored in the Lokalite vault. Returns names and descriptions only — values are never exposed. Use this to discover available secrets before calling get_secret.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "project": ["type": "string", "description": "Project name. Omit to use the active project."],
                        "environment": ["type": "string", "description": "Environment name. Omit to use the active environment."]
                    ]
                ] as [String: Any]
            ]
        ]

        if allowWrites {
            tools += [
                [
                    "name": "add_secret",
                    "description": "Store a new secret in the Lokalite vault. Fails if a secret with that name already exists — use set_secret to update an existing one.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Secret name, e.g. STRIPE_SECRET_KEY"],
                            "value": ["type": "string", "description": "Secret value to encrypt and store"],
                            "description": ["type": "string", "description": "Optional human-readable description"],
                            "project": ["type": "string", "description": "Project name. Omit to use the active project."],
                            "environment": ["type": "string", "description": "Environment name. Omit to use the active environment."]
                        ],
                        "required": ["name", "value"]
                    ] as [String: Any]
                ],
                [
                    "name": "set_secret",
                    "description": "Update the value of an existing secret. Fails if the secret does not exist — use add_secret to create a new one.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Exact name of the secret to update"],
                            "value": ["type": "string", "description": "New secret value"],
                            "project": ["type": "string", "description": "Project name. Omit to use the active project."],
                            "environment": ["type": "string", "description": "Environment name. Omit to use the active environment."]
                        ],
                        "required": ["name", "value"]
                    ] as [String: Any]
                ],
                [
                    "name": "delete_secret",
                    "description": "Permanently delete a secret from the Lokalite vault. This cannot be undone.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Exact name of the secret to delete"],
                            "project": ["type": "string", "description": "Project name. Omit to use the active project."]
                        ],
                        "required": ["name"]
                    ] as [String: Any]
                ]
            ]
        }

        return tools
    }

    // MARK: - Helpers

    private func resolveContext(projectFlag: String?, envFlag: String?) throws -> VaultContext {
        let projectName = projectFlag ?? ProcessInfo.processInfo.environment["LOKALITE_PROJECT"]
        let envName = envFlag ?? ProcessInfo.processInfo.environment["LOKALITE_ENV"]
        let project = try vault.resolveProject(name: projectName)
        let resolvedEnv = envName ?? project.activeEnvironment
        return VaultContext(project: project, environmentName: resolvedEnv)
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

    private func content(_ text: String) -> [String: Any] {
        ["content": [["type": "text", "text": text]]]
    }

    private func contentError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }
}
