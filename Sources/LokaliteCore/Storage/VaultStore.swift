import Foundation
import GRDB

final class VaultStore {
    let db: DatabaseQueue

    init(path: String, migrationTarget: String? = nil) throws {
        var config = Configuration()
        config.journalMode = .wal
        db = try DatabaseQueue(path: path, configuration: config)
        try migrate(upTo: migrationTarget)
    }
}
