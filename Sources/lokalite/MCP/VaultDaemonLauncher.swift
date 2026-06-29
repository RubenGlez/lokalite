import Foundation
import LokaliteCore

/// Ensures the menu-bar app (the vault daemon, ADR 0014) is running before the
/// CLI/MCP connect as a client, auto-launching it if needed.
enum VaultDaemonLauncher {
    /// Returns once the daemon answers on `socketPath`, launching the app and
    /// polling up to `timeout`. Throws `VaultSocketError.notRunning` if it never
    /// comes up (the caller can fall back to `--local`).
    static func ensureRunning(socketPath: String, timeout: TimeInterval = 6) throws {
        if isAnswering(socketPath) { return }
        launchApp()

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            usleep(150_000)
            if isAnswering(socketPath) { return }
        }
        throw VaultSocketError.notRunning
    }

    /// A successful round-trip (even an error response) means the daemon is up.
    /// `listProjects` needs no unlocked key, so it works as a liveness ping.
    private static func isAnswering(_ socketPath: String) -> Bool {
        (try? VaultSocketClient(socketPath: socketPath).send(.listProjects)) != nil
    }

    private static func launchApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Lokalite"]
        try? process.run()
        process.waitUntilExit()
    }
}
