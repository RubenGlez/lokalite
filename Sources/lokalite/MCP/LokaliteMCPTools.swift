import Foundation
import LokaliteCore

enum MCPToolCallResult {
    case success([String: Any])
    case invalidArguments(String)
    case unknownTool(String)
}

final class LokaliteMCPTools {
    private let workspace: SecretWorkspace
    private let allowWrites: Bool
    /// True when this process brokers through the app daemon, which can show the
    /// consent prompt. When false (`--local`/headless), `requiresApproval` secrets
    /// fail closed — there is no GUI to obtain consent.
    private let daemonBacked: Bool

    init(allowWrites: Bool = false, vault: VaultService = Vault.shared, daemonBacked: Bool = false) {
        self.allowWrites = allowWrites
        self.daemonBacked = daemonBacked
        self.workspace = SecretWorkspace(vault: vault)
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
                // Enforce per-secret agent policy before the value is ever loaded.
                let policy = try workspace.listInfo(context: ctx).first(where: { $0.name == secretName })?.agentAccess
                if policy?.blocksAgents == true {
                    return .success(contentError("Secret '\(secretName)' is marked off-limits to AI agents and cannot be retrieved."))
                }
                // `requiresApproval` is brokered by the daemon (Touch ID). Without a
                // daemon there is no way to obtain consent, so fail closed here;
                // when daemon-backed, let the request reach the daemon to prompt.
                if policy?.requiresApprovalForAgents == true && !daemonBacked {
                    return .success(contentError("Secret '\(secretName)' requires per-read approval, which needs the Lokalite app. It cannot be retrieved with --local."))
                }
                let secret = try workspace.get(name: secretName, context: ctx, accessSource: .mcp)
                let command = try MCPSecretHandoff.write([(secret.name, secret.value)])
                return .success(content("Run this in your shell to load \(secret.name) into the environment — the value is never shown here:\n\(command)"))
            } catch {
                return .success(contentError(forResolution: error))
            }

        case "list_projects":
            do {
                let projects = try workspace.listProjects()
                if projects.isEmpty {
                    return .success(content("No projects found."))
                }
                let text = projects.map { project -> String in
                    var line = project.name
                    line += project.path.map { "  — \($0)" } ?? "  — (not linked to a directory)"
                    if let env = project.activeEnvironment { line += "  [env: \(env)]" }
                    return line
                }.joined(separator: "\n")
                return .success(content(text))
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
                    if secret.agentAccess.blocksAgents { line += "  [off-limits to agents]" }
                    else if secret.agentAccess.requiresApprovalForAgents { line += "  [approval required]" }
                    if let description = secret.description { line += "  — \(description)" }
                    return line
                }.joined(separator: "\n")
                return .success(content(text))
            } catch {
                return .success(contentError(forResolution: error))
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
                return .success(contentError(forResolution: error))
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
                return .success(contentError(forResolution: error))
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
                return .success(contentError(forResolution: error))
            }

        default:
            return .unknownTool(name)
        }
    }

    var definitions: [[String: Any]] {
        var tools: [[String: Any]] = [
            [
                "name": "get_secret",
                "description": "Load a secret from the Lokalite vault into your shell environment WITHOUT exposing its value. This does NOT return the value — it returns a one-time `source '<path>'` command. Run that command in your shell (Bash) to set the environment variable, then run your program in the same shell so it inherits it. The raw value never appears in this conversation; the handoff script is single-use and self-deletes. Do not print the loaded variable, and never copy the value into a file (.env, config, source). Call list_secrets first if you don't know the exact name.",
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
            ],
            [
                "name": "list_projects",
                "description": "List the projects in the Lokalite vault, with their linked directories and active environment. No secret values are returned. Use this when a tool reports that no project could be resolved, then pass the project name explicitly.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:] as [String: Any]
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

    /// Surfaces resolution failures with MCP-actionable guidance. The CLI's
    /// `noActiveProject` message tells the user to `cd` into a linked directory,
    /// which an agent cannot do; point it at list_projects instead.
    private func contentError(forResolution error: Error) -> [String: Any] {
        if let vaultError = error as? VaultError, case .noActiveProject = vaultError {
            return contentError("No project could be resolved from the working directory. Call list_projects to see available projects, then pass `project` explicitly.")
        }
        return contentError(error.localizedDescription)
    }
}
