import CryptoKit
import Foundation
import Security

/// Outcome of importing `.env` pairs: how many secrets were created, replaced
/// (with `overwrite`), or skipped because they already existed.
public struct ImportSummary: Sendable, Equatable, Codable {
    public let added: Int
    public let updated: Int
    public let skipped: Int

    public init(added: Int, updated: Int, skipped: Int) {
        self.added = added
        self.updated = updated
        self.skipped = skipped
    }
}

public final class Vault {
    public static let shared = Vault()

    // The daemon serves on background threads while the app uses Vault.shared on
    // the main thread (ADR 0014), so the shared key/store are lock-guarded. The
    // lock is never held across a Keychain or DB call (GRDB serializes the DB
    // itself) and never re-entered, so it can't deadlock.
    private let stateLock = NSLock()
    private var _key: SymmetricKey?
    private var _store: VaultStore?

    private var key: SymmetricKey? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _key }
        set { stateLock.lock(); defer { stateLock.unlock() }; _key = newValue }
    }

    private var store: VaultStore {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let _store { return _store }
        let opened = try! openStore(at: vaultFileURL())
        _store = opened
        return opened
    }

    private init() {}

    /// Test seam: build a Vault over an explicit store (and optional key) so
    /// resolution, import, and project/environment logic can be exercised
    /// without the real vault file or Keychain. Not used in production code.
    init(store: VaultStore, key: SymmetricKey? = nil) {
        self._store = store
        self.key = key
    }

    // MARK: - Setup

    public func unlock() throws {
        do {
            let keyData = try KeychainStore.load()
            key = VaultCrypto.keyFromData(keyData)
        } catch VaultError.keychainReadFailed(let status) where status == errSecItemNotFound {
            let newKey = VaultCrypto.generateKey()
            try KeychainStore.save(VaultCrypto.keyToData(newKey))
            key = newKey
        } catch {
            throw error
        }
        _ = store
    }

    public func lock() {
        key = nil
    }

    // MARK: - Project Management

    public func addProject(name: String, path: String? = nil, icon: String? = nil) throws -> Project {
        let now = iso8601()
        let record = ProjectRecord(id: UUID().uuidString, name: name, path: path,
                                   activeEnvironment: "Default", icon: icon,
                                   createdAt: now, updatedAt: now)
        try store.insertProject(record)
        _ = try addEnvironment(name: "Default", projectId: record.id, color: nil)
        return Project(id: record.id, name: name, path: path, activeEnvironment: "Default", icon: icon)
    }

    public func listProjects() throws -> [Project] {
        try store.fetchAllProjects().map(projectFromRecord)
    }

    public func project(id: String) throws -> Project {
        guard let record = try store.fetchProject(id: id) else {
            throw VaultError.projectNotFound(id)
        }
        return projectFromRecord(record)
    }

    public func project(name: String) throws -> Project? {
        guard let record = try store.fetchProject(name: name) else { return nil }
        return projectFromRecord(record)
    }

    public func deleteProject(id: String) throws {
        let project = try project(id: id)
        guard try store.secretCount(projectId: id) == 0,
              try store.fetchAllEnvironments(projectId: id).isEmpty else {
            throw VaultError.projectContainsSecrets(project.name)
        }
        try store.deleteProject(id: id)
    }

    public func deleteProjectIncludingContents(id: String) throws {
        try store.deleteProjectIncludingContents(id: id)
    }

    public func activeProjectId() throws -> String? {
        try store.configValue(key: "active_project_id")
    }

    public func setActiveProject(id: String?) throws {
        try store.setConfigValue(key: "active_project_id", value: id)
    }

    public func linkProject(id: String, path: String?) throws {
        guard var record = try store.fetchProject(id: id) else {
            throw VaultError.projectNotFound(id)
        }
        record.path = path
        record.updatedAt = iso8601()
        try store.updateProject(record)
    }

    public func setActiveEnvironment(name: String?, projectId: String) throws {
        guard var record = try store.fetchProject(id: projectId) else {
            throw VaultError.projectNotFound(projectId)
        }
        if let name, name != "" {
            guard try store.fetchEnvironment(name: name, projectId: projectId) != nil else {
                throw VaultError.environmentNotFound(name)
            }
        }
        record.activeEnvironment = name.flatMap { $0.isEmpty ? nil : $0 }
        record.updatedAt = iso8601()
        try store.updateProject(record)
        // One synced active environment (ADR 0016): a switch from any caller — the
        // app, the CLI, or an agent via the daemon — notifies in-process observers
        // so the menu bar + manager refresh. Only the app process has observers.
        NotificationCenter.default.post(name: .lokaliteActiveEnvironmentDidChange, object: nil)
    }

    // MARK: - Environment Management

    public func addEnvironment(name: String, projectId: String, color: String? = nil) throws -> VaultEnvironment {
        let record = EnvironmentRecord(id: UUID().uuidString, projectId: projectId,
                                       name: name, color: color, createdAt: iso8601())
        try store.insertEnvironment(record)
        return VaultEnvironment(id: record.id, projectId: projectId, name: name, color: color)
    }

    public func listEnvironments(projectId: String) throws -> [VaultEnvironment] {
        try store.fetchAllEnvironments(projectId: projectId).map {
            VaultEnvironment(id: $0.id, projectId: $0.projectId, name: $0.name, color: $0.color)
        }
    }

    public func environment(name: String, projectId: String) throws -> VaultEnvironment? {
        guard let record = try store.fetchEnvironment(name: name, projectId: projectId) else {
            return nil
        }
        return VaultEnvironment(id: record.id, projectId: record.projectId, name: record.name, color: record.color)
    }

    public func deleteEnvironment(name: String, projectId: String) throws {
        guard let environment = try store.fetchEnvironment(name: name, projectId: projectId) else {
            throw VaultError.environmentNotFound(name)
        }
        guard try store.secretValueCount(environmentId: environment.id) == 0 else {
            throw VaultError.environmentContainsSecrets(name)
        }
        try store.deleteEnvironment(name: name, projectId: projectId)
    }

    public func deleteEnvironmentIncludingContents(name: String, projectId: String) throws {
        try store.deleteEnvironmentIncludingContents(name: name, projectId: projectId)
    }

    public func renameProject(id: String, newName: String) throws {
        try store.renameProject(id: id, newName: newName)
    }

    public func renameEnvironment(id: String, newName: String, projectId: String) throws {
        try store.renameEnvironment(id: id, newName: newName, projectId: projectId)
    }

    public func setProjectIcon(id: String, icon: String?) throws {
        guard var record = try store.fetchProject(id: id) else {
            throw VaultError.projectNotFound(id)
        }
        record.icon = icon.flatMap { $0.isEmpty ? nil : $0 }
        record.updatedAt = iso8601()
        try store.updateProject(record)
    }

    public func setEnvironmentColor(id: String, color: String?) throws {
        guard var record = try store.fetchEnvironment(id: id) else {
            throw VaultError.environmentNotFound(id)
        }
        record.color = color.flatMap { $0.isEmpty ? nil : $0 }
        try store.updateEnvironment(record)
    }

    // MARK: - Secret CRUD

    public func add(
        name: String,
        value: String,
        description: String? = nil,
        icon: String? = nil,
        category: SecretCategory? = nil,
        projectId: String,
        environmentName: String? = nil
    ) throws -> Secret {
        let key = try requireKey()
        let encrypted = try VaultCrypto.encrypt(value, using: key)
        let now = iso8601()
        let category = category ?? SecretCategory.infer(name: name, value: value, description: description)
        let environmentId = try resolveEnvironmentId(name: environmentName, projectId: projectId)

        let secretRecord: SecretRecord
        if let existing = try store.fetchSecret(name: name, projectId: projectId) {
            if try store.fetchSecretValue(secretId: existing.id, environmentId: environmentId) != nil {
                throw VaultError.secretAlreadyExists(name)
            }
            secretRecord = existing
        } else {
            let record = SecretRecord(id: UUID().uuidString, projectId: projectId,
                                      name: name, description: description, icon: icon,
                                      category: category.rawValue,
                                      createdAt: now, updatedAt: now)
            try store.insertSecret(record)
            secretRecord = record
        }

        let valueRecord = SecretValueRecord(id: UUID().uuidString, secretId: secretRecord.id,
                                            environmentId: environmentId, encryptedValue: encrypted,
                                            updatedAt: now)
        try store.upsertSecretValue(valueRecord)

        return Secret(id: secretRecord.id, name: name, value: value, description: description, icon: icon, category: category)
    }

    public func get(name: String, projectId: String, environmentName: String? = nil) throws -> Secret {
        let key = try requireKey()
        guard let secretRecord = try store.fetchSecret(name: name, projectId: projectId) else {
            throw VaultError.secretNotFound(name)
        }
        let environmentId = try resolveEnvironmentId(name: environmentName, projectId: projectId)
        guard let valueRecord = try store.fetchSecretValue(secretId: secretRecord.id,
                                                           environmentId: environmentId) else {
            throw VaultError.secretNotFound(name)
        }
        let value = try VaultCrypto.decrypt(valueRecord.encryptedValue, using: key)
        return secretFromRecord(secretRecord, value: value)
    }

    public func setDescription(name: String, description: String?, projectId: String) throws {
        guard var record = try store.fetchSecret(name: name, projectId: projectId) else {
            throw VaultError.secretNotFound(name)
        }
        record.description = description
        record.updatedAt = iso8601()
        try store.updateSecret(record)
    }

    public func setSecretCategory(name: String, category: SecretCategory, projectId: String) throws {
        guard var record = try store.fetchSecret(name: name, projectId: projectId) else {
            throw VaultError.secretNotFound(name)
        }
        record.category = category.rawValue
        record.updatedAt = iso8601()
        try store.updateSecret(record)
    }

    public func set(name: String, value: String, projectId: String,
                    environmentName: String? = nil) throws -> Secret {
        let key = try requireKey()
        guard var secretRecord = try store.fetchSecret(name: name, projectId: projectId) else {
            throw VaultError.secretNotFound(name)
        }
        let encrypted = try VaultCrypto.encrypt(value, using: key)
        secretRecord.category = SecretCategory
            .infer(name: secretRecord.name, value: value, description: secretRecord.description)
            .rawValue
        secretRecord.updatedAt = iso8601()
        try store.updateSecret(secretRecord)
        let environmentId = try resolveEnvironmentId(name: environmentName, projectId: projectId)
        let valueRecord = SecretValueRecord(id: UUID().uuidString, secretId: secretRecord.id,
                                            environmentId: environmentId, encryptedValue: encrypted,
                                            updatedAt: iso8601())
        try store.upsertSecretValue(valueRecord)
        return secretFromRecord(secretRecord, value: value)
    }

    /// Apply parsed `.env` key/value pairs to a project + environment.
    /// Existing secrets are skipped unless `overwrite` is set. Shared by the
    /// CLI (`import`, `init --from-env`) and the app so summaries stay consistent.
    @discardableResult
    public func importEnv(
        pairs: [(name: String, value: String)],
        projectId: String,
        environmentName: String? = nil,
        overwrite: Bool = false
    ) throws -> ImportSummary {
        var added = 0, updated = 0, skipped = 0
        for (name, value) in pairs {
            do {
                _ = try add(name: name, value: value, projectId: projectId, environmentName: environmentName)
                added += 1
            } catch VaultError.secretAlreadyExists {
                if overwrite {
                    _ = try set(name: name, value: value, projectId: projectId, environmentName: environmentName)
                    updated += 1
                } else {
                    skipped += 1
                }
            }
        }
        return ImportSummary(added: added, updated: updated, skipped: skipped)
    }

    /// Creates a project from parsed `.env` pairs and imports them, making the
    /// new project the active project. A non-Default `environmentName` renames
    /// the auto-created Default rather than leaving an empty one behind, so the
    /// project ends with exactly one environment. Returns the refreshed project
    /// (its `activeEnvironment` reflects any rename), the target environment
    /// name, and the import summary.
    public func createProjectFromEnv(
        name: String,
        environmentName: String,
        linkPath: String?,
        pairs: [(name: String, value: String)],
        overwrite: Bool = false
    ) throws -> (project: Project, environmentName: String, summary: ImportSummary) {
        let created = try addProject(name: name, path: linkPath, icon: "folder")

        var target = "Default"
        if environmentName != "Default", !environmentName.isEmpty {
            if let def = try environment(name: "Default", projectId: created.id) {
                try renameEnvironment(id: def.id, newName: environmentName, projectId: created.id)
            }
            try setActiveEnvironment(name: environmentName, projectId: created.id)
            target = environmentName
        }

        let summary = try importEnv(pairs: pairs, projectId: created.id,
                                    environmentName: target, overwrite: overwrite)
        try setActiveProject(id: created.id)
        return (try project(id: created.id), target, summary)
    }

    public func moveSecretToEnvironment(name: String, projectId: String,
                                        fromEnvironmentName: String?,
                                        toEnvironmentName: String?) throws {
        guard let secretRecord = try store.fetchSecret(name: name, projectId: projectId) else {
            throw VaultError.secretNotFound(name)
        }
        let fromEnvId = try resolveEnvironmentId(name: fromEnvironmentName, projectId: projectId)
        let toEnvId = try resolveEnvironmentId(name: toEnvironmentName, projectId: projectId)
        try store.moveSecretValue(secretId: secretRecord.id, fromEnvironmentId: fromEnvId, toEnvironmentId: toEnvId)
    }

    public func moveSecretToProject(name: String, fromProjectId: String, toProjectId: String,
                                     fromEnvironmentName: String?) throws {
        let key = try requireKey()
        guard let secretRecord = try store.fetchSecret(name: name, projectId: fromProjectId) else {
            throw VaultError.secretNotFound(name)
        }
        if try store.fetchSecret(name: name, projectId: toProjectId) != nil {
            throw VaultError.secretAlreadyExists(name)
        }
        let fromEnvId = try resolveEnvironmentId(name: fromEnvironmentName, projectId: fromProjectId)
        guard let valueRecord = try store.fetchSecretValue(secretId: secretRecord.id,
                                                           environmentId: fromEnvId) else {
            throw VaultError.secretNotFound(name)
        }
        let value = try VaultCrypto.decrypt(valueRecord.encryptedValue, using: key)
        _ = try add(name: name, value: value, description: secretRecord.description, icon: secretRecord.icon,
                    projectId: toProjectId, environmentName: nil)
        try store.deleteSecret(name: name, projectId: fromProjectId)
    }

    public func delete(name: String, projectId: String) throws {
        try store.deleteSecret(name: name, projectId: projectId)
    }

    public func list(projectId: String, environmentName: String? = nil) throws -> [Secret] {
        let key = try requireKey()
        let secrets = try store.fetchAllSecrets(projectId: projectId)
        let environmentId = try resolveEnvironmentId(name: environmentName, projectId: projectId)
        return try secrets.compactMap { secretRecord in
            guard let valueRecord = try store.fetchSecretValue(secretId: secretRecord.id,
                                                               environmentId: environmentId) else {
                return nil
            }
            let value = try VaultCrypto.decrypt(valueRecord.encryptedValue, using: key)
            return secretFromRecord(secretRecord, value: value)
        }
    }

    public func listInfo(projectId: String) throws -> [SecretInfo] {
        try store.fetchAllSecrets(projectId: projectId).map {
            SecretInfo(name: $0.name, description: $0.description, icon: $0.icon,
                       category: category(from: $0), agentAccess: agentAccess(from: $0))
        }
    }

    /// Sets whether AI agents may read a secret (ADR 0014).
    public func setAgentAccess(name: String, projectId: String, policy: AgentAccessPolicy) throws {
        guard var record = try store.fetchSecret(name: name, projectId: projectId) else {
            throw VaultError.secretNotFound(name)
        }
        record.agentAccess = policy.rawValue
        record.updatedAt = iso8601()
        try store.updateSecret(record)
    }

    public func secretCount(projectId: String, environmentName: String? = nil) throws -> Int {
        let environmentId = try resolveEnvironmentId(name: environmentName, projectId: projectId)
        return try store.countSecretValuesInEnvironment(projectId: projectId, environmentId: environmentId)
    }

    public func totalSecretCount(projectId: String) throws -> Int {
        try store.secretCount(projectId: projectId)
    }

    public func secretEnvironmentNames(projectId: String) throws -> [String: [String]] {
        let environments = try store.fetchAllEnvironments(projectId: projectId)
        let environmentNamesById = Dictionary(uniqueKeysWithValues: environments.map { ($0.id, $0.name) })
        let secrets = try store.fetchAllSecrets(projectId: projectId)

        let orderedNames = environments.map { $0.name }
        let orderedIndex = Dictionary(uniqueKeysWithValues: orderedNames.enumerated().map { ($1, $0) })
        var result: [String: [String]] = [:]
        for secret in secrets {
            let values = try store.fetchAllSecretValues(secretId: secret.id)
            let names = Set(values.map { value in
                value.environmentId.flatMap { environmentNamesById[$0] } ?? "Default"
            })
            result[secret.name] = names.sorted { (orderedIndex[$0] ?? Int.max) < (orderedIndex[$1] ?? Int.max) }
        }
        return result
    }

    // MARK: - Project Resolution

    public func resolveProject(name: String? = nil, workingDirectory: String? = nil) throws -> Project {
        if let name {
            guard let p = try project(name: name) else {
                throw VaultError.projectNotFound(name)
            }
            return p
        }

        if let dir = workingDirectory,
           let record = try store.fetchProject(matchingPath: dir) {
            return projectFromRecord(record)
        }

        if let activeId = try activeProjectId(),
           let record = try store.fetchProject(id: activeId) {
            return projectFromRecord(record)
        }

        let all = try store.fetchAllProjects()
        if all.count == 1 { return projectFromRecord(all[0]) }

        throw VaultError.noActiveProject
    }

    // MARK: - Activity Log

    public func logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource, agent: String? = nil, peerTeamID: String? = nil, action: ActivityLogEntry.Action = .read) {
        let record = ActivityLogRecord(
            id: UUID().uuidString,
            secretName: secretName,
            projectName: projectName,
            environmentName: environmentName,
            source: source.rawValue,
            accessedAt: iso8601(),
            agent: agent,
            peerTeam: peerTeamID,
            action: action.rawValue
        )
        try? store.insertActivityLog(record)
    }

    public func listActivity(limit: Int = 100) throws -> [ActivityLogEntry] {
        return try store.fetchActivityLogs(limit: limit).map { record in
            ActivityLogEntry(
                id: record.id,
                secretName: record.secretName,
                projectName: record.projectName,
                environmentName: record.environmentName,
                source: ActivityLogEntry.AccessSource(rawValue: record.source) ?? .app,
                accessedAt: Self.dateFormatter.date(from: record.accessedAt) ?? Date(),
                agent: record.agent,
                peerTeamID: record.peerTeam,
                action: ActivityLogEntry.Action(rawValue: record.action) ?? .read
            )
        }
    }

    // MARK: - Export

    public func export(projectId: String, passphrase: String?) throws -> Data {
        try exportData(secrets: list(projectId: projectId), passphrase: passphrase)
    }

    /// Like `export(projectId:passphrase:)` but omits approval-tier
    /// (`requiresApproval`/`strict`) secrets — bulk paths (`backup`, plain
    /// export) must not release them without consent (ADR 0018). Returns the
    /// payload plus the omitted names so the caller can print the skip notice
    /// (never a value); a restore of the payload will not contain them.
    public func exportExcludingApprovalTier(projectId: String, passphrase: String?) throws -> (data: Data, skippedNames: [String]) {
        let secrets = try list(projectId: projectId)
        let released = secrets.filter { !$0.agentAccess.requiresApprovalForAgents }
        let skipped = secrets.filter { $0.agentAccess.requiresApprovalForAgents }.map(\.name)
        return (try exportData(secrets: released, passphrase: passphrase), skipped)
    }

    private func exportData(secrets: [Secret], passphrase: String?) throws -> Data {
        let dict = Dictionary(uniqueKeysWithValues: secrets.map { ($0.name, $0.value) })
        let json = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)

        if let passphrase {
            return try encryptExport(json, passphrase: passphrase)
        }
        return json
    }

    /// Decrypts an encrypted export envelope produced by `export(projectId:passphrase:)`
    /// and returns the `[name: value]` map it contains. Throws `invalidExportPassphrase`
    /// when the passphrase is wrong or the file is not a valid encrypted export.
    public func decryptExport(_ envelope: Data, passphrase: String) throws -> [String: String] {
        guard envelope.first == 0x02, envelope.count > 13 + 32 else {
            throw VaultError.invalidExportPassphrase
        }
        var offset = envelope.startIndex + 1
        let iterations = envelope.readUInt32(at: &offset)
        let memoryKiB = envelope.readUInt32(at: &offset)
        let parallelism = envelope.readUInt32(at: &offset)
        let salt = envelope.subdata(in: offset..<(offset + 32))
        offset += 32
        let combined = envelope.subdata(in: offset..<envelope.endIndex)

        let parameters = ExportKDFParameters(iterations: iterations, memoryKiB: memoryKiB, parallelism: parallelism)
        do {
            let derivedKey = try VaultCrypto.deriveExportKey(from: passphrase, salt: salt, parameters: parameters)
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let json = try AES.GCM.open(sealedBox, using: derivedKey)
            guard let dict = try JSONSerialization.jsonObject(with: json) as? [String: String] else {
                throw VaultError.invalidExportPassphrase
            }
            return dict
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultError.invalidExportPassphrase
        }
    }

    private func encryptExport(_ data: Data, passphrase: String) throws -> Data {
        let kdfParameters = ExportKDFParameters.current
        let salt = try VaultCrypto.generateSalt()
        let derivedKey = try VaultCrypto.deriveExportKey(
            from: passphrase,
            salt: salt,
            parameters: kdfParameters
        )
        guard let combined = try AES.GCM.seal(data, using: derivedKey).combined else {
            throw VaultError.encryptionFailed
        }
        var envelope = Data()
        envelope.append(0x02)
        envelope.appendUInt32(kdfParameters.iterations)
        envelope.appendUInt32(kdfParameters.memoryKiB)
        envelope.appendUInt32(kdfParameters.parallelism)
        envelope.append(salt)
        envelope.append(combined)
        return envelope
    }

    // MARK: - Helpers

    private func requireKey() throws -> SymmetricKey {
        guard let key else {
            throw VaultError.keychainReadFailed(errSecAuthFailed)
        }
        return key
    }

    private func resolveEnvironmentId(name: String?, projectId: String) throws -> String? {
        let resolvedName: String?
        if let name {
            resolvedName = name
        } else {
            resolvedName = try store.fetchProject(id: projectId)?.activeEnvironment
        }
        guard let name = resolvedName else { return nil }
        guard let env = try store.fetchEnvironment(name: name, projectId: projectId) else {
            throw VaultError.environmentNotFound(name)
        }
        return env.id
    }

    private static let dateFormatter = ISO8601DateFormatter()

    private func projectFromRecord(_ record: ProjectRecord) -> Project {
        let createdAt = Self.dateFormatter.date(from: record.createdAt)
        return Project(id: record.id, name: record.name, path: record.path,
                       activeEnvironment: record.activeEnvironment, icon: record.icon,
                       createdAt: createdAt)
    }

    private func secretFromRecord(_ record: SecretRecord, value: String) -> Secret {
        Secret(id: record.id, name: record.name, value: value, description: record.description,
               icon: record.icon, category: category(from: record), agentAccess: agentAccess(from: record))
    }

    private func category(from record: SecretRecord) -> SecretCategory {
        SecretCategory(rawValue: record.category) ?? .other
    }

    private func agentAccess(from record: SecretRecord) -> AgentAccessPolicy {
        AgentAccessPolicy(rawValue: record.agentAccess) ?? .allowed
    }

    private func vaultFileURL() -> URL {
        let dir = VaultConfiguration.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return VaultConfiguration.vaultFileURL
    }

    private func openStore(at url: URL) throws -> VaultStore {
        do {
            return try VaultStore(path: url.path)
        } catch {
            throw VaultError.databaseError(error.localizedDescription)
        }
    }

    private func iso8601() -> String {
        Self.dateFormatter.string(from: Date())
    }
}

private extension Data {
    mutating func appendUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    func readUInt32(at offset: inout Index) -> UInt32 {
        let bytes = self[offset..<(offset + 4)]
        offset += 4
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }
}

public extension Notification.Name {
    /// Posted by `Vault.setActiveEnvironment` whenever a project's active
    /// environment changes, so the app can refresh the menu bar + manager when an
    /// agent (via the daemon) or the CLI switches it (ADR 0016).
    static let lokaliteActiveEnvironmentDidChange = Notification.Name("lokaliteActiveEnvironmentDidChange")
}
