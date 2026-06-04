import ArgumentParser
import LokaliteCore

struct EnvCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "env",
        abstract: "Manage environments within a project.",
        subcommands: [Add.self, List.self, Use.self, Delete.self]
    )

    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Add an environment to a project.")

        @Argument(help: "Environment name (e.g. staging).")
        var name: String

        @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
        var project: String?

        func run() throws {
            let ctx = try resolveContext(projectFlag: project, envFlag: nil)
            try withVault { vault in
                _ = try vault.addEnvironment(name: name, projectId: ctx.project.id)
            }
            print("Added environment '\(name)' to project '\(ctx.project.name)'.")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List environments in a project.")

        @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
        var project: String?

        func run() throws {
            let ctx = try resolveContext(projectFlag: project, envFlag: nil)
            let envs = try withVault { try $0.listEnvironments(projectId: ctx.project.id) }
            if envs.isEmpty {
                print("No environments in '\(ctx.project.name)'.")
                return
            }
            for env in envs {
                let active = env.name == ctx.project.activeEnvironment ? " *" : ""
                print(env.name + active)
            }
        }
    }

    struct Use: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Set the active environment for a project.")

        @Argument(help: "Environment name.")
        var name: String

        @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
        var project: String?

        func run() throws {
            let ctx = try resolveContext(projectFlag: project, envFlag: nil)
            try withVault { vault in
                try vault.setActiveEnvironment(name: name, projectId: ctx.project.id)
            }
            print("Active environment set to '\(name)' in project '\(ctx.project.name)'.")
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete an environment and its secret values.")

        @Argument(help: "Environment name.")
        var name: String

        @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
        var project: String?

        @Flag(name: .shortAndLong, help: "Skip confirmation prompt.")
        var force = false

        func run() throws {
            let ctx = try resolveContext(projectFlag: project, envFlag: nil)
            try withVault { vault in
                let count = (try? vault.secretCount(projectId: ctx.project.id, environmentName: name)) ?? 0
                let isNonEmpty = count > 0

                if !force {
                    let prompt = isNonEmpty
                        ? "Environment '\(name)' contains secrets. Delete anyway? [y/N] "
                        : "Delete empty environment '\(name)' from '\(ctx.project.name)'? This cannot be undone. [y/N] "
                    print(prompt, terminator: "")
                    guard readLine()?.lowercased() == "y" else {
                        print("Cancelled.")
                        return
                    }
                }
                try vault.deleteEnvironmentIncludingContents(name: name, projectId: ctx.project.id)
            }
            print("Deleted environment '\(name)'.")
        }
    }
}
