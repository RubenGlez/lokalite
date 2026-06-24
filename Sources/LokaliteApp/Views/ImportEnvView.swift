import AppKit
import SwiftUI
import LokaliteCore

/// What an `ImportEnvView` should do: create a new project from the `.env`, or
/// import it into an existing project. Carries the parsed file so the sheet can
/// show a key preview without re-reading disk.
struct ImportEnvRequest: Identifiable {
    enum Mode {
        case createProject
        case existingProject(Project)
    }

    let id = UUID().uuidString
    let mode: Mode
    let envURL: URL
    let suggestedProjectName: String
    let suggestedLinkPath: String
    let pairs: [(name: String, value: String)]
}

private struct ImportKey: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    var include: Bool
}

/// Guided `.env` import form. In create mode it collects a project name, target
/// environment, and linked directory; in existing mode it picks the target
/// environment from the project's existing ones. Both let the user prune keys.
struct ImportEnvView: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss

    let request: ImportEnvRequest

    @State private var projectName: String
    @State private var environmentName: String
    @State private var linkPath: String
    @State private var overwrite = false
    @State private var keys: [ImportKey]

    init(request: ImportEnvRequest) {
        self.request = request
        _projectName = State(initialValue: request.suggestedProjectName)
        _linkPath = State(initialValue: request.suggestedLinkPath)
        _keys = State(initialValue: request.pairs.map {
            ImportKey(name: $0.name, value: $0.value, include: true)
        })
        switch request.mode {
        case .createProject:
            _environmentName = State(initialValue: "Default")
        case .existingProject(let project):
            _environmentName = State(initialValue: project.activeEnvironment ?? "Default")
        }
    }

    private var isCreate: Bool {
        if case .createProject = request.mode { return true }
        return false
    }

    private var selectedCount: Int { keys.filter(\.include).count }

    private var canImport: Bool {
        selectedCount > 0 && (!isCreate || !projectName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isCreate ? "Import .env — new project" : "Import .env")
                    .font(.headline)
                Text(request.envURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if isCreate {
                LabeledField("Project name") { TextField("", text: $projectName) }
                LabeledField("Environment") { TextField("", text: $environmentName) }
                LabeledField("Linked directory") { TextField("Optional", text: $linkPath) }
            } else {
                LabeledField("Environment") {
                    Picker("", selection: $environmentName) {
                        ForEach(vault.environments, id: \.name) { env in
                            Text(env.name).tag(env.name)
                        }
                    }
                    .labelsHidden()
                }
            }

            Toggle("Overwrite existing secrets", isOn: $overwrite)

            Divider()

            HStack {
                Text("Keys")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(selectedCount) of \(keys.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach($keys) { $key in
                    Toggle(isOn: $key.include) {
                        Text(key.name).font(.system(.body, design: .monospaced))
                    }
                }
            }
            .frame(height: 200)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Import") { performImport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canImport)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func performImport() {
        let chosen = keys.filter(\.include).map { (name: $0.name, value: $0.value) }
        guard !chosen.isEmpty else { return }
        let env = environmentName.trimmingCharacters(in: .whitespaces)
        let target = env.isEmpty ? "Default" : env

        let summary: ImportSummary?
        switch request.mode {
        case .createProject:
            let link = linkPath.trimmingCharacters(in: .whitespaces)
            summary = vault.createProjectFromEnv(
                name: projectName.trimmingCharacters(in: .whitespaces),
                environmentName: target,
                linkPath: link.isEmpty ? nil : link,
                pairs: chosen,
                overwrite: overwrite
            )
        case .existingProject(let project):
            summary = vault.importEnv(
                pairs: chosen,
                projectId: project.id,
                environmentName: target,
                overwrite: overwrite
            )
        }

        if summary != nil { dismiss() }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 120, alignment: .leading)
                .foregroundStyle(.secondary)
            content
        }
    }
}
