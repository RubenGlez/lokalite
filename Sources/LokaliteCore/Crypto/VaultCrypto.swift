import CryptoKit
import Foundation
import argon2

struct ExportKDFParameters {
    static let current = ExportKDFParameters(iterations: 3, memoryKiB: 64 * 1024, parallelism: 1)

    let iterations: UInt32
    let memoryKiB: UInt32
    let parallelism: UInt32
}

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

    static func deriveExportKey(
        from passphrase: String,
        salt: Data,
        parameters: ExportKDFParameters = .current
    ) throws -> SymmetricKey {
        var passphraseBytes = Array(passphrase.utf8)
        let saltBytes = Array(salt)
        var keyBytes = [UInt8](repeating: 0, count: 32)
        let keyLength = keyBytes.count

        let result = keyBytes.withUnsafeMutableBytes { keyBuffer in
            passphraseBytes.withUnsafeBytes { passphraseBuffer in
                saltBytes.withUnsafeBytes { saltBuffer in
                    argon2id_hash_raw(
                        parameters.iterations,
                        parameters.memoryKiB,
                        parameters.parallelism,
                        passphraseBuffer.baseAddress,
                        passphraseBytes.count,
                        saltBuffer.baseAddress,
                        saltBytes.count,
                        keyBuffer.baseAddress,
                        keyLength
                    )
                }
            }
        }

        passphraseBytes.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            memset_s(baseAddress, buffer.count, 0, buffer.count)
        }

        guard result == 0 else {
            let message = argon2_error_message(result).map(String.init(cString:)) ?? "Argon2id error \(result)"
            throw VaultError.keyDerivationFailed(message)
        }

        return SymmetricKey(data: keyBytes)
    }

    static func generateSalt() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw VaultError.keyDerivationFailed("Failed to generate random salt (status \(status)).")
        }
        return Data(bytes)
    }
}
