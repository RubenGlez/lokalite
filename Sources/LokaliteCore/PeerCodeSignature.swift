import Foundation
#if canImport(Security)
import Security
#endif

/// The result of verifying a socket peer's Developer ID code signature (ADR 0019).
///
/// Attribution only: the daemon records this against a brokered access; it never
/// gates the read (enforcement never rides detection — ADR 0018). The connecting
/// peer is always some `lokalite` invocation, so this confirms the *binary* is the
/// genuine signed one — it does not classify agent vs. human (that stays with
/// `AgentDetection`).
public struct PeerCodeSignature: Equatable, Sendable, Codable {
    public enum Status: String, Sendable, Codable {
        /// Validly signed by the expected Developer ID team.
        case verified
        /// Validly signed, but by a different team.
        case mismatch
        /// No valid code signature (ad-hoc, unsigned, or broken).
        case unsigned
        /// Could not be determined — no `SecCode` for the pid, or an API failure.
        case unavailable
    }

    public let status: Status
    /// The signing team identifier (leaf OU), when readable (e.g. `67S22M7P3P`).
    public let teamID: String?
    /// The code-signing identifier (e.g. `lokalite`), when readable.
    public let identifier: String?

    public init(status: Status, teamID: String? = nil, identifier: String? = nil) {
        self.status = status
        self.teamID = teamID
        self.identifier = identifier
    }

    public var isVerified: Bool { status == .verified }

    /// The team id to record for attribution — only when actually verified, so a
    /// mismatched/unsigned peer never leaves a team stamp that reads as trusted.
    public var verifiedTeamID: String? { isVerified ? teamID : nil }
}

#if canImport(Security)
/// Verifies a socket peer's code signature via the Security framework (ADR 0019).
public enum PeerCodeVerifier {
    /// Lokalite's account-wide Developer ID team (ADR 0011/0019).
    public static let lokaliteTeamID = "67S22M7P3P"

    /// Verifies process `pid`'s code signature against `teamID` (a Developer ID
    /// leaf OU under Apple's anchor). Pure and side-effect-free; safe off the main
    /// thread. Returns `.unavailable` when the OS won't hand back a `SecCode` for
    /// the pid (e.g. a bad or reused pid). Never throws.
    public static func verify(pid: pid_t, teamID: String = lokaliteTeamID) -> PeerCodeSignature {
        let attrs = [kSecGuestAttributePid: NSNumber(value: pid)] as CFDictionary
        var codeOpt: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &codeOpt) == errSecSuccess,
              let code = codeOpt else {
            return PeerCodeSignature(status: .unavailable)
        }

        let (signingTeam, signingID) = readSigningIdentity(code)

        guard let requirement = developerIDRequirement(teamID: teamID) else {
            return PeerCodeSignature(status: .unavailable, teamID: signingTeam, identifier: signingID)
        }
        if SecCodeCheckValidity(code, [], requirement) == errSecSuccess {
            return PeerCodeSignature(status: .verified, teamID: signingTeam ?? teamID, identifier: signingID)
        }
        // Distinguish "validly signed, wrong team" from "no valid signature".
        let anyValid = SecCodeCheckValidity(code, [], nil) == errSecSuccess
        return PeerCodeSignature(status: anyValid ? .mismatch : .unsigned,
                                 teamID: signingTeam, identifier: signingID)
    }

    /// Builds the Developer ID designated requirement for `teamID`. Exposed for
    /// tests (it compiles without any signed peer).
    public static func developerIDRequirement(teamID: String) -> SecRequirement? {
        let text = "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess else {
            return nil
        }
        return requirement
    }

    private static func readSigningIdentity(_ code: SecCode) -> (team: String?, id: String?) {
        var staticOpt: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticOpt) == errSecSuccess,
              let staticCode = staticOpt else {
            return (nil, nil)
        }
        var infoOpt: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &infoOpt) == errSecSuccess,
              let info = infoOpt as? [String: Any] else {
            return (nil, nil)
        }
        return (info[kSecCodeInfoTeamIdentifier as String] as? String,
                info[kSecCodeInfoIdentifier as String] as? String)
    }
}
#endif
