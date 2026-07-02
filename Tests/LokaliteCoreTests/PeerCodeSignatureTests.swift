import XCTest
@testable import LokaliteCore

final class PeerCodeSignatureTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    // MARK: - Model

    func testCodableRoundTrip() throws {
        let sig = PeerCodeSignature(status: .verified, teamID: "67S22M7P3P", identifier: "lokalite")
        let decoded = try JSONDecoder().decode(PeerCodeSignature.self, from: JSONEncoder().encode(sig))
        XCTAssertEqual(sig, decoded)
    }

    func testVerifiedTeamIDOnlyWhenVerified() {
        XCTAssertEqual(PeerCodeSignature(status: .verified, teamID: "T").verifiedTeamID, "T")
        XCTAssertNil(PeerCodeSignature(status: .mismatch, teamID: "T").verifiedTeamID)
        XCTAssertNil(PeerCodeSignature(status: .unsigned).verifiedTeamID)
        XCTAssertNil(PeerCodeSignature(status: .unavailable).verifiedTeamID)
    }

    // MARK: - CallerContext plumbing

    func testCallerContextPreservesPeerSignatureAcrossMerge() {
        let sig = PeerCodeSignature(status: .verified, teamID: "T", identifier: "lokalite")
        let caller = CallerContext(pid: 1, agent: nil, peerSignature: sig)
        let merged = caller.merging(clientAgentHint: "claude")
        XCTAssertEqual(merged.peerSignature, sig)
        XCTAssertEqual(merged.clientAgentHint, "claude")
    }

    // MARK: - Daemon attribution (ADR 0019)

    func testDaemonStampsVerifiedPeerTeamOnLogAccess() throws {
        let vault = try makeVault()
        let verified = PeerCodeSignature(status: .verified, teamID: "67S22M7P3P", identifier: "lokalite")
        let request = VaultRequest.logAccess(secretName: "K", projectName: "App", environmentName: "prod", source: .mcp, action: .read)
        _ = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 42, agent: "claude", peerSignature: verified))

        let entry = try XCTUnwrap(try vault.listActivity().first)
        XCTAssertEqual(entry.peerTeamID, "67S22M7P3P")
    }

    func testDaemonDoesNotStampUnverifiedPeerTeam() throws {
        let vault = try makeVault()
        // A validly-signed-but-wrong-team peer must not leave a trusted-looking stamp.
        let mismatch = PeerCodeSignature(status: .mismatch, teamID: "OTHERTEAM", identifier: "x")
        let request = VaultRequest.logAccess(secretName: "K", projectName: "App", environmentName: "prod", source: .mcp, action: .read)
        _ = VaultRequestDispatcher.handle(request, using: vault, caller: CallerContext(pid: 42, agent: nil, peerSignature: mismatch))

        let entry = try XCTUnwrap(try vault.listActivity().first)
        XCTAssertNil(entry.peerTeamID)
    }

    func testLogAccessRoundTripsPeerTeam() throws {
        let vault = try makeVault()
        vault.logAccess(secretName: "K", projectName: "App", environmentName: "prod", source: .mcp, agent: "claude", peerTeamID: "67S22M7P3P", action: .read)
        vault.logAccess(secretName: "K", projectName: "App", environmentName: "prod", source: .app)

        let entries = try vault.listActivity()
        XCTAssertEqual(entries.first { $0.source == .mcp }?.peerTeamID, "67S22M7P3P")
        // App-local reads carry no peer signature.
        XCTAssertNil(entries.first { $0.source == .app }?.peerTeamID)
    }

    // MARK: - Verification (macOS Security framework)

    #if canImport(Security)
    func testDeveloperIDRequirementBuilds() {
        XCTAssertNotNil(PeerCodeVerifier.developerIDRequirement(teamID: PeerCodeVerifier.lokaliteTeamID))
    }

    func testVerifyBogusPidIsUnavailable() {
        // A pid that cannot correspond to a live process → no SecCode.
        let sig = PeerCodeVerifier.verify(pid: pid_t(Int32.max))
        XCTAssertEqual(sig.status, .unavailable)
    }

    func testVerifyCurrentProcessIsNotVerified() {
        // The unsigned/ad-hoc test binary is never signed by Lokalite's team.
        let sig = PeerCodeVerifier.verify(pid: getpid())
        XCTAssertNotEqual(sig.status, .verified)
        XCTAssertNil(sig.verifiedTeamID)
    }
    #endif
}
