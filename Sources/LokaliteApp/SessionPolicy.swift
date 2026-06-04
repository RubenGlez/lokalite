import Foundation

@MainActor
final class SessionPolicy {
    private var lockTimer: Timer?

    func renew(timeout: Double, onExpire: @escaping @MainActor () -> Void) {
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            Task { @MainActor in onExpire() }
        }
    }

    func cancel() {
        lockTimer?.invalidate()
        lockTimer = nil
    }
}
