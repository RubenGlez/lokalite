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
