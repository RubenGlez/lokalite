import ArgumentParser
import Foundation
import LokaliteCore

struct CopyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "copy",
        abstract: "Copy a secret value to the clipboard."
    )

    @Argument(help: "Secret name.")
    var name: String

    func run() throws {
        let secret = try withVault { try $0.get(name: name) }
        try copyToPasteboard(secret.value)
        print("Copied \(name) to clipboard.")
    }

    private func copyToPasteboard(_ value: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe
        try process.run()
        pipe.fileHandleForWriting.write(Data(value.utf8))
        pipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
    }
}
