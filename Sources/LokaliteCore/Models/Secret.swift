import Foundation

public struct Secret: Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var value: String
    public var description: String?
    public var icon: String?
    public var category: SecretCategory
    public var agentAccess: AgentAccessPolicy

    public init(
        id: String = UUID().uuidString,
        name: String,
        value: String,
        description: String? = nil,
        icon: String? = nil,
        category: SecretCategory = .other,
        agentAccess: AgentAccessPolicy = .allowed
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.description = description
        self.icon = icon
        self.category = category
        self.agentAccess = agentAccess
    }
}
