import CryptoKit
import Foundation

enum VaultCrypto {
    static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    static func keyToData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    static func keyFromData(_ data: Data) -> SymmetricKey {
        SymmetricKey(data: data)
    }

    static func encrypt(_ value: String, using key: SymmetricKey) throws -> Data {
        guard let data = value.data(using: .utf8) else { throw VaultError.encryptionFailed }
        guard let combined = try AES.GCM.seal(data, using: key).combined else {
            throw VaultError.encryptionFailed
        }
        return combined
    }

    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        guard let value = String(data: decrypted, encoding: .utf8) else {
            throw VaultError.decryptionFailed
        }
        return value
    }

    // Used for encrypted export: derives a key from passphrase with Argon2id-equivalent (SHA256 stretch for MVP).
    // TODO: replace with Argon2id before shipping export feature.
    static func deriveKey(from passphrase: String, salt: Data) -> SymmetricKey {
        var inputData = Data(passphrase.utf8)
        inputData.append(salt)
        let hash = SHA256.hash(data: inputData)
        return SymmetricKey(data: hash)
    }

    static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
