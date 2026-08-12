import Foundation
import XCTest

@testable import LokaliteCore

/// Freezes the daemon protocol's *encoding*, not its behavior (Task 1.2).
///
/// `VaultRequest`, `VaultResponse`, and `VaultEnvelope` get their `Codable`
/// conformance synthesized, so the bytes on the wire are an emergent property of
/// Swift's derivation rules. `VaultWireTests` round-trips through Swift's own
/// coder, which cannot catch a shape a second implementation would render
/// differently — it would encode and decode its own mistake consistently.
///
/// The expected bytes live in `Contracts/wire-protocol-v1.json` and were
/// captured from the shipped baseline. A failure here means either the wire
/// format changed — which breaks every installed CLI and MCP client — or a case
/// was added without being frozen. Neither is fixed by editing the fixture.
final class WireEncodingContractTests: XCTestCase {
    private struct Fixture: Decodable {
        let requests: [String: String]
        let responses: [String: String]
        let envelopes: [String: String]
    }

    private func loadFixture() throws -> Fixture {
        // Resolved from this file rather than a bundle: the fixture is shared
        // with the Rust implementation and belongs beside the contract
        // documentation, not inside a test target's resources.
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("Contracts")
            .appendingPathComponent("wire-protocol-v1.json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Deterministic across runs and platforms: unsorted keys would make the
        // frozen fixture a coin toss.
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    /// Every request case, with values chosen so optional-vs-present and the
    /// nested `SecretCategory` and activity enums are all visible in the output.
    private var requestCases: [(label: String, request: VaultRequest)] {
        [
            ("unlock", .unlock),
            ("resolveProject.named", .resolveProject(name: "demo", workingDirectory: nil)),
            ("resolveProject.byDirectory", .resolveProject(name: nil, workingDirectory: "/tmp/demo")),
            ("listProjects", .listProjects),
            (
                "add.full",
                .add(
                    name: "API_KEY", value: "v", description: "d", icon: "key",
                    category: .secret, projectId: "p1", environmentName: "staging"
                )
            ),
            (
                "add.minimal",
                .add(
                    name: "API_KEY", value: "v", description: nil, icon: nil,
                    category: nil, projectId: "p1", environmentName: nil
                )
            ),
            ("get", .get(name: "API_KEY", projectId: "p1", environmentName: "staging")),
            ("get.noEnvironment", .get(name: "API_KEY", projectId: "p1", environmentName: nil)),
            ("set", .set(name: "API_KEY", value: "v", projectId: "p1", environmentName: nil)),
            ("delete", .delete(name: "API_KEY", projectId: "p1")),
            ("list", .list(projectId: "p1", environmentName: "staging")),
            ("listInfo", .listInfo(projectId: "p1")),
            ("listEnvironments", .listEnvironments(projectId: "p1")),
            ("setActiveEnvironment", .setActiveEnvironment(name: "staging", projectId: "p1")),
            ("setActiveEnvironment.clear", .setActiveEnvironment(name: nil, projectId: "p1")),
            (
                "importEnv",
                .importEnv(
                    pairs: [EnvPair(name: "A", value: "1")], projectId: "p1",
                    environmentName: nil, overwrite: true
                )
            ),
            (
                "logAccess",
                .logAccess(
                    secretName: "API_KEY", projectName: "demo", environmentName: "Default",
                    source: .cli, action: .read
                )
            ),
        ]
    }

    /// The two responses that carry no domain model. They reveal the same
    /// enum-derivation shape every other case uses, without coupling this
    /// contract to model initializers that churn for unrelated reasons.
    private var responseCases: [(label: String, response: VaultResponse)] {
        [
            ("ok", .ok),
            ("failure", .failure(message: "denied")),
        ]
    }

    /// The envelope and its bare-frame fallback are the compatibility seam for
    /// clients that predate the agent hint, so both shapes are frozen.
    private var envelopeCases: [(label: String, envelope: VaultEnvelope)] {
        [
            ("withHint", VaultEnvelope(agentContext: "claude", request: .listProjects)),
            ("withoutHint", VaultEnvelope(agentContext: nil, request: .listProjects)),
        ]
    }

    func testRequestEncodingsMatchTheFrozenBytes() throws {
        let fixture = try loadFixture()
        let encoder = encoder()

        for (label, request) in requestCases {
            let expected = try XCTUnwrap(fixture.requests[label], "\(label) is not frozen")
            let actual = try XCTUnwrap(String(data: encoder.encode(request), encoding: .utf8))
            XCTAssertEqual(actual, expected, "wire encoding changed for request \(label)")
        }
    }

    func testResponseEncodingsMatchTheFrozenBytes() throws {
        let fixture = try loadFixture()
        let encoder = encoder()

        for (label, response) in responseCases {
            let expected = try XCTUnwrap(fixture.responses[label], "\(label) is not frozen")
            let actual = try XCTUnwrap(String(data: encoder.encode(response), encoding: .utf8))
            XCTAssertEqual(actual, expected, "wire encoding changed for response \(label)")
        }
    }

    func testEnvelopeEncodingsMatchTheFrozenBytes() throws {
        let fixture = try loadFixture()
        let encoder = encoder()

        for (label, envelope) in envelopeCases {
            let expected = try XCTUnwrap(fixture.envelopes[label], "\(label) is not frozen")
            let actual = try XCTUnwrap(String(data: encoder.encode(envelope), encoding: .utf8))
            XCTAssertEqual(actual, expected, "wire encoding changed for envelope \(label)")
        }
    }

    /// Drift in the other direction: a case dropped from the suite would leave
    /// its frozen bytes unasserted, and the contract would quietly shrink.
    func testTheFixtureFreezesExactlyTheCasesUnderTest() throws {
        let fixture = try loadFixture()

        XCTAssertEqual(Set(fixture.requests.keys), Set(requestCases.map(\.label)))
        XCTAssertEqual(Set(fixture.responses.keys), Set(responseCases.map(\.label)))
        XCTAssertEqual(Set(fixture.envelopes.keys), Set(envelopeCases.map(\.label)))
    }

    /// Every `VaultRequest` case must be frozen. The count is asserted directly
    /// because Swift cannot enumerate an enum with associated values, so a new
    /// case would otherwise ship unfrozen and silently diverge in the port.
    func testEveryRequestCaseIsFrozen() throws {
        let distinctCases = Set(requestCases.map { $0.label.split(separator: ".").first.map(String.init) ?? $0.label })
        XCTAssertEqual(
            distinctCases.count, 13,
            "VaultRequest gained or lost a case; freeze it in Contracts/wire-protocol-v1.json"
        )
    }

    func testFrozenBytesStillDecodeBackToTheirValues() throws {
        let fixture = try loadFixture()
        let decoder = JSONDecoder()

        for (label, request) in requestCases {
            let data = Data(try XCTUnwrap(fixture.requests[label]).utf8)
            XCTAssertEqual(try decoder.decode(VaultRequest.self, from: data), request, "\(label)")
        }
        for (label, response) in responseCases {
            let data = Data(try XCTUnwrap(fixture.responses[label]).utf8)
            XCTAssertEqual(try decoder.decode(VaultResponse.self, from: data), response, "\(label)")
        }
        for (label, envelope) in envelopeCases {
            let data = Data(try XCTUnwrap(fixture.envelopes[label]).utf8)
            XCTAssertEqual(try decoder.decode(VaultEnvelope.self, from: data), envelope, "\(label)")
        }
    }

    /// The daemon relies on a bare request frame failing to decode as an
    /// envelope; that failure is what makes the legacy-client fallback reachable.
    func testABareRequestFrameDoesNotDecodeAsAnEnvelope() throws {
        let fixture = try loadFixture()
        let bare = Data(try XCTUnwrap(fixture.requests["listProjects"]).utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(VaultEnvelope.self, from: bare))
    }
}
