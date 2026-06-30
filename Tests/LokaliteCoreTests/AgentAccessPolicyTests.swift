import XCTest
@testable import LokaliteCore
@testable import lokalite

final class AgentAccessPolicyTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    func testPolicyDefaultsToAllowedAndRoundTrips() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)

        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).agentAccess, .allowed)

        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .blocked)
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).agentAccess, .blocked)
        XCTAssertEqual(try vault.listInfo(projectId: project.id).first?.agentAccess, .blocked)
    }

    func testMCPGetSecretRefusesBlockedSecretWithoutLeakingValue() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "STRIPE", value: "sk-live-xyz", projectId: project.id)
        try vault.setAgentAccess(name: "STRIPE", projectId: project.id, policy: .blocked)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)
        let payload = try successPayload(tools.call(name: "get_secret", args: ["name": "STRIPE", "project": "App"]))

        XCTAssertEqual(payload["isError"] as? Bool, true)
        let text = textOf(payload)
        XCTAssertTrue(text.contains("off-limits"), "got: \(text)")
        XCTAssertFalse(text.contains("sk-live-xyz"), "a blocked value must never appear")
    }

    func testMCPGetSecretAllowsNormalSecretViaHandoff() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "API", value: "v1-secret", projectId: project.id)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)
        let payload = try successPayload(tools.call(name: "get_secret", args: ["name": "API", "project": "App"]))

        XCTAssertNil(payload["isError"])
        let text = textOf(payload)
        XCTAssertTrue(text.contains("source '"), "should return a handoff command, got: \(text)")
        XCTAssertFalse(text.contains("v1-secret"), "the value must not appear inline")
        if let path = text.split(separator: "'").dropFirst().first {
            try? FileManager.default.removeItem(atPath: String(path))
        }
    }

    func testMCPListSecretsMarksBlockedSecrets() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "a", projectId: project.id)
        _ = try vault.add(name: "LOCKED", value: "b", projectId: project.id)
        try vault.setAgentAccess(name: "LOCKED", projectId: project.id, policy: .blocked)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)
        let text = textOf(try successPayload(tools.call(name: "list_secrets", args: ["project": "App"])))

        XCTAssertTrue(text.contains("LOCKED"))
        XCTAssertTrue(text.contains("off-limits to agents"))
        let openLine = text.split(separator: "\n").first { $0.contains("OPEN") } ?? ""
        XCTAssertFalse(openLine.contains("off-limits"))
    }

    private func successPayload(_ result: MCPToolCallResult) throws -> [String: Any] {
        guard case let .success(payload) = result else {
            throw XCTSkip("expected .success, got \(result)")
        }
        return payload
    }

    private func textOf(_ payload: [String: Any]) -> String {
        guard let content = payload["content"] as? [[String: Any]] else { return "" }
        return content.compactMap { $0["text"] as? String }.joined(separator: "\n")
    }
}
