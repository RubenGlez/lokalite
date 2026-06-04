import SwiftUI
import LokaliteCore
import SymbolPicker

// MARK: - Identity

struct IdentityBadge: View {
    let icon: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(8, size * 0.24))
                .fill(color.opacity(0.16))
            RoundedRectangle(cornerRadius: min(8, size * 0.24))
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
            Text(icon)
                .font(.system(size: size * 0.5))
        }
        .frame(width: size, height: size)
    }
}

struct CategoryPill: View {
    let category: SecretCategory

    var body: some View {
        Label(category.label, systemImage: category.systemImage)
            .font(.system(size: 10, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Theme.brand)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Theme.brand.opacity(0.12))
            )
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
                                    .font(.system(size: 16))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
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
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        if !path.isEmpty {
                            Button("Unlink") { path = "" }
                                .foregroundStyle(Theme.red)
                                .buttonStyle(.plain)
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
    @State private var color: String

    init(environment: VaultEnvironment) {
        self.environment = environment
        _color = State(initialValue: environment.color ?? Theme.environmentPalette[0])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(environment.name) {
                    HStack(spacing: 10) {
                        ForEach(Theme.environmentPalette, id: \.self) { hex in
                            Button {
                                color = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Theme.color(hex: hex))
                                    if color == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.7))
                                    }
                                }
                                .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .help(hex)
                            .accessibilityLabel("Use environment color \(hex)")
                        }
                    }
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
                        vault.setEnvironmentColor(environment, color: color)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 420, height: 190)
    }
}

struct EnvironmentManagerView: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var newColor = Theme.environmentPalette[0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Environments") {
                    if vault.environments.isEmpty {
                        Text("No custom environments")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vault.environments, id: \.id) { environment in
                            EnvironmentEditorRow(environment: environment)
                                .environment(vault)
                        }
                    }
                }

                Section("New Environment") {
                    HStack(spacing: 10) {
                        TextField("Name", text: $newName)
                        ColorSwatches(selection: $newColor)
                        Button {
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            vault.addEnvironment(name: trimmed, color: newColor)
                            newName = ""
                            newColor = Theme.environmentPalette[0]
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.plain)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("Add environment")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Environments")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 560, height: 420)
    }
}

struct EnvironmentEditorRow: View {
    let environment: VaultEnvironment
    @Environment(VaultViewModel.self) private var vault
    @State private var name: String
    @State private var color: String
    @State private var isDeleting = false

    init(environment: VaultEnvironment) {
        self.environment = environment
        _name = State(initialValue: environment.name)
        _color = State(initialValue: environment.color ?? Theme.environmentPalette[0])
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Name", text: $name)
            ColorSwatches(selection: $color)

            Button(role: .destructive) {
                isDeleting = true
                vault.deleteEnvironment(environment)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("Delete environment")
        }
        .onDisappear {
            if !isDeleting {
                save()
            }
        }
    }

    private var hasChanges: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines) != environment.name ||
            color != (environment.color ?? Theme.environmentPalette[0])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed != environment.name {
            vault.renameEnvironment(environment, newName: trimmed)
        }
        let updated = VaultEnvironment(id: environment.id, projectId: environment.projectId, name: trimmed, color: environment.color)
        vault.setEnvironmentColor(updated, color: color)
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
                                .foregroundStyle(.black.opacity(0.72))
                        }
                    }
                    .frame(width: 18, height: 18)
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(hex)
                .accessibilityLabel("Use environment color \(hex)")
            }
        }
    }
}

// MARK: - Sidebar Project Row

struct SidebarProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                let icon = project.icon ?? "folder"
                if icon.unicodeScalars.allSatisfy({ $0.value < 128 }) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                } else {
                    Text(icon)
                        .font(.system(size: 18))
                        .frame(width: 24, height: 24)
                }
                Text(project.name)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Menu {
                    Button("Edit\u{2026}", action: onEdit)
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(rowBackground)
        .clipShape(.rect(cornerRadius: 7))
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = h }
        }
        .contextMenu {
            Button("Edit\u{2026}", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return Color.white.opacity(0.10)
        }
        if isHovered {
            return Color.white.opacity(0.05)
        }
        return Color.clear
    }
}

// MARK: - Secret Row

struct SecretRow: View {
    let secret: Secret
    let isSelected: Bool
    let onEdit: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @Environment(VaultViewModel.self) private var vault

    var body: some View {
        HStack(spacing: 9) {
            IdentityBadge(icon: secret.category.defaultIcon, color: .white, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name)
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(secret.description?.isEmpty == false ? secret.description! : secret.category.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if isHovered {
                Menu {
                    Button("Copy") { vault.copyToClipboard(secret) }
                    Divider()
                    Button("Edit\u{2026}", action: onEdit)
                    Button("Move\u{2026}", action: onMove)
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(rowBackground)
        .clipShape(.rect(cornerRadius: 7))
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = h }
        }
        .contextMenu {
            Button("Copy") { vault.copyToClipboard(secret) }
            Divider()
            Button("Edit\u{2026}", action: onEdit)
            Button("Move\u{2026}", action: onMove)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return Color.white.opacity(0.10)
        }
        if isHovered {
            return Color.white.opacity(0.05)
        }
        return Color.clear
    }
}
