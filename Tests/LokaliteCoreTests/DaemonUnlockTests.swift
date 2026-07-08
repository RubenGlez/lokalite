import XCTest
@testable import LokaliteCore

/// Simulates the daemon's vault lock state at the service seam: key-needing
/// operations throw `.vaultLocked` until the gate opens, and `unlock()` records
/// every call so a test can prove nothing loads the key silently. Metadata
/// operations (projects, info, environments) pass through ungated, like the
/// real store.
private final class LockGatedVaultService: VaultService {
    private let base: Vault
    var locked = true
    var unlockCalls = 0

    init(base: Vault) { self.base = base }

    func unlock() throws {
        unlockCalls += 1
        locked = false
    }

    private func requireUnlocked() throws {
        if locked { throw VaultError.vaultLocked }
    }

    func resolveProject(name: String?, workingDirectory: String?) throws -> Project {
        try base.resolveProject(name: name, workingDirectory: workingDirectory)
    }
    func listProjects() throws -> [Project] { try base.listProjects() }
    func add(name: String, value: String, description: String?, icon: String?, category: SecretCategory?, projectId: String, environmentName: String?) throws -> Secret {
        try requireUnlocked()
        return try base.add(name: name, value: value, description: description, icon: icon, category: category, projectId: projectId, environmentName: environmentName)
    }
    func get(name: String, projectId: String, environmentName: String?) throws -> Secret {
        try requireUnlocked()
        return try base.get(name: name, projectId: projectId, environmentName: environmentName)
    }
    func set(name: String, value: String, projectId: String, environmentName: String?) throws -> Secret {
        try requireUnlocked()
        return try base.set(name: name, value: value, projectId: projectId, environmentName: environmentName)
    }
    func delete(name: String, projectId: String) throws {
        try requireUnlocked()
        try base.delete(name: name, projectId: projectId)
    }
    func list(projectId: String, environmentName: String?) throws -> [Secret] {
        try requireUnlocked()
        return try base.list(projectId: projectId, environmentName: environmentName)
    }
    func listInfo(projectId: String) throws -> [SecretInfo] { try base.listInfo(projectId: projectId) }
    func listEnvironments(projectId: String) throws -> [VaultEnvironment] { try base.listEnvironments(projectId: projectId) }
    func setActiveEnvironment(name: String?, projectId: String) throws {
        try base.setActiveEnvironment(name: name, projectId: projectId)
    }
    func importEnv(pairs: [(name: String, value: String)], projectId: String, environmentName: String?, overwrite: Bool) throws -> ImportSummary {
        try requireUnlocked()
        return try base.importEnv(pairs: pairs, projectId: projectId, environmentName: environmentName, overwrite: overwrite)
    }
    func logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource, agent: String?, peerTeamID: String?, action: ActivityLogEntry.Action) {
        base.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName, source: source, agent: agent, peerTeamID: peerTeamID, action: action)
    }
}

/// The dispatcher's locked-vault brokering: a request that needs the key fails
/// closed without an unlock broker, prompts and retries with one, and the wire
/// `.unlock` never silently loads the key.
final class DaemonLockedVaultTests: XCTestCase {
    private func makeLockedService() throws -> (service: LockGatedVaultService, projectId: String) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        let vault = Vault(store: store, key: VaultCrypto.generateKey())
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "API_KEY", value: "sk-1", projectId: project.id)
        return (LockGatedVaultService(base: vault), project.id)
    }

    func testLockedReadFailsClosedWithoutUnlockBroker() throws {
        let (service, projectId) = try makeLockedService()

        let response = VaultRequestDispatcher.handle(.get(name: "API_KEY", projectId: projectId, environmentName: nil), using: service)

        guard case let .failure(message) = response else {
            return XCTFail("expected a failure, got \(response)")
        }
        XCTAssertTrue(message.contains("locked"))
        XCTAssertEqual(service.unlockCalls, 0)
        XCTAssertTrue(service.locked)
    }

    func testLockedReadBrokersUnlockAndRetries() throws {
        let (service, projectId) = try makeLockedService()
        var promptedAgents: [String?] = []
        let broker: VaultUnlockHandler = { agent in
            promptedAgents.append(agent)
            try? service.unlock()
            return true
        }
        let caller = CallerContext(pid: nil, agent: "claude")

        let response = VaultRequestDispatcher.handle(.get(name: "API_KEY", projectId: projectId, environmentName: nil), using: service, caller: caller, requestUnlock: broker)

        guard case let .secret(secret) = response else {
            return XCTFail("expected the secret after the brokered unlock, got \(response)")
        }
        XCTAssertEqual(secret.value, "sk-1")
        XCTAssertEqual(promptedAgents, ["claude"])
        XCTAssertEqual(service.unlockCalls, 1)
    }

    func testDeniedUnlockFailsWithoutTouchingTheVault() throws {
        let (service, projectId) = try makeLockedService()
        var prompts = 0
        let broker: VaultUnlockHandler = { _ in
            prompts += 1
            return false
        }

        let response = VaultRequestDispatcher.handle(.get(name: "API_KEY", projectId: projectId, environmentName: nil), using: service, requestUnlock: broker)

        guard case let .failure(message) = response else {
            return XCTFail("expected a failure, got \(response)")
        }
        XCTAssertTrue(message.contains("not approved"))
        XCTAssertEqual(prompts, 1)
        XCTAssertEqual(service.unlockCalls, 0)
        XCTAssertTrue(service.locked)
    }

    func testWireUnlockIsAHandshakeNotASilentUnlock() throws {
        let (service, _) = try makeLockedService()

        let response = VaultRequestDispatcher.handle(.unlock, using: service)

        guard case .ok = response else {
            return XCTFail("expected .ok, got \(response)")
        }
        XCTAssertEqual(service.unlockCalls, 0)
        XCTAssertTrue(service.locked)
    }

    func testBrokerThatGrantsWithoutUnlockingFailsInsteadOfLooping() throws {
        let (service, projectId) = try makeLockedService()

        // A broker that claims success but never unlocks: the single retry must
        // surface the locked error, not prompt again or spin.
        var prompts = 0
        let broker: VaultUnlockHandler = { _ in
            prompts += 1
            return true
        }

        let response = VaultRequestDispatcher.handle(.get(name: "API_KEY", projectId: projectId, environmentName: nil), using: service, requestUnlock: broker)

        guard case let .failure(message) = response else {
            return XCTFail("expected a failure, got \(response)")
        }
        XCTAssertTrue(message.contains("locked"))
        XCTAssertEqual(prompts, 1)
    }
}
