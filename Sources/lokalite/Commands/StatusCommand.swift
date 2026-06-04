import ArgumentParser
import Foundation
import LokaliteCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show vault status and active context."
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() throws {
        let vault = Vault.shared
        try vault.unlock()

        let activeProjectId = try vault.activeProjectId()
        let activeProject = activeProjectId.flatMap { try? vault.project(id: $0) }
        let secretCount = activeProject.flatMap { try? vault.listInfo(projectId: $0.id).count }
        let cwd = FileManager.default.currentDirectoryPath
        let linkedProject = try? vault.resolveProject(workingDirectory: cwd)
        let cwdLinked = linkedProject != nil

        let vaultPath = VaultConfiguration.vaultFileURL.path

        let isMCPRegistered = checkMCPRegistered()

        if json {
            printJSON(
                project: activeProject?.name,
                environment: activeProject?.activeEnvironment,
                secretCount: secretCount,
                vaultPath: vaultPath,
                mcpRegistered: isMCPRegistered,
                directoryLinked: cwdLinked
            )
        } else {
            printHuman(
                project: activeProject?.name,
                environment: activeProject?.activeEnvironment,
                secretCount: secretCount,
                vaultPath: vaultPath,
                mcpRegistered: isMCPRegistered,
                cwd: cwd,
                directoryLinked: cwdLinked
            )
        }
    }

    private func printHuman(
        project: String?,
        environment: String?,
        secretCount: Int?,
        vaultPath: String,
        mcpRegistered: Bool,
        cwd: String,
        directoryLinked: Bool
    ) {
        print("Vault:       unlocked")
        print("Project:     \(project ?? "(none)")")
        print("Environment: \(environment ?? "Default")")
        print("Secrets:     \(secretCount.map(String.init) ?? "-")")
        print("Vault file:  \(vaultPath)")
        print("MCP server:  \(mcpRegistered ? "registered" : "not registered — run `lokalite install`")")

        if !directoryLinked {
            print("\nNo project linked to \(cwd).")
            print("Run `lokalite project link <name>` to associate this directory with a project.")
        }
    }

    private func printJSON(
        project: String?,
        environment: String?,
        secretCount: Int?,
        vaultPath: String,
        mcpRegistered: Bool,
        directoryLinked: Bool
    ) {
        let obj: [String: Any?] = [
            "locked": false,
            "project": project,
            "environment": environment ?? "Default",
            "secretCount": secretCount,
            "vaultPath": vaultPath,
            "mcpRegistered": mcpRegistered,
            "directoryLinked": directoryLinked
        ]
        let clean = obj.compactMapValues { $0 as Any? }
        if let data = try? JSONSerialization.data(withJSONObject: clean, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    private func checkMCPRegistered() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpServers = json["mcpServers"] as? [String: Any]
        else { return false }
        return mcpServers["lokalite"] != nil
    }
}
