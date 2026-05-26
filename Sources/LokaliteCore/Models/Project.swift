import Foundation

public struct Project: Equatable, Hashable {
    public var id: String
    public var name: String
    public var path: String?
    public var activeEnvironment: String?
    public var icon: String?

    public init(id: String, name: String, path: String? = nil, activeEnvironment: String? = nil, icon: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.activeEnvironment = activeEnvironment
        self.icon = icon
    }
}
