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
/// This case asserts what is stable without a checked-in fixture, and prints
/// every encoding so the exact bytes can be lifted from a CI run into
/// `Contracts/` and asserted verbatim from then on.
final class WireEncodingContractTests: XCTestCase {
    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Deterministic across runs and platforms: unsorted keys would make any
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

    func testEveryRequestCaseEncodesDeterministically() throws {
        let encoder = encoder()

        for (label, request) in requestCases {
            let first = try encoder.encode(request)
            let second = try encoder.encode(request)
            XCTAssertEqual(first, second, "\(label) does not encode deterministically")

            let json = try XCTUnwrap(String(data: first, encoding: .utf8))
            print("WIRE-CONTRACT request \(label) \(json)")

            let decoded = try JSONDecoder().decode(VaultRequest.self, from: first)
            XCTAssertEqual(decoded, request, "\(label) did not survive a round trip")
        }
    }

    /// The two responses that carry no domain model. They reveal the same
    /// enum-derivation shape every other case uses, without depending on model
    /// initializers that would couple this contract to unrelated churn.
    func testModelFreeResponsesEncodeDeterministically() throws {
        let encoder = encoder()
        let responses: [(String, VaultResponse)] = [
            ("ok", .ok),
            ("failure", .failure(message: "denied")),
        ]

        for (label, response) in responses {
            let data = try encoder.encode(response)
            let json = try XCTUnwrap(String(data: data, encoding: .utf8))
            print("WIRE-CONTRACT response \(label) \(json)")

            let decoded = try JSONDecoder().decode(VaultResponse.self, from: data)
            XCTAssertEqual(decoded, response, "\(label) did not survive a round trip")
        }
    }

    /// The envelope and its bare-frame fallback are the compatibility seam for
    /// clients that predate the agent hint, so both encodings are frozen.
    func testEnvelopeEncodesWithAndWithoutAnAgentHint() throws {
        let encoder = encoder()
        let envelopes: [(String, VaultEnvelope)] = [
            ("withHint", VaultEnvelope(agentContext: "claude", request: .listProjects)),
            ("withoutHint", VaultEnvelope(agentContext: nil, request: .listProjects)),
        ]

        for (label, envelope) in envelopes {
            let data = try encoder.encode(envelope)
            let json = try XCTUnwrap(String(data: data, encoding: .utf8))
            print("WIRE-CONTRACT envelope \(label) \(json)")

            let decoded = try JSONDecoder().decode(VaultEnvelope.self, from: data)
            XCTAssertEqual(decoded, envelope, "\(label) did not survive a round trip")
        }

        // A bare request frame must not decode as an envelope; the daemon relies
        // on that failure to fall back for legacy clients.
        let bare = try encoder.encode(VaultRequest.listProjects)
        XCTAssertThrowsError(try JSONDecoder().decode(VaultEnvelope.self, from: bare))
    }
}
