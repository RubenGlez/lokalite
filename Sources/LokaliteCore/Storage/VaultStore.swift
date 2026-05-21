import Foundation
import GRDB

struct SecretRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "secrets"

    var id: String
    var name: String
    var description: String?
    var tags: String
    var encryptedValue: Data
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case tags
        case encryptedValue = "encrypted_value"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

final class VaultStore {
    private let db: DatabaseQueue

    init(path: String) throws {
        db = try DatabaseQueue(path: path)
        var config = db.configuration
        config.journalMode = .wal
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "secrets") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("description", .text)
                t.column("tags", .text).notNull().defaults(to: "[]")
                t.column("encrypted_value", .blob).notNull()
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }
        }
        try migrator.migrate(db)
    }

    func insert(_ record: SecretRecord) throws {
        try db.write { db in
            guard try SecretRecord.filter(Column("name") == record.name).fetchCount(db) == 0 else {
                throw VaultError.secretAlreadyExists(record.name)
            }
            try record.insert(db)
        }
    }

    func update(_ record: SecretRecord) throws {
        try db.write { db in
            try record.update(db)
        }
    }

    func upsert(_ record: SecretRecord) throws {
        try db.write { db in
            try record.save(db)
        }
    }

    func delete(name: String) throws {
        try db.write { db in
            let deleted = try SecretRecord.filter(Column("name") == name).deleteAll(db)
            guard deleted > 0 else {
                throw VaultError.secretNotFound(name)
            }
        }
    }

    func fetch(name: String) throws -> SecretRecord? {
        try db.read { db in
            try SecretRecord.filter(Column("name") == name).fetchOne(db)
        }
    }

    func fetchAll(tag: String? = nil) throws -> [SecretRecord] {
        try db.read { db in
            if let tag {
                return try SecretRecord
                    .filter(Column("tags").like("%\(tag)%"))
                    .order(Column("name"))
                    .fetchAll(db)
            }
            return try SecretRecord.order(Column("name")).fetchAll(db)
        }
    }
}
