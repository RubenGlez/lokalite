import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Detects whether an AI coding agent is in the caller's process tree (ADR 0014).
/// Used to refuse bulk secret-reveal paths (`lokalite shell` / `export`) when a
/// human isn't the one asking — the agent should inject with `lokalite run` or
/// use the MCP handoff instead, never read raw values.
public enum AgentDetection {
    /// Substrings matched (case-insensitively) against process names. Kept narrow
    /// to avoid false positives — e.g. no bare "code", which would match
    /// `xcodebuild`.
    static let signatures = ["claude", "cursor", "windsurf", "codex", "copilot"]

    private static let maxHops = 20

    /// The matched agent token if `processName` looks like a known agent, else nil.
    public static func matchedAgent(processName: String) -> String? {
        let lowered = processName.lowercased()
        return signatures.first { lowered.contains($0) }
    }

    /// Walks up the process tree from `pid` (default: this process) toward
    /// `launchd`, returning the first detected agent token, or nil.
    ///
    /// Each hop is matched against both the kernel process name (`p_comm`,
    /// truncated to 16 chars) and the executable path: launchers like Claude
    /// Code exec a version-numbered binary (p_comm `2.1.198`) that only the
    /// path (`…/claude/versions/2.1.198`) identifies.
    public static func detectAgent(startingFrom pid: pid_t = getpid()) -> String? {
        var current = pid
        var hops = 0
        while current > 1, hops < maxHops {
            guard let info = processInfo(pid: current) else { break }
            if let agent = matchedAgent(processName: info.name) { return agent }
            if let path = executablePath(pid: current), let agent = matchedAgent(processName: path) {
                return agent
            }
            guard info.parentPID > 0, info.parentPID != current else { break }
            current = info.parentPID
            hops += 1
        }
        return nil
    }

    private static func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : nil
    }

    private static func processInfo(pid: pid_t) -> (name: String, parentPID: pid_t)? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0, size > 0 else { return nil }

        let name = withUnsafePointer(to: info.kp_proc.p_comm) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: info.kp_proc.p_comm)) {
                String(cString: $0)
            }
        }
        return (name, info.kp_eproc.e_ppid)
    }
}
