import AppKit
import SwiftUI
import LokaliteCore
import SymbolPicker

// MARK: - Identifiable

extension Secret: Identifiable {}
extension Project: Identifiable {}
extension VaultEnvironment: Identifiable {}

// MARK: - Theme

enum Theme {
    static let gold       = Color(red: 0.910, green: 0.627, blue: 0.118)
    static let goldSubtle = Color(red: 0.910, green: 0.627, blue: 0.118).opacity(0.15)
    static let neutralSubtle = Color.white.opacity(0.08)
    static let sep        = Color.white.opacity(0.08)
    static let text       = Color(red: 0.929, green: 0.929, blue: 0.941)
    static let textMuted  = Color(red: 0.565, green: 0.565, blue: 0.612)
    static let textDim    = Color(red: 0.341, green: 0.341, blue: 0.376)
    static let bgHigh     = Color.white.opacity(0.06)
    static let red        = Color(red: 0.965, green: 0.369, blue: 0.369)
    static let green      = Color(red: 0.302, green: 0.847, blue: 0.569)
    static let blue       = Color(red: 0.341, green: 0.635, blue: 1.000)
    static let mint       = Color(red: 0.318, green: 0.859, blue: 0.757)
    static let violet     = Color(red: 0.659, green: 0.522, blue: 1.000)
    static let pink       = Color(red: 1.000, green: 0.455, blue: 0.647)
    static let orange     = Color(red: 1.000, green: 0.604, blue: 0.286)

    static let environmentPalette = ["#E8A01E", "#57A2FF", "#51DBC1", "#A885FF", "#FF749F", "#FF9A49", "#4CD964"]

    static func envCircle(_ color: Color) -> Image {
        let size: CGFloat = 10
        let nsImage = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor(color).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        nsImage.isTemplate = false
        return Image(nsImage: nsImage)
    }

    static func color(hex: String?) -> Color {
        guard let hex else { return gold }
        switch hex {
        case "#57A2FF": return blue
        case "#51DBC1": return mint
        case "#A885FF": return violet
        case "#FF749F": return pink
        case "#FF9A49": return orange
        case "#4CD964": return green
        default: return gold
        }
    }
}


private extension View {
    func toolbarSearch(text: Binding<String>, isPresented: Binding<Bool>) -> some View {
        searchable(
            text: text,
            isPresented: isPresented,
            placement: .toolbar,
            prompt: "Filter secrets"
        )
    }
}

// MARK: - Root

struct SettingsView: View {
    @Environment(VaultViewModel.self) private var vault
    @State private var selectedSecret: Secret?

    private enum PresentedSheet: Identifiable {
        case addSecret
        case appSettings
        case environmentManager
        case editSecret(Secret)
        case moveSecret(Secret)
        case projectAppearance(Project?)
        case environmentAppearance(VaultEnvironment)

        var id: String {
            switch self {
            case .addSecret: "add-secret"
            case .appSettings: "app-settings"
            case .environmentManager: "environment-manager"
            case .editSecret(let secret): "edit-secret-\(secret.id)"
            case .moveSecret(let secret): "move-secret-\(secret.id)"
            case .projectAppearance(let project): "project-\(project?.id ?? "new")"
            case .environmentAppearance(let environment): "environment-\(environment.id)"
            }
        }
    }

    // Presentation
    @State private var presentedSheet: PresentedSheet?
    @State private var showingAddEnv = false

    // Search
    @State private var searchExpanded = false

    // Delete confirmations
    @State private var deletingProject: Project?
    @State private var deletingEnv: VaultEnvironment?
    @State private var deletingSecret: Secret?

    // Inline input
    @State private var newEnvName = ""
    @State private var searchText = ""

    private var filteredSecrets: [Secret] {
        guard !searchText.isEmpty else { return vault.secrets }
        let q = searchText.lowercased()
        return vault.secrets.filter {
            $0.name.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            $0.category.label.lowercased().contains(q)
        }
    }

    private var selectedProjectTitle: String {
        vault.selectedProject?.name ?? "Lokalite"
    }

    private var selectedProjectSubtitle: String {
        guard vault.selectedProject != nil else { return "" }
        let n = vault.secrets.count
        return "\(n) secret\(n == 1 ? "" : "s")"
    }

    private var projectSelection: Binding<String?> {
        Binding(
            get: { vault.selectedProject?.id },
            set: { id in
                guard let id else {
                    vault.selectProject(nil)
                    return
                }
                vault.selectProject(vault.projects.first { $0.id == id })
            }
        )
    }

    private var secretSelection: Binding<String?> {
        Binding(
            get: { selectedSecret?.id },
            set: { id in
                selectedSecret = id.flatMap { selectedId in
                    filteredSecrets.first { $0.id == selectedId }
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .onAppear {
            if vault.isLocked { vault.unlock() }
        }
        .onChange(of: vault.secrets) { _, newSecrets in
            if let selected = selectedSecret {
                selectedSecret = newSecrets.first { $0.id == selected.id }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addSecret:
                AddSecretView().environment(vault)
            case .appSettings:
                AppSettingsView().environment(vault)
            case .environmentManager:
                EnvironmentManagerView().environment(vault)
            case .editSecret(let secret):
                EditSecretView(secret: secret).environment(vault)
            case .moveSecret(let secret):
                MoveSecretView(secret: secret).environment(vault)
            case .projectAppearance(let project):
                ProjectAppearanceView(project: project).environment(vault)
            case .environmentAppearance(let environment):
                EnvironmentAppearanceView(environment: environment).environment(vault)
            }
        }
        .alert("New Environment", isPresented: $showingAddEnv) {
            TextField("Name (e.g. staging)", text: $newEnvName)
            Button("Create") {
                guard !newEnvName.isEmpty else { return }
                vault.addEnvironment(name: newEnvName)
                newEnvName = ""
            }
            Button("Cancel", role: .cancel) { newEnvName = "" }
        }
        .confirmationDialog(
            "Delete \"\(deletingProject?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingProject != nil },
                set: { if !$0 { deletingProject = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = deletingProject { vault.deleteProject(p) }
                deletingProject = nil
            }
            Button("Cancel", role: .cancel) { deletingProject = nil }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog(
            "Delete \"\(deletingEnv?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingEnv != nil },
                set: { if !$0 { deletingEnv = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let e = deletingEnv { vault.deleteEnvironment(e) }
                deletingEnv = nil
            }
            Button("Cancel", role: .cancel) { deletingEnv = nil }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog(
            "Delete \"\(deletingSecret?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingSecret != nil },
                set: { if !$0 { deletingSecret = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let s = deletingSecret { vault.delete(s) }
                deletingSecret = nil
            }
            Button("Cancel", role: .cancel) { deletingSecret = nil }
        } message: { Text("This cannot be undone.") }
        .alert("Error", isPresented: Binding(
            get: { vault.errorMessage != nil },
            set: { if !$0 { vault.errorMessage = nil } }
        )) {
            Button("OK") { vault.errorMessage = nil }
        } message: {
            Text(vault.errorMessage ?? "")
        }
    }

    // MARK: - Sidebar Column

    private var sidebarColumn: some View {
        List(vault.projects, selection: projectSelection) { project in
            SidebarProjectRow(
                project: project,
                onEdit: { presentedSheet = .projectAppearance(project) },
                onDelete: { deletingProject = project }
            )
            .tag(project.id)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button { presentedSheet = .projectAppearance(nil) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("New project")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Content Column

    private var contentColumn: some View {
        VStack(spacing: 0) {
            if vault.selectedProject == nil {
                noProjectView
            } else {
                secretsList
            }
        }
        .navigationTitle(selectedProjectTitle)
        .navigationSubtitle(selectedProjectSubtitle)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        vault.selectEnvironment(nil)
                    } label: {
                        Label { Text("Default") } icon: { Theme.envCircle(.white.opacity(0.7)) }
                    }
                    ForEach(vault.environments, id: \.id) { env in
                        Button {
                            vault.selectEnvironment(env)
                        } label: {
                            Label { Text(env.name) } icon: { Theme.envCircle(Theme.color(hex: env.color)) }
                        }
                    }
                    if vault.selectedProject != nil {
                        Divider()
                        Button("Configure Environments...") {
                            presentedSheet = .environmentManager
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Theme.envCircle(vault.selectedEnvironment.map { Theme.color(hex: $0.color) } ?? .white.opacity(0.7))
                        Text(vault.selectedEnvironment?.name ?? "Default")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.button)
                .disabled(vault.selectedProject == nil)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    presentedSheet = .appSettings
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentedSheet = .addSecret
                } label: {
                    Label("New Secret", systemImage: "square.and.pencil")
                }
                .disabled(vault.selectedProject == nil)
                .help("New secret")
            }

        }
        .toolbarSearch(text: $searchText, isPresented: $searchExpanded)
    }

    @ViewBuilder
    private var secretsList: some View {
        if filteredSecrets.isEmpty {
            ContentUnavailableView(
                searchText.isEmpty ? "No Secrets" : "No Results",
                systemImage: searchText.isEmpty ? "key.slash" : "magnifyingglass",
                description: Text(searchText.isEmpty ? "Create a secret to store it in this project." : "No secrets match your search.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredSecrets, selection: secretSelection) { secret in
                SecretRow(
                    secret: secret,
                    onEdit: { presentedSheet = .editSecret(secret) },
                    onMove: { presentedSheet = .moveSecret(secret) },
                    onDelete: { deletingSecret = secret }
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                .listRowSeparator(.hidden)
                .tag(secret.id)
                .contextMenu {
                    Button("Copy") { vault.copyToClipboard(secret) }
                    Divider()
                    Button("Edit\u{2026}") { presentedSheet = .editSecret(secret) }
                    Button("Move\u{2026}") { presentedSheet = .moveSecret(secret) }
                    Divider()
                    Button("Delete", role: .destructive) { deletingSecret = secret }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var noProjectView: some View {
        ContentUnavailableView {
            Label(vault.projects.isEmpty ? "No Projects" : "Select a Project", systemImage: "folder")
        } description: {
            Text(vault.projects.isEmpty ? "Create a project to start storing secrets." : "Choose a project from the sidebar.")
        } actions: {
            if vault.projects.isEmpty {
                Button("New Project") { presentedSheet = .projectAppearance(nil) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        if let secret = selectedSecret {
            SecretDetailView(secret: secret, onEdit: { presentedSheet = .editSecret(secret) })
                .environment(vault)
                .id(secret.id)
        } else {
            ContentUnavailableView("Select a Secret", systemImage: "lock.shield")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Identity

private struct IdentityBadge: View {
    let icon: String?
    let fallbackSystemImage: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(8, size * 0.24))
                .fill(color.opacity(0.16))
            RoundedRectangle(cornerRadius: min(8, size * 0.24))
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
            if let icon, !icon.isEmpty {
                Text(icon)
                    .font(.system(size: size * 0.5))
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct CategoryPill: View {
    let category: SecretCategory

    var body: some View {
        Label(category.label, systemImage: category.systemImage)
            .font(.system(size: 10, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Theme.gold.opacity(0.12))
            )
    }
}

private struct ProjectAppearanceView: View {
    let project: Project?
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String?
    @State private var isShowingSymbolPicker = false

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _icon = State(initialValue: project?.icon)
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
                            vault.refresh()
                        }
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 420, height: 220)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingSymbolPicker) {
            SymbolPicker(symbol: $icon)
        }
    }
}


private struct EnvironmentAppearanceView: View {
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
        .preferredColorScheme(.dark)
    }
}

private struct EnvironmentManagerView: View {
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
        .preferredColorScheme(.dark)
    }
}

private struct EnvironmentEditorRow: View {
    let environment: VaultEnvironment
    @Environment(VaultViewModel.self) private var vault
    @State private var name: String
    @State private var color: String

    init(environment: VaultEnvironment) {
        self.environment = environment
        _name = State(initialValue: environment.name)
        _color = State(initialValue: environment.color ?? Theme.environmentPalette[0])
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Name", text: $name)
            ColorSwatches(selection: $color)
            Button {
                save()
            } label: {
                Image(systemName: "checkmark")
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Save environment")

            Button(role: .destructive) {
                vault.deleteEnvironment(environment)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("Delete environment")
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

private struct ColorSwatches: View {
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

private struct SidebarProjectRow: View {
    let project: Project
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
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = h }
        }
        .contextMenu {
            Button("Edit\u{2026}", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Secret Row

private struct SecretRow: View {
    let secret: Secret
    let onEdit: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @Environment(VaultViewModel.self) private var vault

    var body: some View {
        HStack(spacing: 9) {
            IdentityBadge(icon: secret.category.defaultIcon, fallbackSystemImage: secret.category.systemImage, color: .white, size: 26)
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
    }
}

// MARK: - App Settings

struct AppSettingsView: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var sessionTimeoutSeconds: Double = 300
    @State private var clipboardClearSeconds: Double = 30

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { vault.launchAtLogin },
                        set: { vault.launchAtLogin = $0 }
                    ))
                }

                Section("Security") {
                    Picker("Auto-lock", selection: $sessionTimeoutSeconds) {
                        Text("1 minute").tag(60.0)
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("1 hour").tag(3600.0)
                    }

                    Picker("Clear Clipboard", selection: $clipboardClearSeconds) {
                        Text("15 seconds").tag(15.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("5 minutes").tag(300.0)
                    }

                    Button {
                        vault.lock()
                    } label: {
                        Label("Lock Now", systemImage: "lock")
                    }
                }
            }
            .formStyle(.grouped)
            .onAppear {
                sessionTimeoutSeconds = vault.sessionTimeoutSeconds
                clipboardClearSeconds = vault.clipboardClearSeconds
            }
            .onChange(of: sessionTimeoutSeconds) { _, newValue in vault.sessionTimeoutSeconds = newValue }
            .onChange(of: clipboardClearSeconds) { _, newValue in vault.clipboardClearSeconds = newValue }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 440, height: 340)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Secret Detail

struct SecretDetailView: View {
    let secret: Secret
    var onEdit: (() -> Void)? = nil
    @Environment(VaultViewModel.self) private var vault
    @State private var revealed = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                IdentityBadge(icon: secret.category.defaultIcon, fallbackSystemImage: secret.category.systemImage, color: .white, size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(secret.name)
                            .font(.system(size: 16, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Theme.text)
                        CategoryPill(category: secret.category)
                    }
                    if let desc = secret.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Color.clear.frame(height: 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("VALUE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                        .kerning(1.0)
                    if copied {
                        Label("Copied", systemImage: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                    Button {
                        revealed.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                            Text(revealed ? "Hide" : "Reveal")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealed ? "Hide secret value" : "Reveal secret value")
                }

                Button {
                    vault.copyToClipboard(secret)
                    withAnimation { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { copied = false }
                    }
                } label: {
                    if revealed {
                        Text(secret.value)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        Text(String(repeating: "•", count: min(secret.value.count, 24)))
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(Theme.text)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: .command)
                .help("Click to copy (⌘C)")
                .accessibilityLabel("Copy \(secret.name)")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .animation(.easeInOut(duration: 0.15), value: copied)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Edit Secret

struct EditSecretView: View {
    let secret: Secret
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var value: String
    @State private var description: String
    @State private var category: SecretCategory
    @State private var revealed = false
    @State private var confirmDelete = false

    init(secret: Secret) {
        self.secret = secret
        _value = State(initialValue: secret.value)
        _description = State(initialValue: secret.description ?? "")
        _category = State(initialValue: secret.category)
    }

    private var isValid: Bool { !value.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name") {
                        Text(secret.name)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        if revealed {
                            TextField("Value", text: $value)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Value", text: $value)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button {
                            revealed.toggle()
                        } label: {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Optional") {
                    Picker("Category", selection: $category) {
                        ForEach(SecretCategory.allCases, id: \.self) { category in
                            Label(category.label, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }

                    TextField("Description", text: $description)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Secret")
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vault.update(
                            name: secret.name,
                            value: value,
                            description: description,
                            category: category
                        )
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 440, height: 340)
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Delete \(secret.name)?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                vault.delete(secret)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

// MARK: - Move Secret

struct MoveSecretView: View {
    let secret: Secret
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var destProjectId: String = ""
    @State private var destEnvironmentName: String? = nil
    @State private var availableEnvironments: [VaultEnvironment] = []

    private var isSameDestination: Bool {
        destProjectId == vault.selectedProject?.id &&
        destEnvironmentName == vault.selectedEnvironment?.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Move \"\(secret.name)\" to") {
                    Picker("Project", selection: $destProjectId) {
                        ForEach(vault.projects, id: \.id) { project in
                            Text(project.name).tag(project.id)
                        }
                    }

                    Picker("Environment", selection: $destEnvironmentName) {
                        Text("Default").tag(nil as String?)
                        ForEach(availableEnvironments, id: \.id) { env in
                            Text(env.name).tag(env.name as String?)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: destProjectId) { _, projectId in
                availableEnvironments = (try? Vault.shared.listEnvironments(projectId: projectId)) ?? []
                destEnvironmentName = nil
            }
            .navigationTitle("Move Secret")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        performMove()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSameDestination)
                }
            }
        }
        .frame(width: 380, height: 260)
        .preferredColorScheme(.dark)
        .onAppear {
            destProjectId = vault.selectedProject?.id ?? ""
            destEnvironmentName = vault.selectedEnvironment?.name
            if let projectId = vault.selectedProject?.id {
                availableEnvironments = (try? Vault.shared.listEnvironments(projectId: projectId)) ?? []
            }
        }
    }

    private func performMove() {
        guard let srcProject = vault.selectedProject else { return }
        if destProjectId == srcProject.id {
            vault.moveSecret(secret, toEnvironmentName: destEnvironmentName)
        } else {
            vault.moveSecret(secret, toProjectId: destProjectId)
        }
    }
}
