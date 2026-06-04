import Foundation
import GRDB

extension VaultStore {
    // MARK: - Secrets

    func insertSecret(_ record: SecretRecord) throws {
        try db.write { db in
            guard try SecretRecord
                .filter(Column("project_id") == record.projectId && Column("name") == record.name)
                .fetchCount(db) == 0 else {
                throw VaultError.secretAlreadyExists(record.name)
            }
            try record.insert(db)
        }
    }

    func fetchSecret(name: String, projectId: String) throws -> SecretRecord? {
        try db.read { db in
            try SecretRecord
                .filter(Column("project_id") == projectId && Column("name") == name)
                .fetchOne(db)
        }
    }

    func fetchAllSecrets(projectId: String) throws -> [SecretRecord] {
        try db.read { db in
            try SecretRecord
                .filter(Column("project_id") == projectId)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    func secretCount(projectId: String) throws -> Int {
        try db.read { db in
            try SecretRecord
                .filter(Column("project_id") == projectId)
                .fetchCount(db)
        }
    }

    func updateSecret(_ record: SecretRecord) throws {
        try db.write { db in try record.update(db) }
    }

    func deleteSecret(name: String, projectId: String) throws {
        try db.write { db in
            let deleted = try SecretRecord
                .filter(Column("project_id") == projectId && Column("name") == name)
                .deleteAll(db)
            guard deleted > 0 else { throw VaultError.secretNotFound(name) }
        }
    }

    // MARK: - Secret Values

    func upsertSecretValue(_ record: SecretValueRecord) throws {
        try db.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO secret_values (id, secret_id, environment_id, encrypted_value, updated_at)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [record.id, record.secretId, record.environmentId,
                             record.encryptedValue, record.updatedAt])
        }
    }

    func fetchSecretValue(secretId: String, environmentId: String?) throws -> SecretValueRecord? {
        try db.read { db in
            if let environmentId {
                return try SecretValueRecord
                    .filter(Column("secret_id") == secretId && Column("environment_id") == environmentId)
                    .fetchOne(db)
            }
            return try SecretValueRecord
                .filter(Column("secret_id") == secretId && Column("environment_id") == nil)
                .fetchOne(db)
        }
    }

    func fetchAllSecretValues(secretId: String) throws -> [SecretValueRecord] {
        try db.read { db in
            try SecretValueRecord.filter(Column("secret_id") == secretId).fetchAll(db)
        }
    }

    #if DEBUG
    func insertSecretValueForTesting(_ record: SecretValueRecord) throws {
        try db.write { db in try record.insert(db) }
    }
    #endif

    func countSecretValuesInEnvironment(projectId: String, environmentId: String?) throws -> Int {
        try db.read { db in
            if let environmentId {
                return try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM secret_values sv
                    JOIN secrets s ON s.id = sv.secret_id
                    WHERE s.project_id = ? AND sv.environment_id = ?
                """, arguments: [projectId, environmentId]) ?? 0
            } else {
                return try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM secret_values sv
                    JOIN secrets s ON s.id = sv.secret_id
                    WHERE s.project_id = ? AND sv.environment_id IS NULL
                """, arguments: [projectId]) ?? 0
            }
        }
    }
}
