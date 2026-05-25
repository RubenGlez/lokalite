import Foundation

public struct VaultEnvironment: Equatable, Hashable {
    public var id: String
    public var projectId: String
    public var name: String
    public var color: String?

    public init(id: String, projectId: String, name: String, color: String? = nil) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.color = color
    }

    public static func == (lhs: VaultEnvironment, rhs: VaultEnvironment) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
