import XCTest
import CryptoKit
@testable import LokaliteCore

final class VaultCryptoTests: XCTestCase {
    func testEncryptDecryptRoundtrip() throws {
        let key = VaultCrypto.generateKey()
        let original = "sk-test-1234567890"
        let encrypted = try VaultCrypto.encrypt(original, using: key)
        let decrypted = try VaultCrypto.decrypt(encrypted, using: key)
        XCTAssertEqual(original, decrypted)
    }

    func testEncryptProducesUniqueNonces() throws {
        let key = VaultCrypto.generateKey()
        let value = "same-value"
        let a = try VaultCrypto.encrypt(value, using: key)
        let b = try VaultCrypto.encrypt(value, using: key)
        XCTAssertNotEqual(a, b, "Each encryption should use a unique nonce")
    }

    func testDecryptWithWrongKeyFails() throws {
        let key1 = VaultCrypto.generateKey()
        let key2 = VaultCrypto.generateKey()
        let encrypted = try VaultCrypto.encrypt("secret", using: key1)
        XCTAssertThrowsError(try VaultCrypto.decrypt(encrypted, using: key2))
    }

    func testKeyRoundtrip() {
        let key = VaultCrypto.generateKey()
        let data = VaultCrypto.keyToData(key)
        let restored = VaultCrypto.keyFromData(data)
        XCTAssertEqual(VaultCrypto.keyToData(restored), data)
    }

    func testExportKeyDerivationUsesArgon2idParameters() throws {
        let salt = Data((0..<32).map(UInt8.init))
        let params = ExportKDFParameters(iterations: 2, memoryKiB: 8 * 1024, parallelism: 1)

        let first = try VaultCrypto.deriveExportKey(from: "passphrase", salt: salt, parameters: params)
        let second = try VaultCrypto.deriveExportKey(from: "passphrase", salt: salt, parameters: params)

        XCTAssertEqual(VaultCrypto.keyToData(first), VaultCrypto.keyToData(second))
        XCTAssertEqual(VaultCrypto.keyToData(first).count, 32)
    }

    func testExportKeyDerivationChangesWithSalt() throws {
        let params = ExportKDFParameters(iterations: 2, memoryKiB: 8 * 1024, parallelism: 1)
        let saltA = Data(repeating: 0xA, count: 32)
        let saltB = Data(repeating: 0xB, count: 32)

        let first = try VaultCrypto.deriveExportKey(from: "passphrase", salt: saltA, parameters: params)
        let second = try VaultCrypto.deriveExportKey(from: "passphrase", salt: saltB, parameters: params)

        XCTAssertNotEqual(VaultCrypto.keyToData(first), VaultCrypto.keyToData(second))
    }
}

final class SecretCategoryTests: XCTestCase {
    func testInfersApiKeyFromName() {
        XCTAssertEqual(
            SecretCategory.infer(name: "OPENAI_API_KEY", value: "sk-proj-123"),
            .apiKey
        )
    }

    func testInfersTokenFromKnownValuePrefix() {
        XCTAssertEqual(
            SecretCategory.infer(name: "GITHUB_AUTH", value: "ghp_1234567890"),
            .token
        )
    }

    func testInfersDatabaseFromUrlValue() {
        XCTAssertEqual(
            SecretCategory.infer(name: "PRIMARY_URL", value: "postgres://user:pass@localhost/app"),
            .database
        )
    }

    func testInfersCertificateFromPemValue() {
        XCTAssertEqual(
            SecretCategory.infer(name: "TLS_CHAIN", value: "-----BEGIN CERTIFICATE-----\nabc"),
            .certificate
        )
    }

    func testInfersPasswordBeforeGenericSecret() {
        XCTAssertEqual(
            SecretCategory.infer(name: "DATABASE_PASSWORD", value: "secret-value"),
            .password
        )
    }

    func testFallsBackToOtherForUnknownSecrets() {
        XCTAssertEqual(
            SecretCategory.infer(name: "MISC_VALUE", value: "plain text"),
            .other
        )
    }
}

final class ProjectModelTests: XCTestCase {
    func testProjectEqualityIncludesVisibleProperties() {
        let base = Project(id: "project-id", name: "App", icon: "folder")
        let changedIcon = Project(id: "project-id", name: "App", icon: "shippingbox")
        let changedName = Project(id: "project-id", name: "Renamed", icon: "folder")

        XCTAssertNotEqual(base, changedIcon)
        XCTAssertNotEqual(base, changedName)
    }
}

final class VaultConfigurationTests: XCTestCase {
    func testDebugBuildUsesDevelopmentStorage() {
        #if DEBUG
        XCTAssertTrue(VaultConfiguration.isDevelopmentBuild)
        XCTAssertEqual(VaultConfiguration.keychainService, "com.lokalite.vault.dev")
        XCTAssertTrue(VaultConfiguration.vaultFileURL.path.hasSuffix("/Lokalite/dev/vault.db"))
        #else
        XCTAssertFalse(VaultConfiguration.isDevelopmentBuild)
        XCTAssertEqual(VaultConfiguration.keychainService, "com.lokalite.vault")
        XCTAssertTrue(VaultConfiguration.vaultFileURL.path.hasSuffix("/Lokalite/vault.db"))
        #endif
    }
}

final class VaultStoreDeletionTests: XCTestCase {
    func testDeletingProjectWithSecretsFails() throws {
        let store = try makeStore()
        let project = try XCTUnwrap(store.fetchProject(name: "Default"))
        try store.insertSecret(secretRecord(projectId: project.id, name: "API_KEY"))

        XCTAssertThrowsError(try store.deleteProject(id: project.id)) { error in
            guard case VaultError.projectContainsSecrets("Default") = error else {
                return XCTFail("Expected projectContainsSecrets, got \(error)")
            }
        }
    }

    func testDeletingEmptyProjectSucceeds() throws {
        let store = try makeStore()
        let project = ProjectRecord(
            id: UUID().uuidString,
            name: "Empty",
            path: nil,
            activeEnvironment: nil,
            icon: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try store.insertProject(project)

        try store.deleteProject(id: project.id)

        XCTAssertNil(try store.fetchProject(id: project.id))
    }

    func testDeletingEnvironmentWithSecretValuesFails() throws {
        let store = try makeStore()
        let project = try XCTUnwrap(store.fetchProject(name: "Default"))
        let environment = EnvironmentRecord(
            id: UUID().uuidString,
            projectId: project.id,
            name: "Production",
            color: nil,
            createdAt: timestamp
        )
        let secret = secretRecord(projectId: project.id, name: "DATABASE_URL")
        try store.insertEnvironment(environment)
        try store.insertSecret(secret)
        try store.upsertSecretValue(SecretValueRecord(
            id: UUID().uuidString,
            secretId: secret.id,
            environmentId: environment.id,
            encryptedValue: Data([0x01, 0x02, 0x03]),
            updatedAt: timestamp
        ))

        XCTAssertThrowsError(try store.deleteEnvironment(name: environment.name, projectId: project.id)) { error in
            guard case VaultError.environmentContainsSecrets("Production") = error else {
                return XCTFail("Expected environmentContainsSecrets, got \(error)")
            }
        }
    }

    func testDeletingEmptyEnvironmentSucceeds() throws {
        let store = try makeStore()
        let project = try XCTUnwrap(store.fetchProject(name: "Default"))
        let environment = EnvironmentRecord(
            id: UUID().uuidString,
            projectId: project.id,
            name: "Staging",
            color: nil,
            createdAt: timestamp
        )
        try store.insertEnvironment(environment)

        try store.deleteEnvironment(name: environment.name, projectId: project.id)

        XCTAssertNil(try store.fetchEnvironment(name: environment.name, projectId: project.id))
    }

    func testUpsertingDefaultSecretValueReplacesExistingValue() throws {
        let store = try makeStore()
        let project = try XCTUnwrap(store.fetchProject(name: "Default"))
        let secret = secretRecord(projectId: project.id, name: "OPENAI_API_KEY")
        try store.insertSecret(secret)

        try store.upsertSecretValue(SecretValueRecord(
            id: UUID().uuidString,
            secretId: secret.id,
            environmentId: nil,
            encryptedValue: Data([0x01]),
            updatedAt: timestamp
        ))
        try store.upsertSecretValue(SecretValueRecord(
            id: UUID().uuidString,
            secretId: secret.id,
            environmentId: nil,
            encryptedValue: Data([0x02]),
            updatedAt: timestamp
        ))

        let values = try store.fetchAllSecretValues(secretId: secret.id)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.encryptedValue, Data([0x02]))
    }

    func testDefaultSecretValueUniqueIndexRejectsDuplicates() throws {
        let store = try makeStore()
        let project = try XCTUnwrap(store.fetchProject(name: "Default"))
        let secret = secretRecord(projectId: project.id, name: "OPENAI_API_KEY")
        try store.insertSecret(secret)
        try store.upsertSecretValue(SecretValueRecord(
            id: UUID().uuidString,
            secretId: secret.id,
            environmentId: nil,
            encryptedValue: Data([0x01]),
            updatedAt: timestamp
        ))

        XCTAssertThrowsError(try store.insertSecretValueForTesting(SecretValueRecord(
            id: UUID().uuidString,
            secretId: secret.id,
            environmentId: nil,
            encryptedValue: Data([0x02]),
            updatedAt: timestamp
        )))
    }

    private func makeStore() throws -> VaultStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return try VaultStore(path: directory.appendingPathComponent("vault.db").path)
    }

    private func secretRecord(projectId: String, name: String) -> SecretRecord {
        SecretRecord(
            id: UUID().uuidString,
            projectId: projectId,
            name: name,
            description: nil,
            icon: nil,
            category: SecretCategory.secret.rawValue,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private var timestamp: String {
        "2026-05-25T00:00:00Z"
    }
}
