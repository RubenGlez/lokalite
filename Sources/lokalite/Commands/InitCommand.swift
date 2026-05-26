import ArgumentParser
import Foundation
import LokaliteCore

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a project for the current directory."
    )

    func run() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let dirName = URL(fileURLWithPath: cwd).lastPathComponent

        let project = try withVault { vault in
            try vault.addProject(name: dirName, path: cwd)
        }

        try withVault { vault in
            try vault.setActiveProject(id: project.id)
        }

        print("Created project \"\(project.name)\" and linked it to \(cwd).")
        print("")
        print("Next steps:")
        print("  lokalite add SECRET_NAME value       # add your first secret")
        print("  lokalite import .env                 # or import an existing .env file")
        print("  lokalite run -- <command>            # run a command with secrets injected")
    }
}
