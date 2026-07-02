import AppKit
import ArgumentParser
import CryptoKit
import Foundation
import LokaliteCore

struct CopyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "copy",
        abstract: "Copy a secret value to the clipboard."
    )

    @Argument(help: "Secret name.")
    var name: String

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        // Approval-tier secrets are brokered through the daemon (Touch ID for
        // every caller, ADR 0018); everything else stays in-process.
        let secret = try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            return try CLIReveal.secret(named: name, in: workspace, context: ctx)
        }
        try enforceAgentRevealPolicy(secret)
        copyToPasteboard(secret.value)
        try clearClipboardLater(value: secret.value)
        print("Copied \(name) to clipboard.")
    }

    private func copyToPasteboard(_ value: String) {
        // org.nspasteboard.ConcealedType tells clipboard managers not to record the value.
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, concealed], owner: nil)
        pasteboard.setString(value, forType: .string)
        pasteboard.setString("", forType: concealed)
    }

    private func clearClipboardLater(value: String) throws {
        // Only a SHA-256 digest goes into the script, so the secret never
        // appears in the detached process's argument list.
        let digest = SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let script = "sleep 30 && [ \"$(pbpaste | shasum -a 256 | cut -d' ' -f1)\" = \"\(digest)\" ] && pbcopy < /dev/null"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
    }
}
