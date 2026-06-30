import XCTest
@testable import LokaliteCore
@testable import lokalite

final class EnvironmentSwitchingTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    /// A project "App" with a Default (active) and a staging environment, and a
    /// secret "DB" whose value differs per environment.
    private func makeProjectWithTwoEnvironments(_ vault: Vault) throws -> Project {
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.addEnvironment(name: "staging", projectId: project.id)
        _ = try vault.add(name: "DB", value: "dev-val", projectId: project.id, environmentName: nil)
        _ = try vault.set(name: "DB", value: "stg-val", projectId: project.id, environmentName: "staging")
        return project
    }

    // MARK: - Dispatcher / wire

    func testDispatcherListsAndSetsActiveEnvironment() throws {
        let vault = try makeVault()
        let project = try makeProjectWithTwoEnvironments(vault)

        let listed = VaultRequestDispatcher.handle(.listEnvironments(projectId: project.id), using: vault)
        guard case let .environments(envs) = listed else { return XCTFail("expected environments, got \(listed)") }
        XCTAssertEqual(Set(envs.map(\.name)), ["Default", "staging"])

        let set = VaultRequestDispatcher.handle(.setActiveEnvironment(name: "staging", projectId: project.id), using: vault)
        guard case .ok = set else { return XCTFail("expected ok, got \(set)") }
        XCTAssertEqual(try vault.listProjects().first?.activeEnvironment, "staging")
    }

    func testRemoteServiceRoundTripsEnvironmentOps() throws {
        let vault = try makeVault()
        let project = try makeProjectWithTwoEnvironments(vault)
        let remote = RemoteVaultService(transport: { VaultRequestDispatcher.handle($0, using: vault) })

        XCTAssertEqual(Set(try remote.listEnvironments(projectId: project.id).map(\.name)), ["Default", "staging"])
        try remote.setActiveEnvironment(name: "staging", projectId: project.id)
        XCTAssertEqual(try vault.listProjects().first?.activeEnvironment, "staging")
    }

    // MARK: - MCP tools

    func testUseEnvironmentSwitchesActiveEnvironmentAndResolution() throws {
        let vault = try makeVault()
        _ = try makeProjectWithTwoEnvironments(vault)
        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)
        let workspace = SecretWorkspace(vault: vault)

        // Before: active is Default → resolves the dev value.
        let before = try workspace.get(name: "DB", context: try workspace.resolveContext(projectName: "App"))
        XCTAssertEqual(before.value, "dev-val")

        let result = tools.call(name: "use_environment", args: ["name": "staging", "project": "App"])
        guard case let .success(payload) = result else { return XCTFail("expected success") }
        XCTAssertNil(payload["isError"])

        // After: active is staging, so default resolution returns the staging value.
        XCTAssertEqual(try vault.listProjects().first?.activeEnvironment, "staging")
        let after = try workspace.get(name: "DB", context: try workspace.resolveContext(projectName: "App"))
        XCTAssertEqual(after.value, "stg-val")
    }

    func testUseEnvironmentRejectsUnknownEnvironmentWithoutChangingActive() throws {
        let vault = try makeVault()
        _ = try makeProjectWithTwoEnvironments(vault)
        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)

        let result = tools.call(name: "use_environment", args: ["name": "prod", "project": "App"])
        guard case let .success(payload) = result else { return XCTFail("expected success") }
        XCTAssertEqual(payload["isError"] as? Bool, true)
        let text = (payload["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined() ?? ""
        XCTAssertTrue(text.contains("not found"), "got: \(text)")
        XCTAssertTrue(text.contains("Default") && text.contains("staging"), "should list available envs, got: \(text)")
        // Active environment unchanged.
        XCTAssertEqual(try vault.listProjects().first?.activeEnvironment, "Default")
    }

    func testListEnvironmentsMarksActive() throws {
        let vault = try makeVault()
        _ = try makeProjectWithTwoEnvironments(vault)
        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)

        let result = tools.call(name: "list_environments", args: ["project": "App"])
        guard case let .success(payload) = result else { return XCTFail("expected success") }
        let text = (payload["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined() ?? ""
        let activeLine = text.split(separator: "\n").first { $0.contains("Default") } ?? ""
        XCTAssertTrue(activeLine.contains("[active]"), "Default should be marked active, got: \(text)")
        let stagingLine = text.split(separator: "\n").first { $0.contains("staging") } ?? ""
        XCTAssertFalse(stagingLine.contains("[active]"))
    }

    func testPerCallEnvironmentDoesNotChangeActive() throws {
        let vault = try makeVault()
        _ = try makeProjectWithTwoEnvironments(vault)
        let tools = LokaliteMCPTools(allowWrites: false, vault: vault)

        // A one-off get against staging must not move the active environment.
        let result = tools.call(name: "get_secret", args: ["name": "DB", "project": "App", "environment": "staging"])
        guard case .success = result else { return XCTFail("expected success") }
        XCTAssertEqual(try vault.listProjects().first?.activeEnvironment, "Default")
    }

    func testNewMCPToolsAreAvailableInReadOnlyMode() {
        let names = LokaliteMCPTools(allowWrites: false).definitions.compactMap { $0["name"] as? String }
        XCTAssertTrue(names.contains("use_environment"))
        XCTAssertTrue(names.contains("list_environments"))
    }

    // MARK: - Live app sync

    func testSetActiveEnvironmentPostsSyncNotification() throws {
        let vault = try makeVault()
        let project = try makeProjectWithTwoEnvironments(vault)

        let expectation = XCTNSNotificationExpectation(name: .lokaliteActiveEnvironmentDidChange)
        try vault.setActiveEnvironment(name: "staging", projectId: project.id)
        wait(for: [expectation], timeout: 2.0)
    }
}
