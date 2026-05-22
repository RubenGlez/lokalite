import SwiftUI
import LokaliteCore

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
    @State private var showingAddProject = false
    @State private var showingAddSecret = false
    @State private var showingAddEnv = false
    @State private var showingAppSettings = false
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
            if let selected = selectedSecret, !newSecrets.contains(where: { $0.id == selected.id }) {
                selectedSecret = nil
            }
        }
        .sheet(isPresented: $showingAddSecret) {
            AddSecretView().environmentObject(vault)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView().environmentObject(vault)
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
    }

    // MARK: - Sidebar Column

    private var sidebarColumn: some View {
        List(vault.projects, id: \.id) { project in
            let isSelected = vault.selectedProject?.id == project.id
            Label(project.name, systemImage: "folder")
                .foregroundStyle(isSelected ? Theme.gold : .primary)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Theme.goldSubtle : Color.clear)
                        .padding(.horizontal, 4)
                )
                .contentShape(Rectangle())
                .onTapGesture { vault.selectProject(project) }
                .contextMenu {
                    Button("Delete", role: .destructive) { vault.deleteProject(project) }
                }
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
                envPickerRow
                Rectangle().fill(Theme.sep).frame(height: 1)
                searchBar
                Rectangle().fill(Theme.sep).frame(height: 1)
                secretsList
            }
        }
        .navigationTitle(vault.selectedProject?.name ?? "Lokalite")
        .navigationSubtitle({
            guard vault.selectedProject != nil else { return "" }
            let n = vault.secrets.count
            return "\(n) secret\(n == 1 ? "" : "s")"
        }())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAppSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
            if vault.selectedProject != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddSecret = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("New secret")
                }
            }
        }
    }

    private var envPickerRow: some View {
        HStack {
            envPickerInline
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var envPickerInline: some View {
        Menu {
            Button {
                vault.selectEnvironment(nil)
            } label: {
                if vault.selectedEnvironment == nil {
                    Label("Default", systemImage: "checkmark")
                } else {
                    Text("Default")
                }
            }
            if !vault.environments.isEmpty {
                Divider()
                ForEach(vault.environments, id: \.id) { env in
                    Button {
                        vault.selectEnvironment(env)
                    } label: {
                        if vault.selectedEnvironment?.id == env.id {
                            Label(env.name, systemImage: "checkmark")
                        } else {
                            Text(env.name)
                        }
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) { vault.deleteEnvironment(env) }
                    }
                }
            }
            Divider()
            Button("New Environment\u{2026}") { showingAddEnv = true }
        } label: {
            Text(vault.selectedEnvironment?.name ?? "Default")
                .foregroundStyle(Theme.gold)
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim)
            TextField("Filter secrets\u{2026}", text: $searchText)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                SecretRow(secret: secret) { vault.copyToClipboard(secret) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(selectedSecret?.id == secret.id ? Theme.goldSubtle : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSecret = secret }
                    .contextMenu {
                        Button("Copy Value") { vault.copyToClipboard(secret) }
                        Divider()
                        Button("Delete", role: .destructive) { vault.delete(secret) }
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
                .id(secret.id)
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

// MARK: - Secret Row

private struct SecretRow: View {
    let secret: Secret
    let onCopy: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name)
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if let desc = secret.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(alignment: .trailing) {
            if isHovered {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgHigh))
                }
                .buttonStyle(.plain)
                .help("Copy value")
                .padding(.trailing, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            }
        }
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
    @State private var editingValue = ""
    @State private var revealed = false
    @State private var saved = false
    @State private var confirmDelete = false

    private var hasChanges: Bool { editingValue != secret.value && !editingValue.isEmpty }

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

            Rectangle().fill(Theme.sep).frame(height: 1)

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

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.sep, lineWidth: 1)

                    if revealed {
                        TextField("", text: $editingValue, axis: .vertical)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .textFieldStyle(.plain)
                            .lineLimit(1...8)
                            .padding(12)
                    } else {
                        SecureField("", text: $editingValue)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .textFieldStyle(.plain)
                            .padding(12)
                    }
                }
                .frame(minHeight: 52)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            HStack {
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.green)
                        .transition(.opacity)
                }
                Spacer()
                Button("Save Changes") {
                    vault.update(name: secret.name, value: editingValue)
                    withAnimation(.easeInOut(duration: 0.2)) { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) { saved = false }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasChanges)
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.2), value: saved)

            Spacer()

            Rectangle()
                .fill(Theme.sep)
                .frame(height: 1)
                .padding(.horizontal, 24)

            Button {
                confirmDelete = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                    Text("Delete Secret")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Theme.red.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { editingValue = secret.value }
        .confirmationDialog(
            "Delete \(secret.name)?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { vault.delete(secret) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

// MARK: - Primary Button Style

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : Theme.textDim)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isEnabled
                            ? Theme.gold.opacity(configuration.isPressed ? 0.75 : 1.0)
                            : Theme.bgHigh
                    )
            )
    }
}
