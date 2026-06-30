import XCTest
@testable import LokaliteCore

final class VaultWireProtocolTests: XCTestCase {
    func testRequestsRoundTripThroughJSON() throws {
        let requests: [VaultRequest] = [
            .unlock,
            .listProjects,
            .resolveProject(name: "App", workingDirectory: "/tmp/app"),
            .get(name: "API_KEY", projectId: "p1", environmentName: nil),
            .add(name: "K", value: "v", description: "d", icon: nil, category: .apiKey, projectId: "p1", environmentName: "prod"),
            .set(name: "K", value: "v2", projectId: "p1", environmentName: nil),
            .delete(name: "K", projectId: "p1"),
            .listInfo(projectId: "p1"),
            .importEnv(pairs: [EnvPair(name: "A", value: "1")], projectId: "p1", environmentName: nil, overwrite: true),
            .logAccess(secretName: "K", projectName: "App", environmentName: "Default", source: .mcp, action: .read),
        ]
        for request in requests {
            let data = try JSONEncoder().encode(request)
            XCTAssertEqual(try JSONDecoder().decode(VaultRequest.self, from: data), request)
        }
    }

    func testResponsesRoundTripThroughJSON() throws {
        let responses: [VaultResponse] = [
            .ok,
            .secret(Secret(name: "K", value: "v")),
            .secrets([Secret(name: "A", value: "1")]),
            .project(Project(id: "p1", name: "App")),
            .projects([Project(id: "p1", name: "App")]),
            .secretInfos([SecretInfo(name: "K", description: nil, icon: nil, category: .other)]),
            .importSummary(ImportSummary(added: 1, updated: 0, skipped: 2)),
            .failure(message: "nope"),
        ]
        for response in responses {
            let data = try JSONEncoder().encode(response)
            XCTAssertEqual(try JSONDecoder().decode(VaultResponse.self, from: data), response)
        }
    }
}

/// Exercises the entire request → dispatch → response → result loop that the
/// socket will carry, but in-process: a RemoteVaultService whose transport is the
/// dispatcher against a real temp-store Vault. No socket, no Keychain.
final class RemoteVaultServiceLoopTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    func testAddListGetRoundTripThroughTheLoop() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: "/tmp/app")
        let remote = RemoteVaultService(transport: { VaultRequestDispatcher.handle($0, using: vault) })

        _ = try remote.add(name: "API_KEY", value: "sk-1", description: nil, icon: nil, category: nil, projectId: project.id, environmentName: nil)

        XCTAssertEqual(try remote.list(projectId: project.id, environmentName: nil).map(\.name), ["API_KEY"])
        XCTAssertEqual(try remote.get(name: "API_KEY", projectId: project.id, environmentName: nil).value, "sk-1")
        XCTAssertTrue(try remote.listProjects().map(\.name).contains("App"))
    }

    func testDaemonSideErrorSurfacesAsRemoteVaultError() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        let remote = RemoteVaultService(transport: { VaultRequestDispatcher.handle($0, using: vault) })

        XCTAssertThrowsError(try remote.get(name: "MISSING", projectId: project.id, environmentName: nil)) { error in
            guard case RemoteVaultError.daemon(let message) = error else {
                return XCTFail("expected a daemon error, got \(error)")
            }
            XCTAssertTrue(message.contains("MISSING"))
        }
    }
}
