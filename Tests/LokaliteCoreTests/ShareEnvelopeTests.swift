import XCTest
@testable import LokaliteCore

final class ShareEnvelopeTests: XCTestCase {
    func testEncryptSecretsRoundTrips() throws {
        let vault = try makeVault()
        let pairs = ["OPENAI_API_KEY": "sk-abc123", "DB_URL": "postgres://localhost/db"]

        let envelope = try vault.encryptSecrets(pairs, passphrase: "correct horse")
        let opened = try vault.decryptExport(envelope, passphrase: "correct horse")

        XCTAssertEqual(opened, pairs)
    }

    func testWrongPassphraseFails() throws {
        let vault = try makeVault()
        let envelope = try vault.encryptSecrets(["A": "value123"], passphrase: "right")

        XCTAssertThrowsError(try vault.decryptExport(envelope, passphrase: "wrong")) { error in
            guard case VaultError.invalidExportPassphrase = error else {
                return XCTFail("expected invalidExportPassphrase, got \(error)")
            }
        }
    }

    private func makeVault() throws -> Vault {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try VaultStore(path: directory.appendingPathComponent("vault.db").path)
        return Vault(store: store, key: VaultCrypto.generateKey())
    }
}
