import Foundation

public struct VaultEnvironment: Equatable, Hashable {
    public var id: String
    public var projectId: String
    public var name: String

    public init(id: String, projectId: String, name: String) {
        self.id = id
        self.projectId = projectId
        self.name = name
    }

    public static func == (lhs: VaultEnvironment, rhs: VaultEnvironment) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
