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

