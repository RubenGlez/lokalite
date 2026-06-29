import XCTest
@testable import LokaliteCore

/// Exercises the real Unix-socket transport in-process: a VaultSocketServer
/// backed by a temp-store Vault, driven by a RemoteVaultService over a
/// VaultSocketClient. No Keychain, no GUI — just an actual socket round-trip.
final class VaultSocketTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    private func makeSocketPath() throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("daemon.sock").path
    }

    func testRoundTripOverRealSocket() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        let socketPath = try makeSocketPath()

        let server = VaultSocketServer(socketPath: socketPath, service: vault)
        try server.start()
        addTeardownBlock { server.stop() }

        let remote = RemoteVaultService(transport: VaultSocketClient(socketPath: socketPath).send)

        _ = try remote.add(name: "API_KEY", value: "sk-9", description: nil, icon: nil, category: nil, projectId: project.id, environmentName: nil)
        XCTAssertEqual(try remote.get(name: "API_KEY", projectId: project.id, environmentName: nil).value, "sk-9")
        XCTAssertEqual(try remote.list(projectId: project.id, environmentName: nil).map(\.name), ["API_KEY"])
        XCTAssertTrue(try remote.listProjects().map(\.name).contains("App"))
    }

    func testErrorFromDaemonPropagatesOverSocket() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        let socketPath = try makeSocketPath()

        let server = VaultSocketServer(socketPath: socketPath, service: vault)
        try server.start()
        addTeardownBlock { server.stop() }

        let remote = RemoteVaultService(transport: VaultSocketClient(socketPath: socketPath).send)
        XCTAssertThrowsError(try remote.get(name: "MISSING", projectId: project.id, environmentName: nil)) { error in
            guard case RemoteVaultError.daemon(let message) = error else {
                return XCTFail("expected daemon error, got \(error)")
            }
            XCTAssertTrue(message.contains("MISSING"))
        }
    }

    func testClientFailsWhenDaemonNotRunning() {
        let client = VaultSocketClient(socketPath: "/tmp/lokalite-missing-\(UUID().uuidString).sock")
        XCTAssertThrowsError(try client.send(.listProjects))
    }
}
