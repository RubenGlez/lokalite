import Foundation

public struct ActivityLogEntry: Identifiable, Sendable {
    public let id: String
    public let secretName: String
    public let projectName: String
    public let environmentName: String
    public let source: AccessSource
    public let accessedAt: Date

    public enum AccessSource: String, Sendable {
        case app, cli, mcp
    }
}
