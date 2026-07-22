import Foundation

public struct ActivityLogEntry: Identifiable, Sendable {
    public let id: String
    public let secretName: String
    public let projectName: String
    public let environmentName: String
    public let source: AccessSource
    public let accessedAt: Date
    /// The detected AI agent token (e.g. `claude`, `cursor`), or nil for a human
    /// or unattributed caller. Stamped by the daemon from the kernel peer-PID.
    public let agent: String?
    /// The Developer ID team of the genuine signed binary that brokered this read,
    /// when verified (ADR 0019); nil when unverified, in dev, or app-local. Set
    /// daemon-side from the peer's code signature — the client cannot forge it.
    public let peerTeamID: String?
    /// What the caller did to the secret.
    public let action: Action

    public init(
        id: String,
        secretName: String,
        projectName: String,
        environmentName: String,
        source: AccessSource,
        accessedAt: Date,
        agent: String? = nil,
        peerTeamID: String? = nil,
        action: Action = .read
    ) {
        self.id = id
        self.secretName = secretName
        self.projectName = projectName
        self.environmentName = environmentName
        self.source = source
        self.accessedAt = accessedAt
        self.agent = agent
        self.peerTeamID = peerTeamID
        self.action = action
    }

    public enum AccessSource: String, Sendable, Codable {
        case app, cli, mcp
    }

    public enum Action: String, Sendable, Codable {
        case read, created, updated, deleted, denied
    }
}

/// Narrows an activity-log query. Applied in SQL, not over an already-fetched
/// page, so a filter reaches entries older than the unfiltered listing shows.
public struct ActivityFilter: Sendable, Equatable {
    public var projectName: String?
    public var source: ActivityLogEntry.AccessSource?
    public var action: ActivityLogEntry.Action?
    /// Matched against the secret name, environment name, and agent token.
    public var search: String

    public init(
        projectName: String? = nil,
        source: ActivityLogEntry.AccessSource? = nil,
        action: ActivityLogEntry.Action? = nil,
        search: String = ""
    ) {
        self.projectName = projectName
        self.source = source
        self.action = action
        self.search = search
    }

    public var isEmpty: Bool {
        projectName == nil && source == nil && action == nil
            && search.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
