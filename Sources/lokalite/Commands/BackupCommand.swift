import ArgumentParser
import Foundation
import LokaliteCore

struct BackupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backup",
        abstract: "Create an encrypted backup of the vault.",
        discussion: """
        Writes a passphrase-encrypted backup of a project's active environment. \
        The backup is always encrypted; restore it with `lokalite restore`. Scope \
        is limited to a single project's active environment — switch environments \
        with `lokalite env use` or back up other projects separately with --project.
        """
    )

    @Option(name: .shortAndLong, help: "Output file path. Defaults to a timestamped file in the current directory.")
    var output: String?

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: nil)

        print("Enter passphrase to encrypt the backup: ", terminator: "")
        let passphrase = readPassphrase()
        guard !passphrase.isEmpty else {
            print("Passphrase cannot be empty.")
            throw ExitCode.failure
        }

        let data = try withVault { try $0.export(projectId: ctx.project.id, passphrase: passphrase) }

        let outputPath = output ?? defaultBackupPath()
        try data.write(to: URL(fileURLWithPath: outputPath))
        print("Encrypted backup of project '\(ctx.project.name)' written to \(outputPath).")
    }

    private func defaultBackupPath() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let dir = FileManager.default.currentDirectoryPath
        return (dir as NSString).appendingPathComponent("lokalite-backup-\(stamp).lokalite")
    }

    private func readPassphrase() -> String {
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
