import CryptoKit
import Foundation

public final class Vault {
    public static let shared = Vault()

    private var key: SymmetricKey?
    private lazy var store: VaultStore = {
        let url = vaultFileURL()
        return try! openStore(at: url)
    }()

    private init() {}

    // MARK: - Setup

    public func unlock() throws {
        if KeychainStore.exists() {
            let keyData = try KeychainStore.load()
            key = VaultCrypto.keyFromData(keyData)
        } else {
            let newKey = VaultCrypto.generateKey()
            try KeychainStore.save(VaultCrypto.keyToData(newKey))
            key = newKey
        }
        _ = store  // force lazy init so DB errors surface here
    }

    public func lock() {
        key = nil
    }

    // MARK: - CRUD

    public func add(name: String, value: String, description: String? = nil, tags: [String] = []) throws -> Secret {
        let key = try requireKey()
        let encrypted = try VaultCrypto.encrypt(value, using: key)
        let now = iso8601()
        let record = SecretRecord(
            id: UUID().uuidString,
            name: name,
            description: description,
            tags: encodeTags(tags),
            encryptedValue: encrypted,
            createdAt: now,
            updatedAt: now
        )
        try store.insert(record)
        return Secret(name: name, value: value, description: description, tags: tags)
    }

    public func set(name: String, value: String) throws -> Secret {
        let key = try requireKey()
        guard var record = try store.fetch(name: name) else {
            throw VaultError.secretNotFound(name)
        }
        let encrypted = try VaultCrypto.encrypt(value, using: key)
        record.encryptedValue = encrypted
        record.updatedAt = iso8601()
        try store.update(record)
        return Secret(name: name, value: value, description: record.description, tags: decodeTags(record.tags))
    }

    public func delete(name: String) throws {
        try store.delete(name: name)
    }

    public func get(name: String) throws -> Secret {
        let key = try requireKey()
        guard let record = try store.fetch(name: name) else {
            throw VaultError.secretNotFound(name)
        }
        let value = try VaultCrypto.decrypt(record.encryptedValue, using: key)
        return Secret(name: name, value: value, description: record.description, tags: decodeTags(record.tags))
    }

    public func list(tag: String? = nil) throws -> [Secret] {
        let key = try requireKey()
        let records = try store.fetchAll(tag: tag)
        return try records.map { record in
            let value = try VaultCrypto.decrypt(record.encryptedValue, using: key)
            return Secret(name: record.name, value: value, description: record.description, tags: decodeTags(record.tags))
        }
    }

    // MARK: - Export

    public func export(passphrase: String?) throws -> Data {
        let secrets = try list()
        let dict = Dictionary(uniqueKeysWithValues: secrets.map { ($0.name, $0.value) })
        let json = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)

        if let passphrase {
            return try encryptExport(json, passphrase: passphrase)
        }
        return json
    }

    private func encryptExport(_ data: Data, passphrase: String) throws -> Data {
        let salt = VaultCrypto.generateSalt()
        let derivedKey = VaultCrypto.deriveKey(from: passphrase, salt: salt)
        guard let combined = try AES.GCM.seal(data, using: derivedKey).combined else {
            throw VaultError.encryptionFailed
        }
        var envelope = Data()
        // Format: [1 byte version][32 bytes salt][remaining: sealed box]
        envelope.append(0x01)
        envelope.append(salt)
        envelope.append(combined)
        return envelope
    }

    // MARK: - Helpers

    private func requireKey() throws -> SymmetricKey {
        guard let key else {
            throw VaultError.keychainReadFailed(errSecAuthFailed)
        }
        return key
    }

    private func vaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Lokalite")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vault.db")
    }

    private func openStore(at url: URL) throws -> VaultStore {
        do {
            return try VaultStore(path: url.path)
        } catch {
            throw VaultError.databaseError(error.localizedDescription)
        }
    }

    private func iso8601() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func encodeTags(_ tags: [String]) -> String {
        (try? String(data: JSONEncoder().encode(tags), encoding: .utf8)) ?? "[]"
    }

    private func decodeTags(_ string: String) -> [String] {
        guard let data = string.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return tags
    }
}
