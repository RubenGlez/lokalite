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

final class EnvFileFormatTests: XCTestCase {
    func testFormatsPlainValue() {
        XCTAssertEqual(EnvFileFormat.line(name: "API_KEY", value: "abc123"), "API_KEY=\"abc123\"")
    }

    func testEscapesBackslashesAndQuotes() {
        XCTAssertEqual(
            EnvFileFormat.line(name: "TRICKY", value: #"a\b"c"#),
            #"TRICKY="a\\b\"c""#
        )
    }

    func testParsesBareAndQuotedAndExportLines() {
        let content = """
        # comment
        FOO=bar
        export TOKEN="sk-123"
        QUOTED='single'

        WITH_COMMENT=value # trailing
        """
        let pairs = EnvFileFormat.parse(content)
        XCTAssertEqual(pairs.map(\.name), ["FOO", "TOKEN", "QUOTED", "WITH_COMMENT"])
        XCTAssertEqual(pairs.map(\.value), ["bar", "sk-123", "single", "value"])
    }

    func testSkipsBlankAndCommentAndKeylessLines() {
        let pairs = EnvFileFormat.parse("\n#only a comment\n=novalue\nKEY=ok\n")
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.name, "KEY")
        XCTAssertEqual(pairs.first?.value, "ok")
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

    func testDeletingProjectWithEnvironmentFails() throws {
        let store = try makeStore()
        let project = try XCTUnwrap(store.fetchProject(name: "Default"))

        XCTAssertThrowsError(try store.deleteProject(id: project.id)) { error in
            guard case VaultError.projectContainsSecrets("Default") = error else {
                return XCTFail("Expected projectContainsSecrets, got \(error)")
            }
        }
    }

    func testForceDeletingProjectRemovesEnvironmentsAndSecrets() throws {
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
            encryptedValue: Data([0x01]),
            updatedAt: timestamp
        ))

        try store.deleteProjectIncludingContents(id: project.id)

        XCTAssertNil(try store.fetchProject(id: project.id))
        XCTAssertTrue(try store.fetchAllEnvironments(projectId: project.id).isEmpty)
        XCTAssertTrue(try store.fetchAllSecrets(projectId: project.id).isEmpty)
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

    func testForceDeletingEnvironmentRemovesValuesAndOrphanSecrets() throws {
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
            encryptedValue: Data([0x01]),
            updatedAt: timestamp
        ))

        try store.deleteEnvironmentIncludingContents(name: environment.name, projectId: project.id)

        XCTAssertNil(try store.fetchEnvironment(name: environment.name, projectId: project.id))
        XCTAssertNil(try store.fetchSecret(name: secret.name, projectId: project.id))
    }

    func testFetchingProjectByPathPrefersMostSpecificMatch() throws {
        let store = try makeStore()
        let broadProject = ProjectRecord(
            id: UUID().uuidString,
            name: "Broad",
            path: "/Users/ruben/workspace",
            activeEnvironment: nil,
            icon: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let specificProject = ProjectRecord(
            id: UUID().uuidString,
            name: "Specific",
            path: "/Users/ruben/workspace/lokalite",
            activeEnvironment: nil,
            icon: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try store.insertProject(broadProject)
        try store.insertProject(specificProject)

        let matched = try XCTUnwrap(try store.fetchProject(matchingPath: "/Users/ruben/workspace/lokalite/Sources"))
        XCTAssertEqual(matched.id, specificProject.id)
    }

    func testMovingSecretToSameEnvironmentIsNoOp() throws {
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
        let value = SecretValueRecord(
            id: UUID().uuidString,
            secretId: secret.id,
            environmentId: environment.id,
            encryptedValue: Data([0x01, 0x02, 0x03]),
            updatedAt: timestamp
        )
        try store.insertEnvironment(environment)
        try store.insertSecret(secret)
        try store.upsertSecretValue(value)

        try store.moveSecretValue(
            secretId: secret.id,
            fromEnvironmentId: environment.id,
            toEnvironmentId: environment.id
        )

        let values = try store.fetchAllSecretValues(secretId: secret.id)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.id, value.id)
        XCTAssertEqual(values.first?.environmentId, environment.id)
        XCTAssertEqual(values.first?.encryptedValue, value.encryptedValue)
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

final class VaultResolutionTests: XCTestCase {
    func testResolvesByExplicitName() throws {
        let vault = try makeVault()
        let a = try vault.addProject(name: "alpha")
        _ = try vault.addProject(name: "beta")

        let resolved = try vault.resolveProject(name: "alpha")
        XCTAssertEqual(resolved.id, a.id)
    }

    func testUnknownNameThrowsProjectNotFound() throws {
        let vault = try makeVault()
        _ = try vault.addProject(name: "alpha")

        XCTAssertThrowsError(try vault.resolveProject(name: "ghost")) { error in
            guard case VaultError.projectNotFound = error else {
                return XCTFail("expected projectNotFound, got \(error)")
            }
        }
    }

    func testResolvesByLinkedWorkingDirectory() throws {
        let vault = try makeVault()
        _ = try vault.addProject(name: "alpha")
        let linked = try vault.addProject(name: "beta", path: "/tmp/lokalite-beta")

        let resolved = try vault.resolveProject(workingDirectory: "/tmp/lokalite-beta/sub/dir")
        XCTAssertEqual(resolved.id, linked.id)
    }

    func testFallsBackToStoredActiveProject() throws {
        let vault = try makeVault()
        _ = try vault.addProject(name: "alpha")
        let beta = try vault.addProject(name: "beta")
        try vault.setActiveProject(id: beta.id)

        let resolved = try vault.resolveProject()
        XCTAssertEqual(resolved.id, beta.id)
    }

    func testFallsBackToSingleProjectWhenNoActiveSet() throws {
        // A fresh vault is seeded with a single Default project and an active
        // pointer to it. Clear the active pointer to exercise the single-project
        // fallback branch.
        let vault = try makeVault()
        try vault.setActiveProject(id: nil)
        let projects = try vault.listProjects()
        XCTAssertEqual(projects.count, 1)

        let resolved = try vault.resolveProject()
        XCTAssertEqual(resolved.id, projects[0].id)
    }

    func testThrowsNoActiveProjectWhenAmbiguous() throws {
        let vault = try makeVault()
        try vault.setActiveProject(id: nil)
        _ = try vault.addProject(name: "alpha")

        XCTAssertThrowsError(try vault.resolveProject()) { error in
            guard case VaultError.noActiveProject = error else {
                return XCTFail("expected noActiveProject, got \(error)")
            }
        }
    }

    func testExplicitNameBeatsLinkedDirectoryAndActive() throws {
        let vault = try makeVault()
        let alpha = try vault.addProject(name: "alpha")
        let beta = try vault.addProject(name: "beta", path: "/tmp/lokalite-beta")
        try vault.setActiveProject(id: beta.id)

        let resolved = try vault.resolveProject(name: "alpha", workingDirectory: "/tmp/lokalite-beta")
        XCTAssertEqual(resolved.id, alpha.id)
    }

    func testLinkedDirectoryBeatsActiveProject() throws {
        let vault = try makeVault()
        let alpha = try vault.addProject(name: "alpha")
        let beta = try vault.addProject(name: "beta", path: "/tmp/lokalite-beta")
        try vault.setActiveProject(id: alpha.id)

        let resolved = try vault.resolveProject(workingDirectory: "/tmp/lokalite-beta")
        XCTAssertEqual(resolved.id, beta.id)
    }

    func testContextUsesExplicitEnvironmentName() throws {
        let vault = try makeVault()
        _ = try vault.addProject(name: "alpha")
        let workspace = SecretWorkspace(vault: vault)

        let ctx = try workspace.resolveContext(projectName: "alpha", environmentName: "staging")
        XCTAssertEqual(ctx.environmentName, "staging")
    }

    func testContextFallsBackToActiveEnvironment() throws {
        let vault = try makeVault()
        _ = try vault.addProject(name: "alpha")
        let workspace = SecretWorkspace(vault: vault)

        let ctx = try workspace.resolveContext(projectName: "alpha")
        XCTAssertEqual(ctx.environmentName, "Default")
    }

    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store)
    }
}
