import ArgumentParser
import Foundation
import LokaliteCore

struct ImportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import secrets from a .env file."
    )

    @Argument(help: "Path to .env file.")
    var file: String

    @Flag(name: .long, help: "Overwrite existing secrets instead of skipping them.")
    var overwrite = false

    @Option(name: .shortAndLong, help: "Project name. Defaults to the active project.")
    var project: String?

    @Option(name: .shortAndLong, help: "Environment name. Defaults to the active environment.")
    var env: String?

    func run() throws {
        let ctx = try resolveContext(projectFlag: project, envFlag: env)
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let pairs = parseEnvFile(content)

        guard !pairs.isEmpty else {
            print("No key=value pairs found in \(file).")
            return
        }

        var added = 0, updated = 0, skipped = 0

        try withVault { vault in
            for (key, value) in pairs {
                do {
                    _ = try vault.add(name: key, value: value,
                                      projectId: ctx.project.id,
                                      environmentName: ctx.environmentName)
                    added += 1
                } catch VaultError.secretAlreadyExists {
                    if overwrite {
                        _ = try vault.set(name: key, value: value,
                                          projectId: ctx.project.id,
                                          environmentName: ctx.environmentName)
                        updated += 1
                    } else {
                        skipped += 1
                    }
                }
            }
        }

        var parts: [String] = []
        if added > 0   { parts.append("\(added) added") }
        if updated > 0 { parts.append("\(updated) updated") }
        if skipped > 0 { parts.append("\(skipped) skipped (already exist — use --overwrite to replace)") }
        print(parts.joined(separator: ", ") + ".")
    }
}

private func parseEnvFile(_ content: String) -> [(String, String)] {
    var result: [(String, String)] = []
    for rawLine in content.components(separatedBy: .newlines) {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !line.hasPrefix("#") else { continue }
        if line.hasPrefix("export ") {
            line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard let eqIdx = line.firstIndex(of: "=") else { continue }
        let key = String(line[line.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { continue }
        var value = String(line[line.index(after: eqIdx)...])
        if (value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2) ||
           (value.hasPrefix("'")  && value.hasSuffix("'")  && value.count >= 2) {
            value = String(value.dropFirst().dropLast())
        } else if let commentRange = value.range(of: " #") {
            value = String(value[value.startIndex..<commentRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }
        result.append((key, value))
    }
    return result
}
