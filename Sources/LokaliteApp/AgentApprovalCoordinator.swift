import Foundation
import LocalAuthentication
import LokaliteCore

/// Brokers consent-on-read for approval-tier secrets (ADR 0014). Lives in the
/// app because only the app — the daemon and sole vault owner — has the GUI context
/// for Touch ID. For `requiresApproval` a successful approval grants that secret for
/// the rest of the unlock session (keyed by secret id); grants clear when the vault
/// locks. A `strict` (per-call) request bypasses the grant cache — the cache is
/// neither read nor written, so every read re-prompts.
final class AgentApprovalCoordinator {
    private let grants = ApprovalGrantCache()
    private var lockObserver: NSObjectProtocol?

    init() {
        lockObserver = NotificationCenter.default.addObserver(
            forName: .vaultDidLock, object: nil, queue: nil
        ) { [weak self] _ in self?.grants.clear() }
    }

    deinit {
        if let lockObserver { NotificationCenter.default.removeObserver(lockObserver) }
    }

    /// Called by the daemon dispatcher on its serial queue. Blocks until the user
    /// responds to Touch ID. A cached session grant short-circuits the prompt
    /// (never for a per-call request — `ApprovalGrantCache` bypasses those).
    func approve(_ request: ApprovalRequest) -> Bool {
        if grants.isGranted(request) { return true }
        guard promptTouchID(for: request) else { return false }
        grants.recordGrant(request)
        return true
    }

    private func promptTouchID(for request: ApprovalRequest) -> Bool {
        let context = LAContext()
        var policyError: NSError?
        // No biometric and no device passcode → no way to obtain consent → deny.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return false
        }
        // A nil agent means the human CLI (ADR 0018): approval tiers prompt for
        // every caller, and detection only supplies the agent label.
        let who = request.agent.map { "“\($0)”" } ?? "the lokalite CLI"
        let reason = "release \(request.secretName) (\(request.environmentName)) in project \(request.projectName) to \(who)"
        let semaphore = DispatchSemaphore(value: 0)
        var approved = false
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            approved = success
            semaphore.signal()
        }
        semaphore.wait()
        return approved
    }
}

extension Notification.Name {
    /// Posted by `VaultViewModel.lock()` so session-scoped state (agent-access
    /// grants) clears when the vault locks or the session times out.
    static let vaultDidLock = Notification.Name("vaultDidLock")
}
