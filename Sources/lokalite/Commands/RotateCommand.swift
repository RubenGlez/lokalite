import ArgumentParser
import Foundation
import LokaliteCore

/// Guided secret rotation (ROADMAP, P1): replace a secret's value with a new one
/// you supply or generate, then a reminder to revoke the old credential upstream.
/// The current value is never printed.
struct RotateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rotate",
        abstract: "Rotate a secret's value (supply a new one or generate it).",
        discussion: """
        Replaces a secret's value with one you supply (argument, stdin, or hidden
        prompt) or a strong random value (--generate), then reminds you to revoke
        the previous credential with its provider. The old value is never printed.
        """
    )

    @Argument(help: "Secret name.")
    var name: String

    @Argument(help: "New value. Omit or pass '-' to read from stdin. Ignored with --generate.")
    var value: String?

    @Flag(name: .long, help: "Generate a strong random value instead of supplying one.")
    var generate = false

    @Option(name: .long, help: "Length of the generated value (with --generate).")
    var length: Int = SecretGenerator.defaultLength

    @Flag(name: .long, help: "Print the new value to stdout (needed to update the provider). Refused when an AI agent is detected unless --allow-agent.")
    var show = false

    @Flag(name: .long, help: "Allow --show even when an AI agent is detected in the calling process tree.")
    var allowAgent = false

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let newValue: String
        if generate {
            guard length >= 8 else {
                print("Generated length must be at least 8.")
                throw ExitCode.failure
            }
            newValue = try SecretGenerator.generate(length: length)
        } else {
            newValue = try resolveSecretValue(value)
        }

        try withWorkspace { workspace in
            let ctx = try resolveContext(projectFlag: project, envFlag: env, using: workspace)
            // Confirm the secret exists first; the old value is fetched but never printed.
            _ = try workspace.get(name: name, context: ctx)
            _ = try workspace.set(name: name, value: newValue, context: ctx, accessSource: .cli)
            print("Rotated \(name) in \(ctx.project.name)/\(ctx.displayEnvironmentName).")

            if generate {
                if show {
                    if !allowAgent, let agent = AgentDetection.detectAgent() {
                        print("Not printing the new value: AI agent (\(agent)) detected. Re-run with --allow-agent to override.")
                    } else {
                        print(newValue)
                    }
                } else {
                    print("Re-run with --show to print the new value (needed to update the provider).")
                }
            }
            print("Remember to revoke the previous credential with its provider.")
        }
    }
}
