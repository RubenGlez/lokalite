import Foundation

/// One `.env` key/value pair on the wire (tuples aren't `Codable`).
public struct EnvPair: Codable, Equatable {
    public let name: String
    public let value: String
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// A `VaultService` call serialized for transport to the daemon (ADR 0014).
/// One case per protocol method; `Codable` is synthesized for the enum.
public enum VaultRequest: Codable, Equatable {
    case unlock
    case resolveProject(name: String?, workingDirectory: String?)
    case listProjects
    case add(name: String, value: String, description: String?, icon: String?, category: SecretCategory?, projectId: String, environmentName: String?)
    case get(name: String, projectId: String, environmentName: String?)
    case set(name: String, value: String, projectId: String, environmentName: String?)
    case delete(name: String, projectId: String)
    case list(projectId: String, environmentName: String?)
    case listInfo(projectId: String)
    case importEnv(pairs: [EnvPair], projectId: String, environmentName: String?, overwrite: Bool)
    case logAccess(secretName: String, projectName: String, environmentName: String, source: ActivityLogEntry.AccessSource)
}

/// The daemon's reply. `.failure` carries a human-readable message; everything
/// else is the typed result of the corresponding request.
public enum VaultResponse: Codable, Equatable {
    case ok
    case secret(Secret)
    case secrets([Secret])
    case project(Project)
    case projects([Project])
    case secretInfos([SecretInfo])
    case importSummary(ImportSummary)
    case failure(message: String)
}

/// Applies a decoded request to a local `VaultService` and produces a response.
/// Used by the daemon's socket server; pure and testable without any socket.
public enum VaultRequestDispatcher {
    public static func handle(_ request: VaultRequest, using service: VaultService) -> VaultResponse {
        do {
            switch request {
            case .unlock:
                try service.unlock()
                return .ok
            case let .resolveProject(name, workingDirectory):
                return .project(try service.resolveProject(name: name, workingDirectory: workingDirectory))
            case .listProjects:
                return .projects(try service.listProjects())
            case let .add(name, value, description, icon, category, projectId, environmentName):
                return .secret(try service.add(name: name, value: value, description: description, icon: icon, category: category, projectId: projectId, environmentName: environmentName))
            case let .get(name, projectId, environmentName):
                return .secret(try service.get(name: name, projectId: projectId, environmentName: environmentName))
            case let .set(name, value, projectId, environmentName):
                return .secret(try service.set(name: name, value: value, projectId: projectId, environmentName: environmentName))
            case let .delete(name, projectId):
                try service.delete(name: name, projectId: projectId)
                return .ok
            case let .list(projectId, environmentName):
                return .secrets(try service.list(projectId: projectId, environmentName: environmentName))
            case let .listInfo(projectId):
                return .secretInfos(try service.listInfo(projectId: projectId))
            case let .importEnv(pairs, projectId, environmentName, overwrite):
                let tuples = pairs.map { (name: $0.name, value: $0.value) }
                return .importSummary(try service.importEnv(pairs: tuples, projectId: projectId, environmentName: environmentName, overwrite: overwrite))
            case let .logAccess(secretName, projectName, environmentName, source):
                service.logAccess(secretName: secretName, projectName: projectName, environmentName: environmentName, source: source)
                return .ok
            }
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }
}
