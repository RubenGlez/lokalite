import Foundation
import GRDB

extension VaultStore {
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
