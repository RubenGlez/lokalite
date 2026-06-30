import Foundation

/// Whether AI agents may read a secret (ADR 0014 governance).
///
/// Modeled as a string-backed enum, not a bool, on purpose: adding richer tiers
/// (e.g. the `.requiresApproval` consent-on-read tier, or a future `.strict`) is
/// purely additive — new cases plus enforcement code — with no schema migration
/// and no data backfill, since existing rows already store a string. Stored in
/// `secrets.agent_access`.
public enum AgentAccessPolicy: String, Codable, Equatable, Sendable {
    /// Agents may retrieve the value (the default).
    case allowed
    /// Agents are refused; the value is never handed off via MCP.
    case blocked
    /// Agents may retrieve the value only after a per-read consent prompt
    /// (Touch ID) brokered by the daemon. Fails closed where no GUI can prompt.
    case requiresApproval

    /// True if an agent caller must be refused outright.
    public var blocksAgents: Bool { self == .blocked }

    /// True if an agent caller must obtain consent before the value is released.
    public var requiresApprovalForAgents: Bool { self == .requiresApproval }
}
