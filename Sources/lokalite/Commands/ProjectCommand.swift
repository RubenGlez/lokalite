import ArgumentParser
import Foundation
import LokaliteCore

struct ProjectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "project",
        abstract: "Manage projects.",
        subcommands: [Add.self, List.self, Use.self, Link.self, Delete.self]
    )

    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Create a new project.")

        @Argument(help: "Project name.")
        var name: String

        @Option(name: .long, help: "Link to a directory path.")
        var path: String?

        func run() throws {
            let project = try withVault { try $0.addProject(name: name, path: path) }
            print("Created project '\(project.name)'.")
            if let path = project.path { print("Linked to \(path).") }
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List all projects.")

        func run() throws {
            let activeId = try withVault { try $0.activeProjectId() }
            let projects = try withVault { try $0.listProjects() }
            if projects.isEmpty {
                print("No projects found.")
                return
            }
            for p in projects {
                let active = p.id == activeId ? " *" : ""
                var line = p.name + active
                if let path = p.path { line += "  \(path)" }
                if let env = p.activeEnvironment { line += "  [\(env)]" }
                print(line)
            }
        }
    }

    struct Use: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Set the active project.")

        @Argument(help: "Project name.")
        var name: String

        func run() throws {
            try withVault { vault in
                guard let project = try vault.project(name: name) else {
                    throw VaultError.projectNotFound(name)
                }
                try vault.setActiveProject(id: project.id)
            }
            print("Active project set to '\(name)'.")
        }
    }

    struct Link: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Link a project to a directory path.")

        @Argument(help: "Project name. Defaults to the current directory name.")
        var name: String?

        @Option(name: .long, help: "Directory path to link. Defaults to the current directory. Omit with --unlink to unlink.")
        var path: String?

        @Flag(name: .long, help: "Remove the directory link from the project.")
        var unlink = false

        func run() throws {
            let cwd = FileManager.default.currentDirectoryPath
            let projectName = name ?? URL(fileURLWithPath: cwd).lastPathComponent
            let linkPath: String? = unlink ? nil : (path ?? cwd)

            try withVault { vault in
                guard let project = try vault.project(name: projectName) else {
                    throw VaultError.projectNotFound(projectName)
                }
                try vault.linkProject(id: project.id, path: linkPath)
            }
            if let linkPath { print("Linked '\(projectName)' to \(linkPath).") }
            else { print("Unlinked '\(projectName)'.") }
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a project and all its secrets.")

        @Argument(help: "Project name.")
        var name: String

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt.")
        var force = false

        func run() throws {
            if !force {
                print("Delete empty project '\(name)'? This cannot be undone. [y/N] ",
                      terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            try withVault { vault in
                guard let project = try vault.project(name: name) else {
                    throw VaultError.projectNotFound(name)
                }
                try vault.deleteProject(id: project.id)
            }
            print("Deleted project '\(name)'.")
        }
    }
}
