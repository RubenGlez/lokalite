import Foundation
import GRDB

extension VaultStore {
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
            let sortedProjects = projects.sorted { ($0.path?.count ?? 0) > ($1.path?.count ?? 0) }
            return sortedProjects.first { record in
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
            let secretCount = try SecretRecord.filter(Column("project_id") == id).fetchCount(db)
            let environmentCount = try EnvironmentRecord.filter(Column("project_id") == id).fetchCount(db)
            guard secretCount == 0 && environmentCount == 0 else {
                throw VaultError.projectContainsSecrets(project.name)
            }
            let deleted = try ProjectRecord.filter(Column("id") == id).deleteAll(db)
            guard deleted > 0 else { throw VaultError.projectNotFound(id) }
            try db.execute(
                sql: "DELETE FROM config WHERE key = 'active_project_id' AND value = ?",
                arguments: [id]
            )
        }
    }

    func deleteProjectIncludingContents(id: String) throws {
        try db.write { db in
            guard try ProjectRecord.filter(Column("id") == id).fetchOne(db) != nil else {
                throw VaultError.projectNotFound(id)
            }
            try db.execute(sql: """
                DELETE FROM secret_values
                WHERE secret_id IN (SELECT id FROM secrets WHERE project_id = ?)
            """, arguments: [id])
            try SecretRecord.filter(Column("project_id") == id).deleteAll(db)
            try EnvironmentRecord.filter(Column("project_id") == id).deleteAll(db)
            let deleted = try ProjectRecord.filter(Column("id") == id).deleteAll(db)
            guard deleted > 0 else { throw VaultError.projectNotFound(id) }
            try db.execute(
                sql: "DELETE FROM config WHERE key = 'active_project_id' AND value = ?",
                arguments: [id]
            )
        }
    }
}
