import XCTest
@testable import LokaliteCore
@testable import lokalite

/// Tighten-only client agent context (ADR 0018): the envelope hint can turn a
/// human-classified caller into an agent but never the reverse, kernel detection
/// wins the attribution label, and the MCP/run client seams stamp the hint.
final class ClientAgentContextTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    // MARK: - CallerContext merge semantics

    func testEffectiveAgentPrefersKernelDetectionOverHint() {
        let both = CallerContext(pid: 1, agent: "claude", clientAgentHint: "agent")
        XCTAssertEqual(both.effectiveAgent, "claude", "kernel detection wins the label")
        XCTAssertTrue(both.isAgent)

        let hintOnly = CallerContext(pid: 1, agent: nil, clientAgentHint: "agent")
        XCTAssertEqual(hintOnly.effectiveAgent, "agent")
        XCTAssertTrue(hintOnly.isAgent)

        let kernelOnly = CallerContext(pid: 1, agent: "claude")
        XCTAssertEqual(kernelOnly.effectiveAgent, "claude")
        XCTAssertTrue(kernelOnly.isAgent)

        let human = CallerContext(pid: 1, agent: nil)
        XCTAssertNil(human.effectiveAgent)
        XCTAssertFalse(human.isAgent)
    }

    func testMergingIsTightenOnly() {
        let kernelAgent = CallerContext(pid: 7, agent: "claude")
        // A nil hint (or any hint) never weakens a kernel-detected agent.
        XCTAssertEqual(kernelAgent.merging(clientAgentHint: nil).effectiveAgent, "claude")
        XCTAssertEqual(kernelAgent.merging(clientAgentHint: "agent").effectiveAgent, "claude")

        let human = CallerContext(pid: 7, agent: nil)
        XCTAssertEqual(human.merging(clientAgentHint: "agent").effectiveAgent, "agent")
        XCTAssertNil(human.merging(clientAgentHint: nil).effectiveAgent)
        XCTAssertEqual(human.merging(clientAgentHint: "agent").pid, 7)
    }

    // MARK: - Hint-only enforcement at the dispatcher

    func testHintOnlyCallerIsRefusedBlockedSecretAndDenialIsAttributed() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .blocked)
        let hintOnly = CallerContext(pid: 999, agent: nil, clientAgentHint: "agent")

        let response = VaultRequestDispatcher.handle(.get(name: "K", projectId: project.id, environmentName: nil), using: vault, caller: hintOnly)
        guard case let .failure(message) = response else {
            return XCTFail("hint-only agent should be refused, got \(response)")
        }
        XCTAssertTrue(message.contains("off-limits"), "got: \(message)")
        XCTAssertFalse(message.contains("v-secret"))

        let denial = try XCTUnwrap(try vault.listActivity().first { $0.action == .denied })
        XCTAssertEqual(denial.secretName, "K")
        XCTAssertEqual(denial.agent, "agent", "denial must be attributed to the hint")
    }

    func testHintOnlyCallerPromptsForApprovalTierSecret() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        let hintOnly = CallerContext(pid: 999, agent: nil, clientAgentHint: "agent")
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)

        // Default handler denies (fail closed) — the hint alone gates the read.
        let denied = VaultRequestDispatcher.handle(request, using: vault, caller: hintOnly)
        guard case .failure = denied else {
            return XCTFail("hint-only agent should hit the approval gate, got \(denied)")
        }

        var seen: ApprovalRequest?
        let approved = VaultRequestDispatcher.handle(request, using: vault, caller: hintOnly, approveAgentAccess: { req in
            seen = req
            return true
        })
        guard case let .secret(secret) = approved else {
            return XCTFail("approved read should return the secret, got \(approved)")
        }
        XCTAssertEqual(secret.value, "v-secret")
        XCTAssertEqual(seen?.agent, "agent", "the prompt is attributed to the hint")
    }

    func testKernelDetectionWinsAttributionWhenBothArePresent() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        let both = CallerContext(pid: 999, agent: "claude", clientAgentHint: "agent")
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)

        var seen: ApprovalRequest?
        _ = VaultRequestDispatcher.handle(request, using: vault, caller: both, approveAgentAccess: { req in
            seen = req
            return false
        })
        XCTAssertEqual(seen?.agent, "claude", "ApprovalRequest labels the kernel agent")

        let denial = try XCTUnwrap(try vault.listActivity().first { $0.action == .denied })
        XCTAssertEqual(denial.agent, "claude", "the denial labels the kernel agent")
    }

    func testLogAccessStampsEffectiveAgentOverridingTheClientBody() throws {
        let vault = try makeVault()
        let hintOnly = CallerContext(pid: 999, agent: nil, clientAgentHint: "agent")

        _ = VaultRequestDispatcher.handle(
            .logAccess(secretName: "K", projectName: "App", environmentName: "Default", source: .mcp, action: .read),
            using: vault,
            caller: hintOnly
        )
        let entry = try XCTUnwrap(try vault.listActivity().first)
        XCTAssertEqual(entry.agent, "agent", "access log carries effectiveAgent")
    }

    // MARK: - Client construction seams

    func testMCPClientAlwaysCarriesAHint() {
        // Self-detection's token when it fires…
        XCTAssertEqual(MCPCommand.socketClient(socketPath: "/tmp/s.sock", detected: "claude").agentContext, "claude")
        // …and the literal "agent" when it misses: MCP callers are agents by definition.
        XCTAssertEqual(MCPCommand.socketClient(socketPath: "/tmp/s.sock", detected: nil).agentContext, "agent")
    }

    func testRunClientCarriesAHintOnlyWhenDetectionFires() throws {
        XCTAssertEqual(RunCommand.socketClient(socketPath: "/tmp/s.sock", detected: "goose").agentContext, "goose")

        // A human run stays byte-identical to a legacy client on the wire.
        let humanClient = RunCommand.socketClient(socketPath: "/tmp/s.sock", detected: nil)
        XCTAssertNil(humanClient.agentContext)
        XCTAssertEqual(
            try humanClient.encodeFrame(.listProjects),
            try JSONEncoder().encode(VaultRequest.listProjects)
        )
    }
}
