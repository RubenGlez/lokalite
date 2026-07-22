import Foundation
import GRDB

extension VaultStore {
    // MARK: - Activity Log

    func insertActivityLog(_ record: ActivityLogRecord) throws {
        try db.write { db in try record.insert(db) }
    }

    func fetchActivityLogs(limit: Int = 100, filter: ActivityFilter = ActivityFilter()) throws -> [ActivityLogRecord] {
        var request = ActivityLogRecord.all()
        if let projectName = filter.projectName {
            request = request.filter(Column("project_name") == projectName)
        }
        if let source = filter.source {
            request = request.filter(Column("source") == source.rawValue)
        }
        if let action = filter.action {
            request = request.filter(Column("action") == action.rawValue)
        }
        let term = filter.search.trimmingCharacters(in: .whitespaces)
        if !term.isEmpty {
            let pattern = "%\(term)%"
            request = request.filter(
                Column("secret_name").like(pattern)
                    || Column("environment_name").like(pattern)
                    || Column("agent").like(pattern)
            )
        }
        return try db.read { db in
            try request
                .order(Column("accessed_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
