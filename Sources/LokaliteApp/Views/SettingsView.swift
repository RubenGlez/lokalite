import SwiftUI
import LokaliteCore

// MARK: - Identifiable

extension Secret: Identifiable {}

// MARK: - Theme

private enum Theme {
    static let gold       = Color(red: 0.910, green: 0.627, blue: 0.118)
    static let goldSubtle = Color(red: 0.910, green: 0.627, blue: 0.118).opacity(0.15)
    static let sep        = Color.white.opacity(0.08)
    static let text       = Color(red: 0.929, green: 0.929, blue: 0.941)
    static let textMuted  = Color(red: 0.565, green: 0.565, blue: 0.612)
    static let textDim    = Color(red: 0.341, green: 0.341, blue: 0.376)
    static let bgHigh     = Color.white.opacity(0.06)
    static let red        = Color(red: 0.965, green: 0.369, blue: 0.369)
    static let green      = Color(red: 0.302, green: 0.847, blue: 0.569)
}

// MARK: - Root

struct SettingsView: View {
    @EnvironmentObject private var vault: VaultViewModel
    @State private var selectedSecret: Secret?

    // Sheets
    @State private var showingAddProject = false
    @State private var showingAddSecret = false
    @State private var showingAddEnv = false
    @State private var showingAppSettings = false
    @State private var editingSecret: Secret?
    @State private var movingSecret: Secret?

    // Search
    @State private var searchExpanded = false

    // Rename
    @State private var renamingProject: Project?
    @State private var renameProjectText = ""
    @State private var renamingEnv: VaultEnvironment?
    @State private var renameEnvText = ""

    // Delete confirmations
    @State private var deletingProject: Project?
    @State private var deletingEnv: VaultEnvironment?
    @State private var deletingSecret: Secret?

    // Inline input
    @State private var newProjectName = ""
    @State private var newEnvName = ""
    @State private var searchText = ""

    private var filteredSecrets: [Secret] {
        guard !searchText.isEmpty else { return vault.secrets }
        let q = searchText.lowercased()
        return vault.secrets.filter {
            $0.name.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false)
        }
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
        .onChange(of: vault.secrets) { newSecrets in
            if let selected = selectedSecret {
                selectedSecret = newSecrets.first { $0.name == selected.name }
            }
        }
        .sheet(isPresented: $showingAddSecret) {
            AddSecretView().environmentObject(vault)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView().environmentObject(vault)
        }
        .sheet(item: $editingSecret) { s in
            EditSecretView(secret: s).environmentObject(vault)
        }
        .sheet(item: $movingSecret) { s in
            MoveSecretView(secret: s).environmentObject(vault)
        }
        .alert("New Project", isPresented: $showingAddProject) {
            TextField("Name", text: $newProjectName)
            Button("Create") {
                guard !newProjectName.isEmpty else { return }
                vault.addProject(name: newProjectName)
                newProjectName = ""
            }
            Button("Cancel", role: .cancel) { newProjectName = "" }
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
        .alert("Rename Project", isPresented: Binding(
            get: { renamingProject != nil },
            set: { if !$0 { renamingProject = nil } }
        )) {
            TextField("Name", text: $renameProjectText)
            Button("Rename") {
                if let p = renamingProject, !renameProjectText.isEmpty {
                    vault.renameProject(p, newName: renameProjectText)
                }
                renamingProject = nil
            }
            Button("Cancel", role: .cancel) { renamingProject = nil }
        }
        .alert("Rename Environment", isPresented: Binding(
            get: { renamingEnv != nil },
            set: { if !$0 { renamingEnv = nil } }
        )) {
            TextField("Name", text: $renameEnvText)
            Button("Rename") {
                if let e = renamingEnv, !renameEnvText.isEmpty {
                    vault.renameEnvironment(e, newName: renameEnvText)
                }
                renamingEnv = nil
            }
            Button("Cancel", role: .cancel) { renamingEnv = nil }
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
    }

    // MARK: - Sidebar Column

    private var sidebarColumn: some View {
        List(vault.projects, id: \.id) { project in
            let isSelected = vault.selectedProject?.id == project.id
            SidebarProjectRow(
                project: project,
                isSelected: isSelected,
                onSelect: { vault.selectProject(project) },
                onRename: {
                    renamingProject = project
                    renameProjectText = project.name
                },
                onDelete: { deletingProject = project }
            )
            .listRowBackground(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.goldSubtle : Color.clear)
                    .padding(.horizontal, 4)
            )
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
                Button { showingAddProject = true } label: {
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
        .navigationTitle(vault.selectedProject?.name ?? "Lokalite")
        .navigationSubtitle({
            guard vault.selectedProject != nil else { return "" }
            let n = vault.secrets.count
            return "\(n) secret\(n == 1 ? "" : "s")"
        }())
        .background(settingsToolbarConfigurator)
    }

    private var settingsToolbarConfigurator: some View {
        SettingsToolbarConfigurator(
            vault: vault,
            searchText: $searchText,
            onSettings: { showingAppSettings = true },
            onAddSecret: { showingAddSecret = true },
            onNewEnvironment: { showingAddEnv = true },
            onRenameEnvironment: { env in
                renamingEnv = env
                renameEnvText = env.name
            },
            onDeleteEnvironment: { env in deletingEnv = env }
        )
        .frame(width: 0, height: 0)
    }

@ViewBuilder
    private var secretsList: some View {
        if filteredSecrets.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: searchText.isEmpty ? "key.slash" : "magnifyingglass")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(Theme.textDim)
                Text(searchText.isEmpty ? "No secrets yet" : "No results")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredSecrets, id: \.id) { secret in
                SecretRow(
                    secret: secret,
                    onEdit: { editingSecret = secret },
                    onMove: { movingSecret = secret },
                    onDelete: { deletingSecret = secret }
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedSecret?.name == secret.name ? Theme.goldSubtle : Color.clear)
                        .padding(.horizontal, 4)
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedSecret = secret }
                .contextMenu {
                    Button("Edit\u{2026}") { editingSecret = secret }
                    Button("Move\u{2026}") { movingSecret = secret }
                    Divider()
                    Button("Delete", role: .destructive) { deletingSecret = secret }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var noProjectView: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(Theme.textDim)
            Text("Select a project")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim)
            if vault.projects.isEmpty {
                Button("New Project") { showingAddProject = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        if let secret = selectedSecret {
            SecretDetailView(secret: secret)
                .environmentObject(vault)
                .id(secret.name)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(Theme.textDim)
                Text("Select a secret")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Sidebar Project Row

private struct SidebarProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.textMuted)
                Text(project.name)
                    .foregroundStyle(isSelected ? Theme.gold : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            if isHovered {
                Menu {
                    Button("Rename\u{2026}", action: onRename)
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
            Button("Rename\u{2026}", action: onRename)
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

    var body: some View {
        HStack(spacing: 0) {
            Text(secret.name)
                .font(.system(size: 12, design: .monospaced).weight(.medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer()

            if isHovered {
                Menu {
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
    }
}

// MARK: - App Settings

struct AppSettingsView: View {
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("General") {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { vault.launchAtLogin },
                        set: { vault.launchAtLogin = $0 }
                    ))
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420, height: 180)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Secret Detail

struct SecretDetailView: View {
    let secret: Secret
    @EnvironmentObject private var vault: VaultViewModel
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(secret.name)
                    .font(.system(size: 16, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.text)
                if let desc = secret.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
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
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.sep, lineWidth: 1)

                    if revealed {
                        Text(secret.value)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        Text(String(repeating: "•", count: min(secret.value.count, 24)))
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                    }
                }
                .frame(height: 44, alignment: .topLeading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Edit Secret

struct EditSecretView: View {
    let secret: Secret
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var value: String
    @State private var description: String
    @State private var revealed = false
    @State private var confirmDelete = false

    init(secret: Secret) {
        self.secret = secret
        _value = State(initialValue: secret.value)
        _description = State(initialValue: secret.description ?? "")
    }

    private var isValid: Bool { !value.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
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
                    TextField("Description", text: $description)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.red.opacity(0.8))
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    vault.update(name: secret.name, value: value, description: description)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 440, height: 320)
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
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var destProjectId: String = ""
    @State private var destEnvironmentName: String? = nil
    @State private var availableEnvironments: [VaultEnvironment] = []

    private var isSameDestination: Bool {
        destProjectId == vault.selectedProject?.id &&
        destEnvironmentName == vault.selectedEnvironment?.name
    }

    var body: some View {
        VStack(spacing: 0) {
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
            .onChange(of: destProjectId) { projectId in
                availableEnvironments = (try? Vault.shared.listEnvironments(projectId: projectId)) ?? []
                destEnvironmentName = nil
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Move") {
                    performMove()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isSameDestination)
            }
            .padding()
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
