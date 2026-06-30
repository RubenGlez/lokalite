import XCTest
@testable import LokaliteCore
@testable import lokalite

final class SecretWorkspaceProjectsTests: XCTestCase {
    func testListProjectsReturnsAddedProjects() throws {
        let vault = try makeVault()
        let workspace = SecretWorkspace(vault: vault)

        _ = try vault.addProject(name: "App", path: "/tmp/app")
        _ = try vault.addProject(name: "Unlinked", path: nil)

        let projects = try workspace.listProjects()
        XCTAssertTrue(Set(["App", "Unlinked"]).isSubset(of: Set(projects.map(\.name))))
        XCTAssertEqual(projects.first(where: { $0.name == "App" })?.path, "/tmp/app")
        XCTAssertNil(projects.first(where: { $0.name == "Unlinked" })?.path)
    }

    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }
}

final class MCPToolDefinitionsTests: XCTestCase {
    func testReadOnlyToolsExposeDiscoveryAndNoWriteTools() {
        let names = LokaliteMCPTools(allowWrites: false).definitions.compactMap { $0["name"] as? String }
        XCTAssertEqual(Set(names), ["get_secret", "list_secrets", "list_projects", "list_environments", "use_environment"])
    }

    func testWriteToolsAppearOnlyWithReadWrite() {
        let names = LokaliteMCPTools(allowWrites: true).definitions.compactMap { $0["name"] as? String }
        XCTAssertTrue(Set(["add_secret", "set_secret", "delete_secret"]).isSubset(of: Set(names)))
    }

    func testGetSecretDescribesHandoffNotReveal() {
        let getSecret = LokaliteMCPTools(allowWrites: false).definitions
            .first { $0["name"] as? String == "get_secret" }
        let description = getSecret?["description"] as? String ?? ""
        XCTAssertTrue(description.contains("source"), "get_secret should return a source command, not the value")
        XCTAssertTrue(description.lowercased().contains("does not return the value"))
    }

    func testServerInstructionsCoverTheHandoffFlow() {
        let instructions = MCPServer.instructions
        XCTAssertTrue(instructions.contains("source '<path>'"))
        XCTAssertTrue(instructions.contains("list_projects"))
        XCTAssertTrue(instructions.lowercased().contains("never this chat"))
    }
}

final class MCPClientRegistrationTests: XCTestCase {
    func testClaudeDesktopUsesTheStandardConfigPath() {
        let url = MCPClient.claudeDesktop.configURL(home: URL(fileURLWithPath: "/Users/test"))
        XCTAssertEqual(url.path, "/Users/test/Library/Application Support/Claude/claude_desktop_config.json")
    }

    func testSupportedClients() {
        XCTAssertEqual(Set(MCPClient.allCases.map(\.rawValue)), ["claude", "claude-desktop", "cursor", "windsurf"])
    }
}

final class MCPSecretHandoffTests: XCTestCase {
    func testWriteReturnsSourceCommandForAnOwnerOnlyScript() throws {
        let command = try MCPSecretHandoff.write([("API_KEY", "sk-12345")])

        XCTAssertTrue(command.hasPrefix("source '"))
        let path = String(command.dropFirst("source '".count).dropLast())
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }

        let script = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(script.contains("export API_KEY='sk-12345'"))
        XCTAssertTrue(script.contains("rm -f -- '\(path)'"), "script should delete itself on source")

        let perms = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600)
    }

    func testValueNeverAppearsInTheReturnedCommand() throws {
        let command = try MCPSecretHandoff.write([("TOKEN", "super-secret-value")])
        let path = String(command.dropFirst("source '".count).dropLast())
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertFalse(command.contains("super-secret-value"), "the value must not be in the tool response")
    }

    func testSingleQuotesInValueAreEscaped() throws {
        let command = try MCPSecretHandoff.write([("Q", "a'b")])
        let path = String(command.dropFirst("source '".count).dropLast())
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }

        let script = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(script.contains("export Q='a'\\''b'"))
    }
}

// MARK: - Phase 1 seam (ADR 0014)

/// Proves SecretWorkspace depends on the VaultService protocol, not concrete Vault —
/// the swap point where a socket-backed RemoteVaultService slots in for phase 2.
final class VaultServiceSeamTests: XCTestCase {
    func testSecretWorkspaceRoutesThroughInjectedService() throws {
        let stub = StubVaultService(cannedValue: "canned-123")
        let workspace = SecretWorkspace(vault: stub)
        let context = SecretWorkspaceContext(project: Project(id: "p1", name: "App"), environmentName: "Default")

        let secret = try workspace.get(name: "API_KEY", context: context, accessSource: .mcp)

        XCTAssertEqual(secret.value, "canned-123")
        XCTAssertEqual(stub.getCalls, ["API_KEY"])
        XCTAssertEqual(stub.loggedAccess, ["API_KEY"], "access should be logged through the service")
    }
}

private final class StubVaultService: VaultService {
    private(set) var getCalls: [String] = []
    private(set) var loggedAccess: [String] = []
    private let cannedValue: String

    init(cannedValue: String) { self.cannedValue = cannedValue }

    func unlock() throws {}
    func resolveProject(name: String?, workingDirectory: String?) throws -> Project { Project(id: "p1", name: "App") }
    func listProjects() throws -> [Project] { [Project(id: "p1", name: "App")] }
    func get(name: String, projectId: String, environmentName: String?) throws -> Secret {
        getCalls.append(name)
        return Secret(name: name, value: cannedValue)
    }
    func logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource, agent: String?, action: ActivityLogEntry.Action) {
        loggedAccess.append(secretName)
    }
    func add(name: String, value: String, description: String?, icon: String?, category: SecretCategory?, projectId: String, environmentName: String?) throws -> Secret { throw StubError.unexpected }
    func set(name: String, value: String, projectId: String, environmentName: String?) throws -> Secret { throw StubError.unexpected }
    func delete(name: String, projectId: String) throws { throw StubError.unexpected }
    func list(projectId: String, environmentName: String?) throws -> [Secret] { throw StubError.unexpected }
    func listInfo(projectId: String) throws -> [SecretInfo] { throw StubError.unexpected }
    func listEnvironments(projectId: String) throws -> [VaultEnvironment] { throw StubError.unexpected }
    func setActiveEnvironment(name: String?, projectId: String) throws { throw StubError.unexpected }
    func importEnv(pairs: [(name: String, value: String)], projectId: String, environmentName: String?, overwrite: Bool) throws -> ImportSummary { throw StubError.unexpected }

    enum StubError: Error { case unexpected }
}
