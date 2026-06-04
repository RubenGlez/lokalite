import Foundation
import GRDB

// MARK: - Records

struct ConfigRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "config"
    var key: String
    var value: String
}

struct ProjectRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "projects"
    var id: String
    var name: String
    var path: String?
    var activeEnvironment: String?
    var icon: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, path, icon
        case activeEnvironment = "active_environment"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EnvironmentRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "environments"
    var id: String
    var projectId: String
    var name: String
    var color: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case name, color
        case createdAt = "created_at"
    }
}

struct SecretRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "secrets"
    var id: String
    var projectId: String
    var name: String
    var description: String?
    var icon: String?
    var category: String
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case name, description, icon, category
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SecretValueRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "secret_values"
    var id: String
    var secretId: String
    var environmentId: String?
    var encryptedValue: Data
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case secretId = "secret_id"
        case environmentId = "environment_id"
        case encryptedValue = "encrypted_value"
        case updatedAt = "updated_at"
    }
}

struct ActivityLogRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "activity_log"
    var id: String
    var secretName: String
    var projectName: String
    var environmentName: String
    var source: String
    var accessedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case secretName = "secret_name"
        case projectName = "project_name"
        case environmentName = "environment_name"
        case source
        case accessedAt = "accessed_at"
    }
}

// MARK: - Store

final class VaultStore {
    private let db: DatabaseQueue

    init(path: String) throws {
        var config = Configuration()
        config.journalMode = .wal
        db = try DatabaseQueue(path: path, configuration: config)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            let now = iso8601()

            try db.create(table: "config") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }

            try db.create(table: "projects") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("path", .text)
                t.column("active_environment", .text)
                t.column("icon", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "environments") { t in
                t.column("id", .text).primaryKey()
                t.column("project_id", .text).notNull().references("projects", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.column("created_at", .text).notNull()
                t.uniqueKey(["project_id", "name"])
            }

            try db.create(table: "secrets") { t in
                t.column("id", .text).primaryKey()
                t.column("project_id", .text).notNull().references("projects", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("icon", .text)
                t.column("category", .text).notNull().defaults(to: SecretCategory.secret.rawValue)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
                t.uniqueKey(["project_id", "name"])
            }

            try db.create(table: "secret_values") { t in
                t.column("id", .text).primaryKey()
                t.column("secret_id", .text).notNull().references("secrets", onDelete: .cascade)
                t.column("environment_id", .text).references("environments", onDelete: .cascade)
                t.column("encrypted_value", .blob).notNull()
                t.column("updated_at", .text).notNull()
                t.uniqueKey(["secret_id", "environment_id"])
            }

            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS secret_values_unique_default_environment
                ON secret_values(secret_id)
                WHERE environment_id IS NULL
            """)

            let defaultProjectId = UUID().uuidString
            try db.execute(sql: """
                INSERT INTO projects (id, name, path, active_environment, icon, created_at, updated_at)
                VALUES (?, 'Default', NULL, NULL, 'folder', ?, ?)
            """, arguments: [defaultProjectId, now, now])

            try db.execute(sql: "INSERT INTO config (key, value) VALUES ('active_project_id', ?)",
                           arguments: [defaultProjectId])
        }

        migrator.registerMigration("v3") { db in
            try db.create(table: "activity_log", options: .ifNotExists) { t in
                t.column("id", .text).primaryKey()
                t.column("secret_name", .text).notNull()
                t.column("project_name", .text).notNull()
                t.column("environment_name", .text).notNull()
                t.column("source", .text).notNull()
                t.column("accessed_at", .text).notNull()
            }
        }

        try migrator.migrate(db)
    }

    // MARK: - Config

    func configValue(key: String) throws -> String? {
        try db.read { db in
            try ConfigRecord.filter(Column("key") == key).fetchOne(db)?.value
        }
    }

    func setConfigValue(key: String, value: String?) throws {
        try db.write { db in
            if let value {
                try db.execute(sql: "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)",
                               arguments: [key, value])
            } else {
                try db.execute(sql: "DELETE FROM config WHERE key = ?", arguments: [key])
            }
        }
    }

    // MARK: - Projects

    func insertProject(_ record: ProjectRecord) throws {
        try db.write { db in
            guard try ProjectRecord.filter(Column("name") == record.name).fetchCount(db) == 0 else {
                throw VaultError.projectAlreadyExists(record.name)
            }
            try record.insert(db)
        }
    }

    func fetchAllProjects() throws -> [ProjectRecord] {
        try db.read { db in
            try ProjectRecord.order(Column("name")).fetchAll(db)
        }
    }

    func fetchProject(id: String) throws -> ProjectRecord? {
        try db.read { db in
            try ProjectRecord.filter(Column("id") == id).fetchOne(db)
        }
    }

    func fetchProject(name: String) throws -> ProjectRecord? {
        try db.read { db in
            try ProjectRecord.filter(Column("name") == name).fetchOne(db)
        }
    }

    func fetchProject(matchingPath path: String) throws -> ProjectRecord? {
        try db.read { db in
            let projects = try ProjectRecord.filter(Column("path") != nil).fetchAll(db)
            return projects.first { record in
                guard let recordPath = record.path else { return false }
                return path == recordPath || path.hasPrefix(recordPath + "/")
            }
        }
    }

    func updateProject(_ record: ProjectRecord) throws {
        try db.write { db in try record.update(db) }
    }

    func deleteProject(id: String) throws {
        try db.write { db in
            guard let project = try ProjectRecord.filter(Column("id") == id).fetchOne(db) else {
                throw VaultError.projectNotFound(id)
            }
            guard try SecretRecord.filter(Column("project_id") == id).fetchCount(db) == 0 else {
                throw VaultError.projectContainsSecrets(project.name)
            }
            let deleted = try ProjectRecord.filter(Column("id") == id).deleteAll(db)
            guard deleted > 0 else { throw VaultError.projectNotFound(id) }
        }
    }

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
            if let environmentId = record.environmentId {
                try SecretValueRecord
                    .filter(Column("secret_id") == record.secretId && Column("environment_id") == environmentId)
                    .deleteAll(db)
            } else {
                try SecretValueRecord
                    .filter(Column("secret_id") == record.secretId && Column("environment_id") == nil)
                    .deleteAll(db)
            }
            try record.insert(db)
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

    // MARK: - Activity Log

    func insertActivityLog(_ record: ActivityLogRecord) throws {
        try db.write { db in try record.insert(db) }
    }

    func fetchActivityLogs(limit: Int = 100) throws -> [ActivityLogRecord] {
        try db.read { db in
            try ActivityLogRecord
                .order(Column("accessed_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}

private func iso8601() -> String {
    ISO8601DateFormatter().string(from: Date())
}
