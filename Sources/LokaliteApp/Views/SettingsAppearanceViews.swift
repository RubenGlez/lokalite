import SwiftUI
import LokaliteCore
import SymbolPicker

struct CategoryPill: View {
    let category: SecretCategory

    var body: some View {
        Label(category.label, systemImage: category.systemImage)
            .font(.system(size: 10, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(category.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            // Squared tag: capsules are reserved for environments (chips + row badges).
            .background(category.color.opacity(0.14), in: .rect(cornerRadius: 5))
    }
}

struct ProjectAppearanceView: View {
    let project: Project?
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String?
    @State private var path: String
    @State private var isShowingSymbolPicker = false

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _icon = State(initialValue: project?.icon)
        _path = State(initialValue: project?.path ?? "")
    }

    private var isCreating: Bool { project == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)

                    LabeledContent("Icon") {
                        Button {
                            isShowingSymbolPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: icon ?? "folder")
                                    .font(.system(size: 14))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .buttonStyle(SurfaceButtonStyle(height: 26, horizontalPadding: 8, cornerRadius: 6))
                        .accessibilityLabel("Choose project icon")
                    }
                }

                if !isCreating {
                    Section("Directory") {
                        HStack {
                            TextField("Path (optional)", text: $path)
                                .font(.system(size: 12, design: .monospaced))
                            Button {
                                pickDirectory()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(IconButtonStyle(size: 24))
                            .help("Choose folder")
                        }
                        if !path.isEmpty {
                            Button("Unlink") { path = "" }
                                .buttonStyle(LinkButtonStyle(tone: .danger))
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isCreating ? "New Project" : "Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Create" : "Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isCreating {
                            vault.addProject(name: trimmedName, icon: icon ?? "folder")
                        } else if let project {
                            if !trimmedName.isEmpty, trimmedName != project.name {
                                vault.renameProject(project, newName: trimmedName)
                            }
                            let updated = Project(
                                id: project.id,
                                name: trimmedName.isEmpty ? project.name : trimmedName,
                                path: project.path,
                                activeEnvironment: project.activeEnvironment,
                                icon: project.icon
                            )
                            vault.setProjectIcon(updated, icon: icon)
                            let newPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                            let pathChanged = newPath != (project.path ?? "")
                            if pathChanged {
                                vault.linkProject(updated, path: newPath.isEmpty ? nil : newPath)
                            }
                            vault.refresh()
                        }
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 420, height: isCreating ? 220 : 310)
        .sheet(isPresented: $isShowingSymbolPicker) {
            SymbolPicker(symbol: $icon)
        }
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Link"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}


struct EnvironmentAppearanceView: View {
    let environment: VaultEnvironment
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: String

    init(environment: VaultEnvironment) {
        self.environment = environment
        _name = State(initialValue: environment.name)
        _color = State(initialValue: environment.color ?? Theme.environmentPalette[0])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    ColorSwatches(selection: $color)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Environment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = environment
                        if trimmedName != environment.name {
                            vault.renameEnvironment(environment, newName: trimmedName)
                            updated = VaultEnvironment(id: environment.id, projectId: environment.projectId,
                                                       name: trimmedName, color: environment.color)
                        }
                        vault.setEnvironmentColor(updated, color: color)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .frame(width: 420, height: 230)
    }
}

struct ColorSwatches: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Theme.environmentPalette, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.color(hex: hex))
                        if selection == hex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                        }
                    }
                    .frame(width: 18, height: 18)
                }
                .buttonStyle(SwatchButtonStyle(isSelected: selection == hex))
                .help(hex)
                .accessibilityLabel("Use environment color \(hex)")
            }
        }
    }
}
