import Foundation
import GRDB

extension VaultStore {
    func migrate() throws {
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
}
