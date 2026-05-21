import Foundation

public struct Secret: Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var value: String
    public var description: String?
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(name: String, value: String, description: String? = nil, tags: [String] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.value = value
        self.description = description
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
