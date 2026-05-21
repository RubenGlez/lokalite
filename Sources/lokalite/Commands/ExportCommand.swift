import ArgumentParser
import Foundation
import LokaliteCore

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export secrets. Encrypted by default."
    )

    @Option(name: .shortAndLong, help: "Output file path. Defaults to stdout.")
    var output: String?

    @Flag(help: "Export as plaintext JSON. Requires confirmation.")
    var plain: Bool = false

    func run() throws {
        let data: Data

        if plain {
            print("Warning: plain export writes secret values unencrypted.")
            print("Type 'yes' to confirm: ", terminator: "")
            let input = readLine() ?? ""
            guard input == "yes" else {
                print("Cancelled.")
                return
            }
            data = try withVault { try $0.export(passphrase: nil) }
        } else {
            print("Enter passphrase for encrypted export: ", terminator: "")
            let passphrase = readPassphrase()
            guard !passphrase.isEmpty else {
                print("Passphrase cannot be empty.")
                return
            }
            data = try withVault { try $0.export(passphrase: passphrase) }
        }

        if let outputPath = output {
            let url = URL(fileURLWithPath: outputPath)
            try data.write(to: url)
            print("Exported to \(outputPath).")
        } else {
            if plain {
                print(String(data: data, encoding: .utf8) ?? "")
            } else {
                print(data.base64EncodedString())
            }
        }
    }

    private func readPassphrase() -> String {
        // Disable echo for passphrase input.
        var term = termios()
        tcgetattr(STDIN_FILENO, &term)
        var noEcho = term
        noEcho.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &noEcho)
        let passphrase = readLine() ?? ""
        tcsetattr(STDIN_FILENO, TCSANOW, &term)
        print()
        return passphrase
    }
}
