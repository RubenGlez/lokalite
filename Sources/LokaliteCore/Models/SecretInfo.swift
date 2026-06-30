import Foundation

public struct SecretInfo: Codable, Equatable {
    public var name: String
    public var description: String?
    public var icon: String?
    public var category: SecretCategory
    public var agentAccess: AgentAccessPolicy = .allowed
}
