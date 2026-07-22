import XCTest
@testable import LokaliteCore
@testable import lokalite

final class ActivityLogTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    // MARK: - Model / migration v6

    func testLogAccessPersistsAgentAndAction() throws {
        let vault = try makeVault()
        vault.logAccess(secretName: "K", projectName: "App", environmentName: "prod", source: .mcp, agent: "claude", action: .read)
        vault.logAccess(secretName: "K", projectName: "App", environmentName: "prod", source: .app)

        let entries = try vault.listActivity()
        // Default-argument call defaults to a human read.
        XCTAssertEqual(entries.count, 2)
        let mcp = entries.first { $0.source == .mcp }
        XCTAssertEqual(mcp?.agent, "claude")
        XCTAssertEqual(mcp?.action, .read)
        let app = entries.first { $0.source == .app }
        XCTAssertNil(app?.agent)
        XCTAssertEqual(app?.action, .read)
    }

    // MARK: - Daemon stamps the agent un-forgeably

    func testDaemonStampsCallerAgentOnLogAccess() throws {
        let vault = try makeVault()
        // The client never sends an agent; the daemon overrides from CallerContext.
        let request = VaultRequest.logAccess(secretName: "K", projectName: "App", environmentName: "prod", source: .mcp, action: .read)
        _ = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 42, agent: "cursor"))

        let entry = try XCTUnwrap(try vault.listActivity().first)
        XCTAssertEqual(entry.agent, "cursor")
    }

    // MARK: - Denials are recorded with the agent

    func testDaemonLogsDenialForBlockedAgentRead() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "STRIPE", value: "sk-live", projectId: project.id)
        try vault.setAgentAccess(name: "STRIPE", projectId: project.id, policy: .blocked)
        let request = VaultRequest.get(name: "STRIPE", projectId: project.id, environmentName: nil)

        _ = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 1, agent: "claude"))

        let entry = try XCTUnwrap(try vault.listActivity().first { $0.action == .denied })
        XCTAssertEqual(entry.agent, "claude")
        XCTAssertEqual(entry.secretName, "STRIPE")
        XCTAssertEqual(entry.projectName, "App")
    }

    func testDaemonLogsDenialWhenApprovalRefused() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "DB", value: "secret", projectId: project.id)
        try vault.setAgentAccess(name: "DB", projectId: project.id, policy: .requiresApproval)
        let request = VaultRequest.get(name: "DB", projectId: project.id, environmentName: nil)

        _ = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 1, agent: "claude"), approveAgentAccess: { _ in false })

        let entry = try XCTUnwrap(try vault.listActivity().first { $0.action == .denied })
        XCTAssertEqual(entry.agent, "claude")
        XCTAssertEqual(entry.secretName, "DB")
    }

    func testApprovedReadIsNotLoggedAsDenied() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "DB", value: "secret", projectId: project.id)
        try vault.setAgentAccess(name: "DB", projectId: project.id, policy: .requiresApproval)
        let request = VaultRequest.get(name: "DB", projectId: project.id, environmentName: nil)

        let response = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 1, agent: "claude"), approveAgentAccess: { _ in true })
        guard case .secret = response else { return XCTFail("approved read should return the secret") }
        // The .get path itself does not log a read (the client logs it); crucially no denial was recorded.
        XCTAssertTrue(try vault.listActivity().allSatisfy { $0.action != .denied })
    }

    // MARK: - Writes are logged

    func testWorkspaceLogsWriteActions() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        let workspace = SecretWorkspace(vault: vault)
        let ctx = SecretWorkspaceContext(project: project, environmentName: nil)

        _ = try workspace.add(name: "K", value: "v1", context: ctx, accessSource: .cli)
        _ = try workspace.set(name: "K", value: "v2", context: ctx, accessSource: .cli)
        try workspace.delete(name: "K", context: ctx, accessSource: .cli)

        let actions = try vault.listActivity().map(\.action)
        XCTAssertEqual(Set(actions), [.created, .updated, .deleted])
    }

    func testWorkspaceWritesAreNotLoggedWithoutAccessSource() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        let workspace = SecretWorkspace(vault: vault)
        let ctx = SecretWorkspaceContext(project: project, environmentName: nil)

        _ = try workspace.add(name: "K", value: "v1", context: ctx)

        XCTAssertTrue(try vault.listActivity().isEmpty, "no source → no audit entry (preserves existing callers)")
    }

    // MARK: - Filtering

    func testListActivityFiltersByProjectSourceAndAction() throws {
        let vault = try makeVault()
        vault.logAccess(secretName: "A", projectName: "App", environmentName: "prod", source: .cli, action: .read)
        vault.logAccess(secretName: "B", projectName: "App", environmentName: "prod", source: .mcp, agent: "claude", action: .denied)
        vault.logAccess(secretName: "C", projectName: "Site", environmentName: "dev", source: .app, action: .created)

        let byProject = try vault.listActivity(filter: ActivityFilter(projectName: "App"))
        XCTAssertEqual(Set(byProject.map(\.secretName)), ["A", "B"])

        let bySource = try vault.listActivity(filter: ActivityFilter(source: .mcp))
        XCTAssertEqual(bySource.map(\.secretName), ["B"])

        let byAction = try vault.listActivity(filter: ActivityFilter(action: .created))
        XCTAssertEqual(byAction.map(\.secretName), ["C"])

        // Filters combine, and a contradictory combination yields nothing.
        XCTAssertTrue(try vault.listActivity(filter: ActivityFilter(projectName: "Site", source: .cli)).isEmpty)
    }

    func testListActivitySearchMatchesSecretEnvironmentAndAgent() throws {
        let vault = try makeVault()
        vault.logAccess(secretName: "STRIPE_KEY", projectName: "App", environmentName: "prod", source: .cli)
        vault.logAccess(secretName: "DB_URL", projectName: "App", environmentName: "staging", source: .mcp, agent: "cursor")

        XCTAssertEqual(try vault.listActivity(filter: ActivityFilter(search: "stripe")).map(\.secretName), ["STRIPE_KEY"])
        XCTAssertEqual(try vault.listActivity(filter: ActivityFilter(search: "staging")).map(\.secretName), ["DB_URL"])
        XCTAssertEqual(try vault.listActivity(filter: ActivityFilter(search: "curs")).map(\.secretName), ["DB_URL"])
        XCTAssertEqual(try vault.listActivity(filter: ActivityFilter(search: "   ")).count, 2, "a blank search is not a filter")
    }

    // MARK: - MCP denial logging (client side, for the blocked pre-check)

    func testMCPGetSecretLogsDenialForBlockedSecret() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "STRIPE", value: "sk-live", projectId: project.id)
        try vault.setAgentAccess(name: "STRIPE", projectId: project.id, policy: .blocked)

        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)
        _ = tools.call(name: "get_secret", args: ["name": "STRIPE", "project": "App"])

        let entry = try XCTUnwrap(try vault.listActivity().first { $0.action == .denied })
        XCTAssertEqual(entry.source, .mcp)
        XCTAssertEqual(entry.secretName, "STRIPE")
    }
}
