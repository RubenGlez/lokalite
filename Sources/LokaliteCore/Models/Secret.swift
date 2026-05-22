import Foundation

public struct Secret: Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var value: String
    public var description: String?

    public init(name: String, value: String, description: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.value = value
        self.description = description
    }
}
