import XCTest
@testable import LokaliteCore
#if canImport(Darwin)
import Darwin
#endif

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

    func testConcurrentClientsAreServedWithoutRaces() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v", projectId: project.id)
        let socketPath = try makeSocketPath()

        let server = VaultSocketServer(socketPath: socketPath, service: vault)
        try server.start()
        addTeardownBlock { server.stop() }

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "clients", attributes: .concurrent)
        for _ in 0..<20 {
            queue.async(group: group) {
                let remote = RemoteVaultService(transport: VaultSocketClient(socketPath: socketPath).send)
                _ = try? remote.get(name: "K", projectId: project.id, environmentName: nil)
                _ = try? remote.listProjects()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 15), .success)
    }

    // MARK: - Wire frames (ADR 0018: envelope-first decode, bare fallback)

    func testDecodeFrameReadsEnvelopeWithHint() throws {
        let request = VaultRequest.get(name: "K", projectId: "p1", environmentName: nil)
        let data = try JSONEncoder().encode(VaultEnvelope(agentContext: "agent", request: request))
        let frame = try XCTUnwrap(VaultSocketServer.decodeFrame(data))
        XCTAssertEqual(frame.request, request)
        XCTAssertEqual(frame.agentContext, "agent")
    }

    func testDecodeFrameFallsBackToBareRequest() throws {
        // Legacy clients send bare VaultRequest frames; they must keep working.
        let request = VaultRequest.listProjects
        let data = try JSONEncoder().encode(request)
        let frame = try XCTUnwrap(VaultSocketServer.decodeFrame(data))
        XCTAssertEqual(frame.request, request)
        XCTAssertNil(frame.agentContext)
    }

    func testDecodeFrameRejectsGarbage() {
        // serve answers a nil decode with the "Malformed request." failure.
        XCTAssertNil(VaultSocketServer.decodeFrame(Data("not json at all".utf8)))
        XCTAssertNil(VaultSocketServer.decodeFrame(Data("{\"nope\":true}".utf8)))
    }

    func testHintlessClientFramesAreByteIdenticalToBareRequests() throws {
        // A client without a hint must stay wire-compatible with an old daemon.
        let request = VaultRequest.get(name: "K", projectId: "p1", environmentName: "prod")
        let client = VaultSocketClient(socketPath: "/tmp/unused.sock")
        XCTAssertNil(client.agentContext)
        XCTAssertEqual(try client.encodeFrame(request), try JSONEncoder().encode(request))
    }

    func testHintedClientFramesAreEnvelopes() throws {
        let request = VaultRequest.listProjects
        let client = VaultSocketClient(socketPath: "/tmp/unused.sock", agentContext: "claude")
        let envelope = try JSONDecoder().decode(VaultEnvelope.self, from: try client.encodeFrame(request))
        XCTAssertEqual(envelope, VaultEnvelope(agentContext: "claude", request: request))
    }

    func testHintedClientIsEnforcedAsAgentOverRealSocket() throws {
        // End-to-end: the envelope hint alone classifies the caller as an agent,
        // so a blocked secret is refused whether or not the daemon's kernel-side
        // tree walk detects anything for this test process.
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.add(name: "K", value: "v-secret", projectId: project.id)
        try vault.setAgentAccess(name: "K", projectId: project.id, policy: .blocked)
        let socketPath = try makeSocketPath()

        let server = VaultSocketServer(socketPath: socketPath, service: vault)
        try server.start()
        addTeardownBlock { server.stop() }

        let remote = RemoteVaultService(transport: VaultSocketClient(socketPath: socketPath, agentContext: "agent").send)
        XCTAssertThrowsError(try remote.get(name: "K", projectId: project.id, environmentName: nil)) { error in
            guard case RemoteVaultError.daemon(let message) = error else {
                return XCTFail("expected daemon error, got \(error)")
            }
            XCTAssertTrue(message.contains("off-limits"), "got: \(message)")
            XCTAssertFalse(message.contains("v-secret"))
        }
    }

    func testPeerPIDReadsTheConnectedProcess() throws {
        var fds: [Int32] = [0, 0]
        XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds), 0)
        defer { close(fds[0]); close(fds[1]) }
        // Both ends live in this process, so the peer PID is our own.
        XCTAssertEqual(SocketIO.peerPID(fd: fds[0]), getpid())
    }
}
