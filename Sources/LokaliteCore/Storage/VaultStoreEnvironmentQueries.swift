import Foundation
import GRDB

extension VaultStore {
    // MARK: - Environments

    func insertEnvironment(_ record: EnvironmentRecord) throws {
        try db.write { db in
            guard try EnvironmentRecord
                .filter(Column("project_id") == record.projectId && Column("name") == record.name)
                .fetchCount(db) == 0 else {
                throw VaultError.environmentAlreadyExists(record.name)
            }
            try record.insert(db)
        }
    }

    func fetchAllEnvironments(projectId: String) throws -> [EnvironmentRecord] {
        try db.read { db in
            try EnvironmentRecord
                .filter(Column("project_id") == projectId)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    func fetchEnvironment(name: String, projectId: String) throws -> EnvironmentRecord? {
        try db.read { db in
            try EnvironmentRecord
                .filter(Column("project_id") == projectId && Column("name") == name)
                .fetchOne(db)
        }
    }

    func fetchEnvironment(id: String) throws -> EnvironmentRecord? {
        try db.read { db in
            try EnvironmentRecord.filter(Column("id") == id).fetchOne(db)
        }
    }

    func updateEnvironment(_ record: EnvironmentRecord) throws {
        try db.write { db in try record.update(db) }
    }

    func deleteEnvironment(name: String, projectId: String) throws {
        try db.write { db in
            guard let environment = try EnvironmentRecord
                .filter(Column("project_id") == projectId && Column("name") == name)
                .fetchOne(db) else {
                throw VaultError.environmentNotFound(name)
            }
            guard try SecretValueRecord
                .filter(Column("environment_id") == environment.id)
                .fetchCount(db) == 0 else {
                throw VaultError.environmentContainsSecrets(name)
            }
            let deleted = try EnvironmentRecord
                .filter(Column("project_id") == projectId && Column("name") == name)
                .deleteAll(db)
            guard deleted > 0 else { throw VaultError.environmentNotFound(name) }
            try db.execute(
                sql: "UPDATE projects SET active_environment = NULL, updated_at = ? WHERE id = ? AND active_environment = ?",
                arguments: [iso8601(), projectId, name]
            )
        }
    }

    func deleteEnvironmentIncludingContents(name: String, projectId: String) throws {
        try db.write { db in
            guard let environment = try EnvironmentRecord
                .filter(Column("project_id") == projectId && Column("name") == name)
                .fetchOne(db) else {
                throw VaultError.environmentNotFound(name)
            }

            try SecretValueRecord
                .filter(Column("environment_id") == environment.id)
                .deleteAll(db)
            try db.execute(sql: """
                DELETE FROM secrets
                WHERE project_id = ?
                  AND id NOT IN (SELECT DISTINCT secret_id FROM secret_values)
            """, arguments: [projectId])
            let deleted = try EnvironmentRecord
                .filter(Column("id") == environment.id)
                .deleteAll(db)
            guard deleted > 0 else { throw VaultError.environmentNotFound(name) }
            try db.execute(
                sql: "UPDATE projects SET active_environment = NULL, updated_at = ? WHERE id = ? AND active_environment = ?",
                arguments: [iso8601(), projectId, name]
            )
        }
    }

    func secretValueCount(environmentId: String) throws -> Int {
        try db.read { db in
            try SecretValueRecord
                .filter(Column("environment_id") == environmentId)
                .fetchCount(db)
        }
    }

    func renameProject(id: String, newName: String) throws {
        try db.write { db in
            guard try ProjectRecord.filter(Column("name") == newName).fetchCount(db) == 0 else {
                throw VaultError.projectAlreadyExists(newName)
            }
            try db.execute(sql: "UPDATE projects SET name = ?, updated_at = ? WHERE id = ?",
                          arguments: [newName, iso8601(), id])
        }
    }

    func renameEnvironment(id: String, newName: String, projectId: String) throws {
        try db.write { db in
            guard let env = try EnvironmentRecord.filter(Column("id") == id).fetchOne(db) else {
                throw VaultError.environmentNotFound(id)
            }
            let oldName = env.name
            guard try EnvironmentRecord
                .filter(Column("project_id") == projectId && Column("name") == newName)
                .fetchCount(db) == 0 else {
                throw VaultError.environmentAlreadyExists(newName)
            }
            try db.execute(sql: "UPDATE environments SET name = ? WHERE id = ?",
                          arguments: [newName, id])
            try db.execute(
                sql: "UPDATE projects SET active_environment = ?, updated_at = ? WHERE id = ? AND active_environment = ?",
                arguments: [newName, iso8601(), projectId, oldName])
        }
    }

    func moveSecretValue(secretId: String, fromEnvironmentId: String?, toEnvironmentId: String?) throws {
        try db.write { db in
            let source: SecretValueRecord?
            if let fromId = fromEnvironmentId {
                source = try SecretValueRecord
                    .filter(Column("secret_id") == secretId && Column("environment_id") == fromId)
                    .fetchOne(db)
            } else {
                source = try SecretValueRecord
                    .filter(Column("secret_id") == secretId && Column("environment_id") == nil)
                    .fetchOne(db)
            }
            guard var record = source else { return }

            if let toId = toEnvironmentId {
                try SecretValueRecord
                    .filter(Column("secret_id") == secretId && Column("environment_id") == toId)
                    .deleteAll(db)
            } else {
                try SecretValueRecord
                    .filter(Column("secret_id") == secretId && Column("environment_id") == nil)
                    .deleteAll(db)
            }

            record.environmentId = toEnvironmentId
            record.updatedAt = iso8601()
            try record.update(db)
        }
    }
}
