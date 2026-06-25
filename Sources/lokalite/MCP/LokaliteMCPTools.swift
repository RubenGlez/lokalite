import Foundation
import LokaliteCore

enum MCPToolCallResult {
    case success([String: Any])
    case invalidArguments(String)
    case unknownTool(String)
}

final class LokaliteMCPTools {
    private let workspace = SecretWorkspace()
    private let allowWrites: Bool

    init(allowWrites: Bool = false) {
        self.allowWrites = allowWrites
    }

    func unlock() throws {
        try workspace.unlock()
    }

    func call(name: String, args: [String: Any]) -> MCPToolCallResult {
        switch name {
        case "get_secret":
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return .invalidArguments("Missing required argument: name")
            }
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            let path = args["path"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName, pathFlag: path, using: workspace)
                let secret = try workspace.get(name: secretName, context: ctx, accessSource: .mcp)
                return .success(content(secret.value))
            } catch {
                return .success(contentError(error.localizedDescription))
            }

        case "list_secrets":
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            let path = args["path"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName, pathFlag: path, using: workspace)
                let secrets = try workspace.listInfo(context: ctx)
                if secrets.isEmpty {
                    return .success(content("No secrets found."))
                }
                let text = secrets.map { secret -> String in
                    var line = "[\(secret.category.label)] \(secret.name)"
                    if let description = secret.description { line += "  — \(description)" }
                    return line
                }.joined(separator: "\n")
                return .success(content(text))
            } catch {
                return .success(contentError(error.localizedDescription))
            }

        case "add_secret":
            guard allowWrites else {
                return .success(contentError("Write tools are disabled. Start the MCP server with --read-write to enable them."))
            }
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return .invalidArguments("Missing required argument: name")
            }
            guard let value = args["value"] as? String, !value.isEmpty else {
                return .invalidArguments("Missing required argument: value")
            }
            let description = args["description"] as? String
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            let path = args["path"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName, pathFlag: path, using: workspace)
                _ = try workspace.add(name: secretName, value: value, description: description, context: ctx)
                return .success(content("Secret '\(secretName)' created."))
            } catch {
                return .success(contentError(error.localizedDescription))
            }

        case "set_secret":
            guard allowWrites else {
                return .success(contentError("Write tools are disabled. Start the MCP server with --read-write to enable them."))
            }
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return .invalidArguments("Missing required argument: name")
            }
            guard let value = args["value"] as? String, !value.isEmpty else {
                return .invalidArguments("Missing required argument: value")
            }
            let projectName = args["project"] as? String
            let envName = args["environment"] as? String
            let path = args["path"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: envName, pathFlag: path, using: workspace)
                _ = try workspace.set(name: secretName, value: value, context: ctx)
                return .success(content("Secret '\(secretName)' updated."))
            } catch {
                return .success(contentError(error.localizedDescription))
            }

        case "delete_secret":
            guard allowWrites else {
                return .success(contentError("Write tools are disabled. Start the MCP server with --read-write to enable them."))
            }
            guard let secretName = args["name"] as? String, !secretName.isEmpty else {
                return .invalidArguments("Missing required argument: name")
            }
            let projectName = args["project"] as? String
            let path = args["path"] as? String
            do {
                let ctx = try resolveContext(projectFlag: projectName, envFlag: nil, pathFlag: path, using: workspace)
                try workspace.delete(name: secretName, context: ctx)
                return .success(content("Secret '\(secretName)' deleted."))
            } catch {
                return .success(contentError(error.localizedDescription))
            }

        default:
            return .unknownTool(name)
        }
    }

    var definitions: [[String: Any]] {
        var tools: [[String: Any]] = [
            [
                "name": "get_secret",
                "description": "Retrieve a secret value from the Lokalite vault by name. Use this when you need the actual value of a credential, API key, or other secret. Call list_secrets first if you don't know the exact name.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Exact secret name, e.g. OPENAI_API_KEY"],
                        "project": ["type": "string", "description": "Project name. Omit to auto-resolve the project from the working directory (path)."],
                        "environment": ["type": "string", "description": "Environment name (e.g. production). Omit to use the active environment."],
                        "path": ["type": "string", "description": "Absolute path of the caller's working directory; used to auto-resolve the project when omitted."]
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
                        "project": ["type": "string", "description": "Project name. Omit to auto-resolve the project from the working directory (path)."],
                        "environment": ["type": "string", "description": "Environment name. Omit to use the active environment."],
                        "path": ["type": "string", "description": "Absolute path of the caller's working directory; used to auto-resolve the project when omitted."]
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
                            "project": ["type": "string", "description": "Project name. Omit to auto-resolve the project from the working directory (path)."],
                            "environment": ["type": "string", "description": "Environment name. Omit to use the active environment."],
                            "path": ["type": "string", "description": "Absolute path of the caller's working directory; used to auto-resolve the project when omitted."]
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
                            "project": ["type": "string", "description": "Project name. Omit to auto-resolve the project from the working directory (path)."],
                            "environment": ["type": "string", "description": "Environment name. Omit to use the active environment."],
                            "path": ["type": "string", "description": "Absolute path of the caller's working directory; used to auto-resolve the project when omitted."]
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
                            "project": ["type": "string", "description": "Project name. Omit to auto-resolve the project from the working directory (path)."],
                            "path": ["type": "string", "description": "Absolute path of the caller's working directory; used to auto-resolve the project when omitted."]
                        ],
                        "required": ["name"]
                    ] as [String: Any]
                ]
            ]
        }

        return tools
    }

    private func content(_ text: String) -> [String: Any] {
        ["content": [["type": "text", "text": text]]]
    }

    private func contentError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }
}
