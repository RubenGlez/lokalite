import XCTest
@testable import LokaliteCore

/// Covers the write-path correctness fixes from the 2026-07-03 adversarial audit:
/// secret-name validation (M5) and the add-in-new-environment category (L2).
final class VaultWriteValidationTests: XCTestCase {
    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }

    // MARK: - M5

    func testAddRejectsShellUnsafeSecretNames() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        for bad in ["X'; rm -rf ~ #", "FOO BAR", "1FOO", "FOO-BAR", "FOO\nBAR", "", "a.b"] {
            XCTAssertThrowsError(try vault.add(name: bad, value: "v", projectId: project.id), "name '\(bad)' should be rejected") { error in
                guard case VaultError.invalidSecretName = error else {
                    return XCTFail("expected invalidSecretName for '\(bad)', got \(error)")
                }
            }
        }
    }

    func testAddAcceptsValidIdentifierNames() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        for good in ["FOO", "_FOO", "OPENAI_API_KEY", "a1_b2", "_"] {
            XCTAssertNoThrow(try vault.add(name: good, value: "v", projectId: project.id), "name '\(good)' should be accepted")
        }
    }

    // MARK: - L2

    func testAddInNewEnvironmentReturnsPersistedCategoryNotAReInference() throws {
        let vault = try makeVault()
        let project = try vault.addProject(name: "App", path: nil)
        _ = try vault.addEnvironment(name: "prod", projectId: project.id, color: nil)

        let created = try vault.add(name: "API_TOKEN", value: "v", category: .apiKey,
                                    projectId: project.id, environmentName: "Default")
        // Re-adding the same secret in another environment reuses the existing
        // row; the metadata args are ignored, so the returned category must be the
        // persisted one, not the category passed on this call.
        let reused = try vault.add(name: "API_TOKEN", value: "v2", category: .password,
                                   projectId: project.id, environmentName: "prod")

        XCTAssertEqual(reused.category, .apiKey)
        XCTAssertEqual(reused.category, created.category)
        XCTAssertEqual(try vault.get(name: "API_TOKEN", projectId: project.id).category, .apiKey)
    }
}
