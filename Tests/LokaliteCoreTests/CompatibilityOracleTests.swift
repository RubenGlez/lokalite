import CryptoKit
import Foundation
import GRDB
import XCTest
import argon2
@testable import LokaliteCore

final class CompatibilityOracleTests: XCTestCase {
    private let migrations = ["v1", "v3", "v4", "v5", "v6", "v7"]

    func testGenerateSwiftFixturesAndVerifyRustCrypto() throws {
        let root = try fixtureRoot()
        let swiftDirectory = root.appendingPathComponent("swift", isDirectory: true)
        try FileManager.default.createDirectory(at: swiftDirectory, withIntermediateDirectories: true)
        try generateCryptoFixtures(at: swiftDirectory)
        try generateSchemaFixtures(at: swiftDirectory)
        try verifyRustCrypto(at: root.appendingPathComponent("rust", isDirectory: true))
    }

    func testVerifyRustWrittenSchemaFixtures() throws {
        let root = try fixtureRoot()
        let directory = root.appendingPathComponent("rust-written", isDirectory: true)
        for (index, migration) in migrations.enumerated() {
            let path = directory.appendingPathComponent("schema-\(migration).db").path
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "Missing Rust-written \(migration) fixture")
            let db = try DatabaseQueue(path: path)
            try db.read { database in
                let identifiers = try String.fetchAll(
                    database,
                    sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
                )
                XCTAssertEqual(identifiers, Array(migrations[...index]))
                XCTAssertEqual(
                    try String.fetchOne(database, sql: "SELECT name FROM projects WHERE id='project-synthetic'"),
                    "Prøject 🚀"
                )
                XCTAssertEqual(
                    try Data.fetchOne(database, sql: "SELECT encrypted_value FROM secret_values WHERE id='value-synthetic'"),
                    Data([0, 255, 1, 2, 3, 254])
                )
                XCTAssertEqual(
                    try String.fetchOne(database, sql: "SELECT environment_id FROM secret_values WHERE id='value-synthetic'"),
                    index >= 2 ? "environment-default" : nil
                )
                if index >= 3 {
                    XCTAssertEqual(
                        try String.fetchOne(database, sql: "SELECT agent_access FROM secrets WHERE id='secret-synthetic'"),
                        "allowed"
                    )
                }
                if index >= 1 {
                    XCTAssertEqual(
                        try String.fetchOne(database, sql: "SELECT source FROM activity_log WHERE id='activity-synthetic'"),
                        "cli"
                    )
                }
                if index >= 4 {
                    XCTAssertEqual(
                        try String.fetchOne(database, sql: "SELECT agent FROM activity_log WHERE id='activity-synthetic'"),
                        "codex"
                    )
                    XCTAssertEqual(
                        try String.fetchOne(database, sql: "SELECT action FROM activity_log WHERE id='activity-synthetic'"),
                        "read"
                    )
                }
                if index >= 5 {
                    XCTAssertEqual(
                        try String.fetchOne(database, sql: "SELECT peer_team FROM activity_log WHERE id='activity-synthetic'"),
                        "67S22M7P3P"
                    )
                }
            }
        }
    }

    private func fixtureRoot() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["LOKALITE_COMPAT_DIR"], !path.isEmpty else {
            throw XCTSkip("Set LOKALITE_COMPAT_DIR to run the isolated compatibility oracle")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func generateCryptoFixtures(at directory: URL) throws {
        let keyData = Data((0..<32).map(UInt8.init))
        let nonceData = Data((0..<12).map(UInt8.init))
        let plaintext = Data("synthetic-lokalite-secret".utf8)
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(
            plaintext,
            using: key,
            nonce: try AES.GCM.Nonce(data: nonceData)
        )
        guard let combined = sealed.combined else { throw OracleError.missingCombined }
        try writeJSON(
            [
                "producer": "swift-cryptokit",
                "key_hex": keyData.hex,
                "nonce_hex": nonceData.hex,
                "plaintext_hex": plaintext.hex,
                "combined_hex": combined.hex,
            ],
            to: directory.appendingPathComponent("aes-value.json")
        )

        let salt = Data((0..<32).map(UInt8.init))
        let exportNonce = Data((32..<44).map(UInt8.init))
        let payload = Data(#"{"API_KEY":"synthetic-value","UNICODE":"caf\u00e9"}"#.utf8)
        let passphrase = "synthetic passphrase"
        let exportKey = try deriveExportKey(passphrase: passphrase, salt: salt)
        let exportBox = try AES.GCM.seal(
            payload,
            using: exportKey,
            nonce: try AES.GCM.Nonce(data: exportNonce)
        )
        guard let exportCombined = exportBox.combined else { throw OracleError.missingCombined }
        var envelope = Data([0x02])
        envelope.append(bigEndian: 3)
        envelope.append(bigEndian: 65_536)
        envelope.append(bigEndian: 1)
        envelope.append(salt)
        envelope.append(exportCombined)
        try writeJSON(
            [
                "producer": "swift-cryptokit+argon2id",
                "version": 2,
                "iterations": 3,
                "memory_kib": 65_536,
                "parallelism": 1,
                "passphrase": passphrase,
                "salt_hex": salt.hex,
                "nonce_hex": exportNonce.hex,
                "payload_hex": payload.hex,
                "envelope_hex": envelope.hex,
            ],
            to: directory.appendingPathComponent("encrypted-export-v2.json")
        )
    }

    private func verifyRustCrypto(at directory: URL) throws {
        let aes = try readJSON(directory.appendingPathComponent("aes-value.json"))
        let key = SymmetricKey(data: try Data(hex: try string(aes, "key_hex")))
        let combined = try Data(hex: try string(aes, "combined_hex"))
        let plaintext = try AES.GCM.open(try AES.GCM.SealedBox(combined: combined), using: key)
        XCTAssertEqual(plaintext, try Data(hex: try string(aes, "plaintext_hex")))
        for offset in [0, 12, combined.count - 1] {
            var damaged = combined
            damaged[offset] ^= 1
            XCTAssertThrowsError(try AES.GCM.open(try AES.GCM.SealedBox(combined: damaged), using: key))
        }

        let export = try readJSON(directory.appendingPathComponent("encrypted-export-v2.json"))
        let envelope = try Data(hex: try string(export, "envelope_hex"))
        XCTAssertEqual(envelope.first, 0x02)
        XCTAssertEqual(envelope.subdata(in: 1..<5), Data([0, 0, 0, 3]))
        XCTAssertEqual(envelope.subdata(in: 5..<9), Data([0, 1, 0, 0]))
        XCTAssertEqual(envelope.subdata(in: 9..<13), Data([0, 0, 0, 1]))
        XCTAssertEqual(envelope.subdata(in: 13..<45), try Data(hex: try string(export, "salt_hex")))
        XCTAssertEqual(envelope.subdata(in: 45..<57), try Data(hex: try string(export, "nonce_hex")))
        let salt = envelope.subdata(in: 13..<45)
        let exportKey = try deriveExportKey(passphrase: try string(export, "passphrase"), salt: salt)
        let exportPayload = try AES.GCM.open(
            try AES.GCM.SealedBox(combined: envelope.subdata(in: 45..<envelope.count)),
            using: exportKey
        )
        XCTAssertEqual(exportPayload, try Data(hex: try string(export, "payload_hex")))
        let wrongKey = try deriveExportKey(passphrase: "wrong passphrase", salt: salt)
        XCTAssertThrowsError(
            try AES.GCM.open(
                try AES.GCM.SealedBox(combined: envelope.subdata(in: 45..<envelope.count)),
                using: wrongKey
            )
        )
        var damagedExport = envelope.subdata(in: 45..<envelope.count)
        damagedExport[damagedExport.count - 1] ^= 1
        XCTAssertThrowsError(
            try AES.GCM.open(try AES.GCM.SealedBox(combined: damagedExport), using: exportKey)
        )
    }

    private func generateSchemaFixtures(at directory: URL) throws {
        for (index, migration) in migrations.enumerated() {
            let path = directory.appendingPathComponent("schema-\(migration).db").path
            try? FileManager.default.removeItem(atPath: path)
            let store = try VaultStore(path: path, migrationTarget: migration)
            try store.db.write { db in
                try db.execute(sql: "DELETE FROM secret_values")
                try db.execute(sql: "DELETE FROM secrets")
                try db.execute(sql: "DELETE FROM environments")
                if index >= 1 { try db.execute(sql: "DELETE FROM activity_log") }
                try db.execute(sql: "DELETE FROM config")
                try db.execute(sql: "DELETE FROM projects")
                let timestamp = "2026-07-29T12:34:56.000Z"
                try db.execute(
                    sql: "INSERT INTO projects VALUES(?,?,?,?,?,?,?)",
                    arguments: ["project-synthetic", "Prøject 🚀", nil, index >= 2 ? "Default" : nil, nil, timestamp, timestamp]
                )
                try db.execute(sql: "INSERT INTO config VALUES('active_project_id','project-synthetic')")
                let environment: String? = index >= 2 ? "environment-default" : nil
                if let environment {
                    try db.execute(
                        sql: "INSERT INTO environments VALUES(?,?,?,?,?)",
                        arguments: [environment, "project-synthetic", "Default", nil, timestamp]
                    )
                }
                if index >= 3 {
                    try db.execute(
                        sql: "INSERT INTO secrets(id,project_id,name,description,icon,category,created_at,updated_at,agent_access) VALUES(?,?,?,?,?,?,?,?,?)",
                        arguments: ["secret-synthetic", "project-synthetic", "CAFÉ_TOKEN", nil, nil, "token", timestamp, timestamp, "allowed"]
                    )
                } else {
                    try db.execute(
                        sql: "INSERT INTO secrets(id,project_id,name,description,icon,category,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)",
                        arguments: ["secret-synthetic", "project-synthetic", "CAFÉ_TOKEN", nil, nil, "token", timestamp, timestamp]
                    )
                }
                try db.execute(
                    sql: "INSERT INTO secret_values VALUES(?,?,?,?,?)",
                    arguments: ["value-synthetic", "secret-synthetic", environment, Data([0, 255, 1, 2, 3, 254]), timestamp]
                )
                if index >= 1 {
                    if index <= 3 {
                        try db.execute(
                            sql: "INSERT INTO activity_log(id,secret_name,project_name,environment_name,source,accessed_at) VALUES(?,?,?,?,?,?)",
                            arguments: ["activity-synthetic", "CAFÉ_TOKEN", "Prøject 🚀", "Default", "cli", timestamp]
                        )
                    } else if index == 4 {
                        try db.execute(
                            sql: "INSERT INTO activity_log(id,secret_name,project_name,environment_name,source,accessed_at,agent,action) VALUES(?,?,?,?,?,?,?,?)",
                            arguments: ["activity-synthetic", "CAFÉ_TOKEN", "Prøject 🚀", "Default", "cli", timestamp, "codex", "read"]
                        )
                    } else {
                        try db.execute(
                            sql: "INSERT INTO activity_log(id,secret_name,project_name,environment_name,source,accessed_at,agent,action,peer_team) VALUES(?,?,?,?,?,?,?,?,?)",
                            arguments: ["activity-synthetic", "CAFÉ_TOKEN", "Prøject 🚀", "Default", "cli", timestamp, "codex", "read", "67S22M7P3P"]
                        )
                    }
                }
            }
        }
    }

    private func deriveExportKey(passphrase: String, salt: Data) throws -> SymmetricKey {
        var output = [UInt8](repeating: 0, count: 32)
        let outputCount = output.count
        let password = Array(passphrase.utf8)
        let saltBytes = Array(salt)
        let result = output.withUnsafeMutableBytes { outputBuffer in
            password.withUnsafeBytes { passwordBuffer in
                saltBytes.withUnsafeBytes { saltBuffer in
                    argon2id_hash_raw(
                        3, 65_536, 1,
                        passwordBuffer.baseAddress, password.count,
                        saltBuffer.baseAddress, saltBytes.count,
                        outputBuffer.baseAddress, outputCount
                    )
                }
            }
        }
        guard result == 0 else { throw OracleError.argon2(result) }
        return SymmetricKey(data: output)
    }

    private func writeJSON(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func readJSON(_ url: URL) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw OracleError.invalidJSON(url.path)
        }
        return object
    }

    private func string(_ object: [String: Any], _ key: String) throws -> String {
        guard let value = object[key] as? String else { throw OracleError.missingField(key) }
        return value
    }
}

private enum OracleError: Error {
    case argon2(Int32)
    case invalidHex
    case invalidJSON(String)
    case missingCombined
    case missingField(String)
}

private extension Data {
    init(hex: String) throws {
        guard hex.count.isMultiple(of: 2) else { throw OracleError.invalidHex }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { throw OracleError.invalidHex }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }

    var hex: String { map { String(format: "%02x", $0) }.joined() }

    mutating func append(bigEndian value: UInt32) {
        var value = value.bigEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
