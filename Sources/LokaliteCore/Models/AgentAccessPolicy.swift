import Foundation

/// Whether AI agents may read a secret (ADR 0014 governance).
///
/// Modeled as a string-backed enum, not a bool, on purpose: adding richer tiers
/// (the `.requiresApproval` consent-on-read tier, then `.strict`) is purely
/// additive — new cases plus enforcement code — with no schema migration and no
/// data backfill, since existing rows already store a string. Stored in
/// `secrets.agent_access`.
public enum AgentAccessPolicy: String, Codable, Equatable, Sendable {
    /// Agents may retrieve the value (the default).
    case allowed
    /// Agents are refused; the value is never handed off via MCP.
    case blocked
    /// Agents may retrieve the value only after a consent prompt (Touch ID)
    /// brokered by the daemon; a successful approval grants that secret for the
    /// rest of the unlock session. Fails closed where no GUI can prompt.
    case requiresApproval
    /// Like `requiresApproval`, but the approval is never cached: agents are
    /// prompted on EVERY read. Fails closed where no GUI can prompt.
    case strict

    /// True if an agent caller must be refused outright.
    public var blocksAgents: Bool { self == .blocked }

    /// True if an agent caller must obtain consent before the value is released.
    public var requiresApprovalForAgents: Bool { self == .requiresApproval || self == .strict }

    /// True if consent must be obtained on every read (never cached for the session).
    public var promptsPerCall: Bool { self == .strict }
}
