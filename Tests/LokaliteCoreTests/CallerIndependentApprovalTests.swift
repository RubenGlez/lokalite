import XCTest
@testable import LokaliteCore
@testable import lokalite

/// Caller-independent approval tiers (ADR 0018): consent is a property of the
/// secret, not of caller classification. Every daemon-brokered read of a
/// `requiresApproval`/`strict` secret prompts — humans included — and the CLI
/// reveal/bulk paths route or exclude those secrets so the only way to a value
/// is through the consent prompt.
final class CallerIndependentApprovalTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    // MARK: - Dispatcher: humans are gated too

    func testHumanCallerNeedsConsentAndDenialLogsNilAgent() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .requiresApproval)
        let request = VaultRequest.get(name: "K", projectId: project.id, environmentName: nil)

        // Denying handler → failure, and a .denied audit entry with nil agent
        // (renders as the human/CLI in the activity log).
        var seen: ApprovalRequest?
        let denied = VaultRequestDispatcher.handle(request, using: vault, caller: .local, approveAgentAccess: { req in
            seen = req
            return false
        })
        guard case let .failure(message) = denied else {
            return XCTFail("a denied human read must fail, got \(denied)")
        }
        XCTAssertTrue(message.contains("approval"), "got: \(message)")
        XCTAssertFalse(message.contains("to an AI agent"), "the human denial must not blame an agent")
        XCTAssertFalse(message.contains("v-secret"))
        XCTAssertNil(seen?.agent, "a human caller's ApprovalRequest carries a nil agent")
        XCTAssertEqual(seen?.perCall, false)
        let denial = try XCTUnwrap(try vault.listActivity().first { $0.action == .denied })
        XCTAssertEqual(denial.secretName, "K")
        XCTAssertNil(denial.agent, "the denial is logged with nil agent (the human/CLI)")

        // Approving handler → the secret.
        let approved = VaultRequestDispatcher.handle(request, using: vault, caller: .local, approveAgentAccess: { _ in true })
        guard case let .secret(secret) = approved else {
            return XCTFail("an approved human read must return the secret, got \(approved)")
        }
        XCTAssertEqual(secret.value, "v-secret")
    }

    func testHumanCallerStrictReadCarriesPerCall() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .strict)

        var seen: ApprovalRequest?
        _ = VaultRequestDispatcher.handle(.get(name: "K", projectId: project.id, environmentName: nil), using: vault, caller: .local, approveAgentAccess: { req in
            seen = req
            return true
        })
        XCTAssertEqual(seen?.perCall, true)
        XCTAssertNil(seen?.agent)
    }

    /// Per-tier grant semantics for a human caller, using a handler that mirrors
    /// `AgentApprovalCoordinator.approve` (grant cache in front of the prompt):
    /// `requiresApproval` prompts once per session, `strict` on every read.
    func testGrantSemanticsPerTierForHumanCaller() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "SESSION", value: "a", projectId: project.id)
        _ = try vault.add(name: "PERCALL", value: "b", projectId: project.id)
        try vault.setAgentAccess(name: "SESSION", projectId: project.id, policy: .requiresApproval)
        try vault.setAgentAccess(name: "PERCALL", projectId: project.id, policy: .strict)

        let cache = ApprovalGrantCache()
        var prompts = 0
        let handler: AgentApprovalHandler = { request in
            if cache.isGranted(request) { return true }
            prompts += 1
            cache.recordGrant(request)
            return true
        }

        let sessionGet = VaultRequest.get(name: "SESSION", projectId: project.id, environmentName: nil)
        _ = VaultRequestDispatcher.handle(sessionGet, using: vault, caller: .local, approveAgentAccess: handler)
        _ = VaultRequestDispatcher.handle(sessionGet, using: vault, caller: .local, approveAgentAccess: handler)
        XCTAssertEqual(prompts, 1, "requiresApproval prompts once per unlock session, for humans too")

        prompts = 0
        let strictGet = VaultRequest.get(name: "PERCALL", projectId: project.id, environmentName: nil)
        _ = VaultRequestDispatcher.handle(strictGet, using: vault, caller: .local, approveAgentAccess: handler)
        _ = VaultRequestDispatcher.handle(strictGet, using: vault, caller: .local, approveAgentAccess: handler)
        XCTAssertEqual(prompts, 2, "strict prompts on every read, for humans too")
    }

    // MARK: - CLI reveal routing (get/copy)

    /// Wraps a vault and counts value fetches, so a test can prove the CLI
    /// never decrypts an approval-tier value in-process.
    private final class SpyVaultService: VaultService {
        let wrapped: Vault
        private(set) var getCalls = 0
        init(wrapping vault: Vault) { self.wrapped = vault }

        func unlock() throws {}
        func resolveProject(name: String?, workingDirectory: String?) throws -> Project { try wrapped.resolveProject(name: name, workingDirectory: workingDirectory) }
        func listProjects() throws -> [Project] { try wrapped.listProjects() }
        func add(name: String, value: String, description: String?, icon: String?, category: SecretCategory?, projectId: String, environmentName: String?) throws -> Secret {
            try wrapped.add(name: name, value: value, description: description, icon: icon, category: category, projectId: projectId, environmentName: environmentName)
        }
        func get(name: String, projectId: String, environmentName: String?) throws -> Secret {
            getCalls += 1
            return try wrapped.get(name: name, projectId: projectId, environmentName: environmentName)
        }
        func set(name: String, value: String, projectId: String, environmentName: String?) throws -> Secret { try wrapped.set(name: name, value: value, projectId: projectId, environmentName: environmentName) }
        func delete(name: String, projectId: String) throws { try wrapped.delete(name: name, projectId: projectId) }
        func list(projectId: String, environmentName: String?) throws -> [Secret] { try wrapped.list(projectId: projectId, environmentName: environmentName) }
        func listInfo(projectId: String) throws -> [SecretInfo] { try wrapped.listInfo(projectId: projectId) }
        func listEnvironments(projectId: String) throws -> [VaultEnvironment] { try wrapped.listEnvironments(projectId: projectId) }
        func setActiveEnvironment(name: String?, projectId: String) throws { try wrapped.setActiveEnvironment(name: name, projectId: projectId) }
        func importEnv(pairs: [(name: String, value: String)], projectId: String, environmentName: String?, overwrite: Bool) throws -> ImportSummary {
            try wrapped.importEnv(pairs: pairs, projectId: projectId, environmentName: environmentName, overwrite: overwrite)
        }
        func logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource, agent: String?, action: ActivityLogEntry.Action) {
            wrapped.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName, source: source, agent: agent, action: action)
        }
    }

    private struct DaemonDown: Error {}

    func testApprovalTierRevealFailsClosedWithoutInProcessFetchWhenDaemonIsDown() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "GATED", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "GATED", projectId: project.id, policy: .requiresApproval)

        let spy = SpyVaultService(wrapping: vault)
        let workspace = SecretWorkspace(vault: spy)
        let context = SecretWorkspaceContext(project: project, environmentName: nil)

        XCTAssertThrowsError(
            try CLIReveal.secret(named: "GATED", in: workspace, context: context, daemonFetch: { _, _ in throw DaemonDown() })
        ) { XCTAssertTrue($0 is DaemonDown) }
        XCTAssertEqual(spy.getCalls, 0, "the value must never be decrypted in-process when the daemon route fails")
    }

    func testApprovalTierRevealRoutesThroughTheDaemon() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "STRICT", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "STRICT", projectId: project.id, policy: .strict)

        let spy = SpyVaultService(wrapping: vault)
        let workspace = SecretWorkspace(vault: spy)
        let context = SecretWorkspaceContext(project: project, environmentName: nil)

        var routed: String?
        let secret = try CLIReveal.secret(named: "STRICT", in: workspace, context: context, daemonFetch: { name, _ in
            routed = name
            return Secret(id: "remote", name: name, value: "daemon-brokered", description: nil, icon: nil, category: .other, agentAccess: .strict)
        })
        XCTAssertEqual(routed, "STRICT")
        XCTAssertEqual(secret.value, "daemon-brokered")
        XCTAssertEqual(spy.getCalls, 0, "an approval-tier reveal must not touch the in-process path")
    }

    func testNonApprovalRevealKeepsTheInProcessPath() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "v-open", projectId: project.id)
        _ = try vault.add(name: "LOCKED", value: "v-locked", projectId: project.id)
        try vault.setAgentAccess(name: "LOCKED", projectId: project.id, policy: .blocked)

        let spy = SpyVaultService(wrapping: vault)
        let workspace = SecretWorkspace(vault: spy)
        let context = SecretWorkspaceContext(project: project, environmentName: nil)
        let daemonFetch: (String, SecretWorkspaceContext) throws -> Secret = { _, _ in
            XCTFail("a non-approval secret must never route through the daemon")
            throw DaemonDown()
        }

        // allowed → in-process, byte-identical to before.
        let open = try CLIReveal.secret(named: "OPEN", in: workspace, context: context, daemonFetch: daemonFetch)
        XCTAssertEqual(open.value, "v-open")
        // blocked → still fetched in-process (the agent refusal lives in
        // enforceAgentRevealPolicy, unchanged; a human prints it).
        let locked = try CLIReveal.secret(named: "LOCKED", in: workspace, context: context, daemonFetch: daemonFetch)
        XCTAssertEqual(locked.value, "v-locked")
        XCTAssertEqual(spy.getCalls, 2)
    }

    func testDaemonUnreachableMessagePointsAtOpeningLokalite() {
        let message = CLIReveal.daemonUnreachableMessage(secretName: "GATED")
        XCTAssertTrue(message.contains("GATED"))
        XCTAssertTrue(message.contains("approval"))
        XCTAssertTrue(message.contains("Open Lokalite"), "the refusal must name the fix")
    }

    // MARK: - Bulk paths exclude approval-tier secrets

    func testBulkRevealExcludesApprovalTierAndNamesThem() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "a", projectId: project.id)
        _ = try vault.add(name: "LOCKED", value: "b", projectId: project.id)
        _ = try vault.add(name: "GATED", value: "c", projectId: project.id)
        _ = try vault.add(name: "PERCALL", value: "d", projectId: project.id)
        try vault.setAgentAccess(name: "LOCKED", projectId: project.id, policy: .blocked)
        try vault.setAgentAccess(name: "GATED", projectId: project.id, policy: .requiresApproval)
        try vault.setAgentAccess(name: "PERCALL", projectId: project.id, policy: .strict)
        let workspace = SecretWorkspace(vault: vault)
        let context = SecretWorkspaceContext(project: project, environmentName: nil)

        // All secrets: both approval tiers are skipped; blocked stays (the human
        // bulk paths are agent-gated wholesale by ensureNotAgentExfil, and
        // blocked means off-limits to agents, not to the owner).
        let all = try bulkRevealSecrets(named: nil, context: context, workspace: workspace, accessSource: nil)
        XCTAssertEqual(Set(all.released.map(\.name)), ["OPEN", "LOCKED"])
        XCTAssertEqual(Set(all.skippedApprovalTier), ["GATED", "PERCALL"])

        // Explicit key list: requested approval-tier names are skipped, not fetched.
        let named = try bulkRevealSecrets(named: ["OPEN", "GATED"], context: context, workspace: workspace, accessSource: nil)
        XCTAssertEqual(named.released.map(\.name), ["OPEN"])
        XCTAssertEqual(named.skippedApprovalTier, ["GATED"])
    }

    func testBulkRevealLogsOnlyReleasedSecrets() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "a", projectId: project.id)
        _ = try vault.add(name: "GATED", value: "b", projectId: project.id)
        try vault.setAgentAccess(name: "GATED", projectId: project.id, policy: .requiresApproval)
        let workspace = SecretWorkspace(vault: vault)
        let context = SecretWorkspaceContext(project: project, environmentName: nil)

        _ = try bulkRevealSecrets(named: nil, context: context, workspace: workspace, accessSource: .cli)
        let logged = try vault.listActivity().map(\.secretName)
        XCTAssertEqual(logged, ["OPEN"], "a skipped secret must not be stamped as read")
    }

    func testApprovalTierSkipNoticeNamesSecretsAndNeverValues() throws {
        XCTAssertNil(approvalTierSkipNotice([]))
        let notice = try XCTUnwrap(approvalTierSkipNotice(["GATED", "PERCALL"]))
        XCTAssertTrue(notice.contains("GATED"))
        XCTAssertTrue(notice.contains("PERCALL"))
        XCTAssertTrue(notice.contains("approval"))
        XCTAssertTrue(notice.contains("lokalite get"), "the notice points at the per-secret consent paths")
    }

    // MARK: - Export/backup exclusion seam

    func testExportExcludingApprovalTierOmitsSecretsAndNamesThem() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "OPEN", value: "v-open", projectId: project.id)
        _ = try vault.add(name: "GATED", value: "v-gated", projectId: project.id)
        try vault.setAgentAccess(name: "GATED", projectId: project.id, policy: .strict)

        // Plain (used by `export --plain`): the payload omits the secret.
        let plain = try vault.exportExcludingApprovalTier(projectId: project.id, passphrase: nil)
        let dict = try XCTUnwrap(try JSONSerialization.jsonObject(with: plain.data) as? [String: String])
        XCTAssertEqual(dict, ["OPEN": "v-open"])
        XCTAssertEqual(plain.skippedNames, ["GATED"])

        // Encrypted (used by `backup`): a restore of the file will not contain it.
        let encrypted = try vault.exportExcludingApprovalTier(projectId: project.id, passphrase: "pw")
        XCTAssertEqual(try vault.decryptExport(encrypted.data, passphrase: "pw"), ["OPEN": "v-open"])
        XCTAssertEqual(encrypted.skippedNames, ["GATED"])

        // The encrypted `lokalite export` path is unchanged: everything included.
        let full = try vault.export(projectId: project.id, passphrase: "pw")
        XCTAssertEqual(try vault.decryptExport(full, passphrase: "pw"), ["OPEN": "v-open", "GATED": "v-gated"])
    }
}
