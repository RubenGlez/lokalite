import Foundation
import LocalAuthentication
import LokaliteCore

/// Brokers consent-on-read for `requiresApproval` secrets (ADR 0014). Lives in the
/// app because only the app — the daemon and sole vault owner — has the GUI context
/// for Touch ID. A successful approval grants that secret for the rest of the unlock
/// session (keyed by secret id); grants clear when the vault locks.
final class AgentApprovalCoordinator {
    private let lock = NSLock()
    private var grantedSecretIDs: Set<String> = []
    private var lockObserver: NSObjectProtocol?

    init() {
        lockObserver = NotificationCenter.default.addObserver(
            forName: .vaultDidLock, object: nil, queue: nil
        ) { [weak self] _ in self?.clearGrants() }
    }

    deinit {
        if let lockObserver { NotificationCenter.default.removeObserver(lockObserver) }
    }

    /// Called by the daemon dispatcher on its serial queue. Blocks until the user
    /// responds to Touch ID. A cached session grant short-circuits the prompt.
    func approve(_ request: ApprovalRequest) -> Bool {
        if isGranted(request.secretID) { return true }
        guard promptTouchID(for: request) else { return false }
        recordGrant(request.secretID)
        return true
    }

    private func isGranted(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return grantedSecretIDs.contains(id)
    }

    private func recordGrant(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        grantedSecretIDs.insert(id)
    }

    private func clearGrants() {
        lock.lock(); defer { lock.unlock() }
        grantedSecretIDs.removeAll()
    }

    private func promptTouchID(for request: ApprovalRequest) -> Bool {
        let context = LAContext()
        var policyError: NSError?
        // No biometric and no device passcode → no way to obtain consent → deny.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return false
        }
        let who = request.agent.map { "“\($0)”" } ?? "an AI agent"
        let reason = "release \(request.secretName) to \(who)"
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
