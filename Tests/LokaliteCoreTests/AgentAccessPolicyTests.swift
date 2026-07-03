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

    func testDaemonDefaultHandlerDeniesApprovalSecretForEveryCaller() throws {
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

        // Approval tiers are caller-independent (ADR 0018): a human caller is
        // gated by the same fail-closed handler.
        let humanResponse = VaultRequestDispatcher.handle(request, using: vault, caller: .local)
        guard case let .failure(message) = humanResponse else {
            return XCTFail("a human caller must also be gated, got \(humanResponse)")
        }
        XCTAssertTrue(message.contains("approval"), "got: \(message)")
        XCTAssertFalse(message.contains("v-secret"))
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
        XCTAssertEqual(AgentAccessCommand.State.strict.policy, .strict)
    }

    // MARK: - strict tier (per-call approval)

    func testStrictPolicyRoundTripsAndFlags() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)

        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .strict)
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).agentAccess, .strict)
        XCTAssertEqual(try vault.listInfo(projectId: project.id).first?.agentAccess, .strict)
        XCTAssertEqual(AgentAccessPolicy.strict.rawValue, "strict")

        // strict prompts like requiresApproval, but on every read.
        XCTAssertTrue(AgentAccessPolicy.strict.requiresApprovalForAgents)
        XCTAssertTrue(AgentAccessPolicy.strict.promptsPerCall)
        XCTAssertFalse(AgentAccessPolicy.requiresApproval.promptsPerCall)
        XCTAssertFalse(AgentAccessPolicy.strict.blocksAgents)
    }

    func testDaemonReleasesStrictSecretOnlyWhenHandlerApproves() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .strict)
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)
        let agent = CallerContext(pid: 999, agent: "claude")

        let denied = VaultRequestDispatcher.handle(request, using: vault, caller: agent, approveAgentAccess: { _ in false })
        guard case let .failure(message) = denied else {
            return XCTFail("denied strict read should fail, got \(denied)")
        }
        XCTAssertTrue(message.contains("approval"), "got: \(message)")
        XCTAssertFalse(message.contains("v-secret"))
        let denial = try XCTUnwrap(try vault.listActivity().first { $0.action == .denied })
        XCTAssertEqual(denial.secretName, "K")
        XCTAssertEqual(denial.agent, "claude")

        var seen: ApprovalRequest?
        let approved = VaultRequestDispatcher.handle(request, using: vault, caller: agent, approveAgentAccess: { req in
            seen = req
            return true
        })
        guard case let .secret(secret) = approved else {
            return XCTFail("approved strict read should return the secret, got \(approved)")
        }
        XCTAssertEqual(secret.value, "v-secret")
        XCTAssertEqual(seen?.perCall, true)
        XCTAssertEqual(seen?.agent, "claude")
    }

    func testDispatcherInvokesHandlerOnEveryStrictRead() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .strict)
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)
        let agent = CallerContext(pid: 999, agent: "claude")

        var invocations = 0
        let handler: AgentApprovalHandler = { _ in
            invocations += 1
            return true
        }
        _ = VaultRequestDispatcher.handle(request, using: vault, caller: agent, approveAgentAccess: handler)
        _ = VaultRequestDispatcher.handle(request, using: vault, caller: agent, approveAgentAccess: handler)
        XCTAssertEqual(invocations, 2, "a strict secret must consult the handler on every read")
    }

    func testGrantCacheCachesSessionGrantsButNeverPerCallOnes() {
        let cache = ApprovalGrantCache()
        let session = ApprovalRequest(secretID: "s1", secretName: "K", projectID: "p1", projectName: "App", environmentName: "Default", perCall: false, agent: "claude")
        let perCall = ApprovalRequest(secretID: "s2", secretName: "K2", projectID: "p1", projectName: "App", environmentName: "Default", perCall: true, agent: "claude")

        // requiresApproval: first read prompts, the grant is cached, the second
        // read is released without a prompt.
        XCTAssertFalse(cache.isGranted(session))
        cache.recordGrant(session)
        XCTAssertTrue(cache.isGranted(session), "a session grant must short-circuit the second prompt")

        // strict: never read from and never written to the cache.
        XCTAssertFalse(cache.isGranted(perCall))
        cache.recordGrant(perCall)
        XCTAssertFalse(cache.isGranted(perCall), "a per-call approval must never be cached")

        // A per-call request for a secret that also holds a session grant still
        // bypasses the cache.
        let perCallSameSecret = ApprovalRequest(secretID: "s1", secretName: "K", projectID: "p1", projectName: "App", environmentName: "Default", perCall: true, agent: "claude")
        XCTAssertFalse(cache.isGranted(perCallSameSecret))

        // Locking the vault drops session grants.
        cache.clear()
        XCTAssertFalse(cache.isGranted(session))
    }

    func testApprovalRequestCarriesProjectAndResolvedEnvironmentNames() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        _ = try vault.addEnvironment(name: "production", projectId: project.id)
        _ = try vault.set(name: "K", value: "v-prod", projectId: project.id, environmentName: "production")
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        let agent = CallerContext(pid: 999, agent: "claude")

        // A nil wire environment resolves to the project's active environment name.
        try vault.setActiveEnvironment(name: "production", projectId: project.id)
        var seen: ApprovalRequest?
        _ = VaultRequestDispatcher.handle(.get(name: "K", projectId: project.id, environmentName: nil), using: vault, caller: agent, approveAgentAccess: { req in
            seen = req
            return true
        })
        XCTAssertEqual(seen?.projectName, "App")
        XCTAssertEqual(seen?.environmentName, "production")
        XCTAssertEqual(seen?.perCall, false)

        // An explicit wire environment is carried through as-is.
        seen = nil
        _ = VaultRequestDispatcher.handle(.get(name: "K", projectId: project.id, environmentName: "production"), using: vault, caller: agent, approveAgentAccess: { req in
            seen = req
            return true
        })
        XCTAssertEqual(seen?.environmentName, "production")
    }

    func testApprovalRequestFallsBackToDefaultEnvironmentName() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        // No active environment on the project: the value lives outside any
        // environment, and the prompt shows the "Default" display name.
        try vault.setActiveEnvironment(name: nil, projectId: project.id)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .strict)

        var seen: ApprovalRequest?
        _ = VaultRequestDispatcher.handle(.get(name: "K", projectId: project.id, environmentName: nil), using: vault, caller: CallerContext(pid: 999, agent: "claude"), approveAgentAccess: { req in
            seen = req
            return true
        })
        XCTAssertEqual(seen?.projectName, "App")
        XCTAssertEqual(seen?.environmentName, "Default")
        XCTAssertEqual(seen?.perCall, true)
    }

    func testMCPGetSecretFailsClosedForStrictSecretWhenNotDaemonBacked() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "STRIPE", value: "sk-live-xyz", projectId: project.id)
        try vault.setAgentAccess(name: "STRIPE", projectId: project.id, policy: .strict)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault, daemonBacked: false)
        let payload = try successPayload(tools.call(name: "get_secret", args: ["name": "STRIPE", "project": "App"]))

        XCTAssertEqual(payload["isError"] as? Bool, true)
        let text = textOf(payload)
        XCTAssertTrue(text.contains("--local") || text.contains("approval"), "got: \(text)")
        XCTAssertFalse(text.contains("sk-live-xyz"), "a strict value must never appear")
    }

    func testMCPListSecretsMarksStrictSecrets() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "GATED", value: "a", projectId: project.id)
        _ = try vault.add(name: "STRICT", value: "b", projectId: project.id)
        try vault.setAgentAccess(name: "GATED", projectId: project.id, policy: .requiresApproval)
        try vault.setAgentAccess(name: "STRICT", projectId: project.id, policy: .strict)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault, daemonBacked: true)
        let text = textOf(try successPayload(tools.call(name: "list_secrets", args: ["project": "App"])))

        let strictLine = text.split(separator: "\n").first { $0.contains("STRICT") } ?? ""
        XCTAssertTrue(strictLine.contains("approval required every read"), "got: \(text)")
        let gatedLine = text.split(separator: "\n").first { $0.contains("GATED") } ?? ""
        XCTAssertTrue(gatedLine.contains("approval required"))
        XCTAssertFalse(gatedLine.contains("every read"), "session-tier marker must stay unchanged")
    }

    // MARK: - M2: bulk list excludes approval-tier for agents

    func testDaemonBulkListExcludesApprovalTierForAgentsOnly() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "a", projectId: project.id)
        _ = try vault.add(name: "APPROVE", value: "b", projectId: project.id)
        _ = try vault.add(name: "STRICT", value: "c", projectId: project.id)
        try vault.setAgentAccess(name: "APPROVE", projectId: project.id, policy: .requiresApproval)
        try vault.setAgentAccess(name: "STRICT", projectId: project.id, policy: .strict)
        let request = VaultRequest.list(projectId: project.id, environmentName: nil)

        let agentResponse = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 1, agent: "claude"))
        guard case let .secrets(agentSecrets) = agentResponse else { return XCTFail("expected secrets") }
        XCTAssertEqual(agentSecrets.map(\.name), ["OPEN"], "agent bulk list must omit approval-tier secrets")

        let humanResponse = VaultRequestDispatcher.handle(request, using: vault, caller: .local)
        guard case let .secrets(humanSecrets) = humanResponse else { return XCTFail("expected secrets") }
        XCTAssertEqual(Set(humanSecrets.map(\.name)), ["OPEN", "APPROVE", "STRICT"], "a human still gets everything")
    }

    // MARK: - H3: agent write governance (ADR 0020)

    func testDaemonRefusesWritesToBlockedForAgentButAllowsHuman() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .blocked)
        let setReq = VaultRequest.set(name: "K", value: "hacked", projectId: project.id, environmentName: nil)
        let delReq = VaultRequest.delete(name: "K", projectId: project.id)
        let agent = CallerContext(pid: 1, agent: "claude")

        guard case let .failure(setMsg) = VaultRequestDispatcher.handle(setReq, using: vault, caller: agent) else {
            return XCTFail("agent set on a blocked secret must be refused")
        }
        XCTAssertTrue(setMsg.contains("off-limits"))
        guard case .failure = VaultRequestDispatcher.handle(delReq, using: vault, caller: agent) else {
            return XCTFail("agent delete on a blocked secret must be refused")
        }
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).value, "v", "the blocked value must be untouched")

        // A human may still edit a blocked secret (blocked is agent-scoped).
        guard case .secret = VaultRequestDispatcher.handle(setReq, using: vault, caller: .local) else {
            return XCTFail("a human write to a blocked secret must succeed")
        }
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).value, "hacked")
    }

    func testDaemonWriteToApprovalTierRequiresConsentForEveryCaller() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        let setReq = VaultRequest.set(name: "K", value: "changed", projectId: project.id, environmentName: nil)

        for caller in [CallerContext(pid: 1, agent: "claude"), CallerContext.local] {
            guard case let .failure(msg) = VaultRequestDispatcher.handle(setReq, using: vault, caller: caller, approveAgentAccess: { _ in false }) else {
                return XCTFail("a denied approval must refuse the write")
            }
            XCTAssertTrue(msg.contains("approval"), "got: \(msg)")
        }
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).value, "v", "a denied write must not change the value")

        var seen: ApprovalRequest?
        let approved = VaultRequestDispatcher.handle(setReq, using: vault, caller: CallerContext(pid: 1, agent: "claude"), approveAgentAccess: { req in seen = req; return true })
        guard case .secret = approved else { return XCTFail("an approved write must go through, got \(approved)") }
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).value, "changed")
        XCTAssertEqual(seen?.perCall, true, "a governed write always prompts — a cached read grant must never authorize it")
    }

    func testDaemonDefaultHandlerDeniesApprovalTierDelete() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .strict)
        let delReq = VaultRequest.delete(name: "K", projectId: project.id)

        guard case .failure = VaultRequestDispatcher.handle(delReq, using: vault, caller: CallerContext(pid: 1, agent: "claude")) else {
            return XCTFail("the fail-closed default handler must deny an approval-tier delete")
        }
        XCTAssertNoThrow(try vault.get(name: "K", projectId: project.id), "the secret must still exist")
    }

    func testMCPSetSecretRefusesBlockedSecretWithoutChangingIt() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .blocked)

        let tools = LokaliteMCPTools(allowWrites: true, vault: vault)
        let payload = try successPayload(tools.call(name: "set_secret", args: ["name": "K", "value": "x", "project": "App"]))

        XCTAssertEqual(payload["isError"] as? Bool, true)
        XCTAssertTrue(textOf(payload).contains("off-limits"))
        XCTAssertEqual(try vault.get(name: "K", projectId: project.id).value, "v")
    }

    func testMCPDeleteSecretFailsClosedForApprovalTierWhenNotDaemonBacked() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)

        let tools = LokaliteMCPTools(allowWrites: true, vault: vault, daemonBacked: false)
        let payload = try successPayload(tools.call(name: "delete_secret", args: ["name": "K", "project": "App"]))

        XCTAssertEqual(payload["isError"] as? Bool, true)
        XCTAssertNoThrow(try vault.get(name: "K", projectId: project.id), "a fail-closed delete must not remove the secret")
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
