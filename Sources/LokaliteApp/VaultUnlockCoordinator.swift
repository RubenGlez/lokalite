import Foundation
import LocalAuthentication
import LokaliteCore

/// Brokers a vault unlock for daemon callers (the CLI and MCP over the socket).
/// Lives in the app for the same reason as `AgentApprovalCoordinator`: only the
/// app — the daemon and sole vault owner — has the GUI context for Touch ID.
/// Blocks the calling socket thread until the user responds. Prompts are
/// serialized on a queue so concurrent requests against a locked vault coalesce
/// into one dialog: whoever waits behind the prompt re-checks the lock state and
/// rides the first caller's grant instead of stacking prompts.
final class VaultUnlockCoordinator {
    private let queue = DispatchQueue(label: "com.lokalite.daemon.unlock")

    /// Called by the daemon dispatcher while it holds no vault lock (M3).
    /// Returns true only once the vault is unlocked.
    func requestUnlock(agent: String?) -> Bool {
        queue.sync {
            if !Vault.shared.isLocked { return true }
            guard promptTouchID(agent: agent) else { return false }
            do {
                try Vault.shared.unlock()
            } catch {
                return false
            }
            NotificationCenter.default.post(name: .vaultDidUnlockExternally, object: nil)
            return true
        }
    }

    private func promptTouchID(agent: String?) -> Bool {
        let context = LAContext()
        var policyError: NSError?
        // No biometric and no device passcode → no way to obtain consent → deny.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return false
        }
        // A nil agent means the human CLI (ADR 0018): unlock prompts for every
        // caller, and detection only supplies the agent label.
        let who = agent.map { "“\($0)”" } ?? "the lokalite CLI"
        let reason = "unlock the Lokalite vault for \(who)"
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
    /// Posted after a daemon-brokered unlock so the UI adopts the unlocked state
    /// and starts the auto-lock session timer.
    static let vaultDidUnlockExternally = Notification.Name("vaultDidUnlockExternally")
}
