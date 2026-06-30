import Foundation

/// Whether AI agents may read a secret (ADR 0014 governance).
///
/// Modeled as a string-backed enum, not a bool, on purpose: adding richer tiers
/// later (e.g. `.requiresApproval`, `.strict`) is then purely additive — new
/// cases plus enforcement code — with no schema migration and no data backfill,
/// since existing rows already store a string. Stored in `secrets.agent_access`.
public enum AgentAccessPolicy: String, Codable, Equatable, Sendable {
    /// Agents may retrieve the value (the default).
    case allowed
    /// Agents are refused; the value is never handed off via MCP.
    case blocked

    /// True if an agent caller must be refused.
    public var blocksAgents: Bool { self == .blocked }
}
