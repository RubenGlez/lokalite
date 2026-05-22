import Foundation

public struct Project: Equatable, Hashable {
    public var id: String
    public var name: String
    public var path: String?
    public var activeEnvironment: String?

    public static func == (lhs: Project, rhs: Project) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
