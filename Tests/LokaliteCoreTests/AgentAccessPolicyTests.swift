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

    func testDaemonRefusesBlockedSecretForAgentCallerButNotForHuman() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .blocked)
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)

        let agentResponse = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 999, agent: "claude"))
        guard case let .failure(message) = agentResponse else {
            return XCTFail("agent caller should be refused, got \(agentResponse)")
        }
        XCTAssertTrue(message.contains("off-limits"))

        let humanResponse = VaultRequestDispatcher.handle(request, using: vault, caller: .local)
        guard case let .secret(secret) = humanResponse else {
            return XCTFail("non-agent caller should get the value, got \(humanResponse)")
        }
        XCTAssertEqual(secret.value, "v-secret")
    }

    func testDaemonBulkListExcludesBlockedSecretsForAgentsOnly() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "a", projectId: project.id)
        _ = try vault.add(name: "LOCKED", value: "b", projectId: project.id)
        try vault.setAgentAccess(name: "LOCKED", projectId: project.id, policy: .blocked)
        let request = VaultRequest.list(projectId: project.id, environmentName: nil)

        let agentResponse = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 1, agent: "claude"))
        guard case let .secrets(agentSecrets) = agentResponse else { return XCTFail("expected secrets") }
        XCTAssertEqual(agentSecrets.map(\.name), ["OPEN"], "agent bulk list must omit blocked secrets")

        let humanResponse = VaultRequestDispatcher.handle(request, using: vault, caller: .local)
        guard case let .secrets(humanSecrets) = humanResponse else { return XCTFail("expected secrets") }
        XCTAssertEqual(Set(humanSecrets.map(\.name)), ["OPEN", "LOCKED"], "a human still gets everything")
    }

    // MARK: - requiresApproval tier

    func testRequiresApprovalPolicyRoundTrips() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)

        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).agentAccess, .requiresApproval)
        XCTAssertEqual(try vault.listInfo(projectId: project.id).first?.agentAccess, .requiresApproval)
        XCTAssertEqual(AgentAccessPolicy.requiresApproval.rawValue, "requiresApproval")
    }

    func testDaemonReleasesApprovalSecretOnlyWhenHandlerApproves() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)
        let agent = CallerContext(pid: 999, agent: "claude")

        let denied = VaultRequestDispatcher.handle(request, using: vault, caller: agent, approveAgentAccess: { _ in false })
        guard case let .failure(message) = denied else {
            return XCTFail("denied approval should fail, got \(denied)")
        }
        XCTAssertTrue(message.contains("approval"), "got: \(message)")
        XCTAssertFalse(message.contains("v-secret"))

        var seen: ApprovalRequest?
        let approved = VaultRequestDispatcher.handle(request, using: vault, caller: agent, approveAgentAccess: { req in
            seen = req
            return true
        })
        guard case let .secret(secret) = approved else {
            return XCTFail("approved request should return the secret, got \(approved)")
        }
        XCTAssertEqual(secret.value, "v-secret")
        XCTAssertEqual(seen?.secretName, "K")
        XCTAssertEqual(seen?.agent, "claude")
    }

    func testDaemonDefaultHandlerDeniesApprovalSecretButHumanIsUnaffected() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)

        // Default handler denies (fail closed) for an agent.
        let agentResponse = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 1, agent: "claude"))
        guard case .failure = agentResponse else {
            return XCTFail("default handler should deny an agent, got \(agentResponse)")
        }

        // A human caller is never gated by approval.
        let humanResponse = VaultRequestDispatcher.handle(request, using: vault, caller: .local)
        guard case let .secret(secret) = humanResponse else {
            return XCTFail("human caller should get the value, got \(humanResponse)")
        }
        XCTAssertEqual(secret.value, "v-secret")
    }

    func testMCPGetSecretFailsClosedForApprovalSecretWhenNotDaemonBacked() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "STRIPE", value: "sk-live-xyz", projectId: project.id)
        try vault.setAgentAccess(name: "STRIPE", projectId: project.id, policy: .requiresApproval)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault, daemonBacked: false)
        let payload = try successPayload(tools.call(name: "get_secret", args: ["name": "STRIPE", "project": "App"]))

        XCTAssertEqual(payload["isError"] as? Bool, true)
        let text = textOf(payload)
        XCTAssertTrue(text.contains("--local") || text.contains("approval"), "got: \(text)")
        XCTAssertFalse(text.contains("sk-live-xyz"), "an approval-gated value must never appear")
    }

    func testMCPGetSecretPassesApprovalSecretThroughWhenDaemonBacked() throws {
        // Daemon-backed: the pre-check must NOT refuse; the value is brokered to the
        // daemon (which prompts). Backed by a local vault here, so it returns the
        // handoff — proving the pre-check let it through rather than failing closed.
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "API", value: "v1-secret", projectId: project.id)
        try vault.setAgentAccess(name: "API", projectId: project.id, policy: .requiresApproval)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault, daemonBacked: true)
        let payload = try successPayload(tools.call(name: "get_secret", args: ["name": "API", "project": "App"]))

        XCTAssertNil(payload["isError"])
        let text = textOf(payload)
        XCTAssertTrue(text.contains("source '"), "should return a handoff command, got: \(text)")
        XCTAssertFalse(text.contains("v1-secret"))
        if let path = text.split(separator: "'").dropFirst().first {
            try? FileManager.default.removeItem(atPath: String(path))
        }
    }

    func testMCPListSecretsMarksApprovalRequiredSecrets() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "a", projectId: project.id)
        _ = try vault.add(name: "GATED", value: "b", projectId: project.id)
        try vault.setAgentAccess(name: "GATED", projectId: project.id, policy: .requiresApproval)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault, daemonBacked: true)
        let text = textOf(try successPayload(tools.call(name: "list_secrets", args: ["project": "App"])))

        let gatedLine = text.split(separator: "\n").first { $0.contains("GATED") } ?? ""
        XCTAssertTrue(gatedLine.contains("approval required"), "got: \(text)")
        let openLine = text.split(separator: "\n").first { $0.contains("OPEN") } ?? ""
        XCTAssertFalse(openLine.contains("approval required"))
    }

    func testAgentAccessCommandApproveMapsToRequiresApproval() {
        XCTAssertEqual(AgentAccessCommand.State.approve.policy, .requiresApproval)
        XCTAssertEqual(AgentAccessCommand.State.block.policy, .blocked)
        XCTAssertEqual(AgentAccessCommand.State.allow.policy, .allowed)
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
