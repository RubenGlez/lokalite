import ArgumentParser
import Foundation
import LokaliteCore

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a project for the current directory, optionally importing a .env file."
    )

    @Argument(help: "Project name. Defaults to the directory name.")
    var name: String?

    @Option(name: .long, help: "Create the project from a .env file (or a folder containing one) and import its keys.")
    var fromEnv: String?

    @Option(name: .shortAndLong, help: "Target environment for the imported secrets. Defaults to Default.")
    var env: String?

    @Flag(name: .long, help: "Overwrite existing secrets instead of skipping them.")
    var overwrite = false

    func run() throws {
        if let fromEnv {
            try runFromEnv(fromEnv)
        } else {
            try runPlain()
        }
    }

    // MARK: - Plain init (current directory)

    private func runPlain() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let projectName = name ?? URL(fileURLWithPath: cwd).lastPathComponent

        let project = try withVault { vault -> Project in
            let project = try vault.addProject(name: projectName, path: cwd)
            try vault.setActiveProject(id: project.id)
            return project
        }

        print("Created project \"\(project.name)\" and linked it to \(cwd).")
        print("")
        print("Next steps:")
        print("  lokalite add SECRET_NAME value       # add your first secret")
        print("  lokalite import .env                 # or import an existing .env file")
        print("  lokalite run -- <command>            # run a command with secrets injected")
    }

    // MARK: - Init from a .env file

    private func runFromEnv(_ path: String) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            throw ValidationError("No file or folder at \(path).")
        }
        let url = URL(fileURLWithPath: path)
        let envURL = isDir.boolValue ? url.appendingPathComponent(".env") : url
        let projectDir = isDir.boolValue ? url : url.deletingLastPathComponent()

        guard fm.fileExists(atPath: envURL.path) else {
            throw ValidationError("No .env file found at \(envURL.path).")
        }

        let content = try String(contentsOf: envURL, encoding: .utf8)
        let pairs = EnvFileFormat.parse(content)
        guard !pairs.isEmpty else {
            throw ValidationError("No key=value pairs found in \(envURL.path).")
        }

        let projectName = name ?? projectDir.lastPathComponent

        let (project, targetEnv, summary) = try withVault { vault in
            try vault.createProjectFromEnv(name: projectName, environmentName: env ?? "Default",
                                           linkPath: projectDir.path, pairs: pairs, overwrite: overwrite)
        }

        print("Created project \"\(project.name)\" (environment \(targetEnv)) and linked it to \(projectDir.path).")
        print(importSummaryLine(summary))
    }
}
