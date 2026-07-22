import SwiftUI
import LokaliteCore
import SymbolPicker

// MARK: - Environments Tab

struct EnvironmentsTab: View {
    @Environment(VaultViewModel.self) private var vault
    @State private var newName = ""
    @State private var newColor = Theme.environmentPalette[0]
    @State private var editingEnvironment: VaultEnvironment?
    @State private var deletingEnvironment: VaultEnvironment?
    @State private var forceDeletingEnvironment: VaultEnvironment?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Environments")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)

                    if vault.environments.isEmpty {
                        Text("No custom environments. All secrets are in the default environment.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textMuted)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(vault.environments, id: \.id) { env in
                                EnvironmentTabRow(
                                    environment: env,
                                    onEdit: { editingEnvironment = env },
                                    onDelete: { deletingEnvironment = env }
                                )
                                .environment(vault)
                                if env.id != vault.environments.last?.id {
                                    Divider().overlay(Theme.sep)
                                }
                            }
                        }
                        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("New Environment")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)

                    HStack(spacing: 10) {
                        TextField("Name (e.g. staging)", text: $newName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Theme.neutral(0.045), in: .rect(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.sep, lineWidth: 1))

                        ColorSwatches(selection: $newColor)

                        BorderedActionButton(action: {
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            vault.addEnvironment(name: trimmed, color: newColor)
                            newName = ""
                            newColor = Theme.environmentPalette[0]
                        }) {
                            Text("Add")
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .sheet(item: $editingEnvironment) { env in
            EnvironmentAppearanceView(environment: env).environment(vault)
        }
        .confirmationDialog(
            "Delete \"\(deletingEnvironment?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingEnvironment != nil },
                set: { if !$0 { deletingEnvironment = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let e = deletingEnvironment, !vault.deleteEnvironment(e) {
                    forceDeletingEnvironment = e
                }
                deletingEnvironment = nil
            }
            Button("Cancel", role: .cancel) { deletingEnvironment = nil }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog(
            "Delete \"\(forceDeletingEnvironment?.name ?? "")\" and its secrets?",
            isPresented: Binding(
                get: { forceDeletingEnvironment != nil },
                set: { if !$0 { forceDeletingEnvironment = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Environment and Secrets", role: .destructive) {
                if let e = forceDeletingEnvironment {
                    vault.deleteEnvironment(e, includingContents: true)
                }
                forceDeletingEnvironment = nil
            }
            Button("Cancel", role: .cancel) { forceDeletingEnvironment = nil }
        } message: {
            Text("This environment contains secret values. Deleting anyway removes those values and deletes secrets that only existed in this environment.")
        }
    }
}

struct EnvironmentTabRow: View {
    let environment: VaultEnvironment
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(VaultViewModel.self) private var vault
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.color(hex: environment.color))
                .frame(width: 8, height: 8)

            Text(environment.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text)

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button("Edit", action: onEdit)
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.red)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Theme.rowHeight)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovered = h } }
    }
}

// MARK: - Secrets Tab

struct SecretsTab: View {
    @Environment(VaultViewModel.self) private var vault
    let onEdit: (Secret) -> Void
    let onMove: (Secret) -> Void
    let onDelete: (Secret) -> Void
    let onAdd: () -> Void
    @State private var searchText = ""
    @State private var selectedSecret: Secret?

    private var filteredSecrets: [Secret] {
        guard !searchText.isEmpty else { return vault.secrets }
        let q = searchText.lowercased()
        return vault.secrets.filter {
            $0.name.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            $0.category.label.lowercased().contains(q)
        }
    }

    private var selectedEnvironmentName: String {
        vault.selectedEnvironment?.name ?? "No environment"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Secrets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                DashboardSearchField(placeholder: "Search secrets...", text: $searchText, shortcut: "⌘F")
                    .frame(width: 200)
                BorderedActionButton(action: onAdd) {
                    Label("New secret", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)
            .padding(.bottom, 16)

            if filteredSecrets.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.textDim)
                    Text(searchText.isEmpty ? "No secrets in \(selectedEnvironmentName)" : "No matching secrets")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Button { onAdd() } label: {
                        Label("New secret", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        DashboardSecretsTable(
                            secrets: filteredSecrets,
                            environmentNames: vault.secretEnvironmentNames,
                            environmentColors: vault.environmentColors,
                            selectedEnvironmentName: selectedEnvironmentName,
                            selectedSecret: selectedSecret,
                            showActions: true,
                            onSelect: { selectedSecret = $0 },
                            onCopy: { vault.copyToClipboard($0) },
                            onEdit: onEdit,
                            onMove: onMove,
                            onDelete: onDelete
                        )
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)
                }
            }
        }
    }
}

// MARK: - Activity

/// Vault-wide access log. Not scoped to a project: every entry carries its own
/// project and environment, so this is a top-level pane, not a project tab.
struct ActivityView: View {
    @Environment(VaultViewModel.self) private var vault

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filterBar

            if vault.activityEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vault.activityEntries) { entry in
                            ActivityRow(entry: entry)
                            if entry.id != vault.activityEntries.last?.id {
                                Divider().overlay(Theme.sep)
                            }
                        }
                    }
                    .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
                    .padding(.horizontal, 36)
                    .padding(.vertical, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { vault.reloadActivity() }
        .onChange(of: vault.activityFilter) { _, _ in vault.reloadActivity() }
    }

    private var filterBar: some View {
        @Bindable var vault = vault
        return HStack(spacing: 10) {
            DashboardSearchField(
                placeholder: "Search secret, environment, agent...",
                text: $vault.activityFilter.search,
                shortcut: ""
            )
            .frame(width: 260)

            Picker("", selection: $vault.activityFilter.projectName) {
                Text("All projects").tag(String?.none)
                ForEach(vault.projects) { project in
                    Text(project.name).tag(String?.some(project.name))
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Picker("", selection: $vault.activityFilter.source) {
                Text("All sources").tag(ActivityLogEntry.AccessSource?.none)
                Text("App").tag(ActivityLogEntry.AccessSource?.some(.app))
                Text("CLI").tag(ActivityLogEntry.AccessSource?.some(.cli))
                Text("MCP").tag(ActivityLogEntry.AccessSource?.some(.mcp))
            }
            .labelsHidden()
            .frame(width: 120)

            Picker("", selection: $vault.activityFilter.action) {
                Text("All actions").tag(ActivityLogEntry.Action?.none)
                ForEach([ActivityLogEntry.Action.read, .created, .updated, .deleted, .denied], id: \.self) { action in
                    Text(action.rawValue.capitalized).tag(ActivityLogEntry.Action?.some(action))
                }
            }
            .labelsHidden()
            .frame(width: 120)

            Spacer()

            if !vault.activityFilter.isEmpty {
                Button("Clear") { vault.activityFilter = ActivityFilter() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.brand)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.sep)
                .frame(height: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: vault.activityFilter.isEmpty ? "clock" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textDim)
            Text(vault.activityFilter.isEmpty ? "No activity yet" : "No matching activity")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(vault.activityFilter.isEmpty
                 ? "Secrets accessed via the app, CLI, or MCP will appear here."
                 : "No entry matches these filters.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.brand.opacity(0.16))
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Theme.brand.opacity(0.28), lineWidth: 1)
                Image(systemName: "clock")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.brand)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Activity")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Every project and environment in the vault")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.sep)
                .frame(height: 1)
        }
    }
}

struct ActivityRow: View {
    let entry: ActivityLogEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(sourceColor.opacity(0.15))
                Image(systemName: sourceIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(sourceColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.secretName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(actionLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(actionColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(actionColor.opacity(0.14), in: .rect(cornerRadius: 3))
                }
                Text("\(entry.projectName) / \(entry.environmentName)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    if let agent = entry.agent {
                        Text(agent)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.violet)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.violet.opacity(0.13), in: .rect(cornerRadius: 4))
                    }
                    Text(sourceLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(sourceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor.opacity(0.13), in: .rect(cornerRadius: 4))
                }
                Text(relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Theme.rowHeight)
    }

    private var actionLabel: String {
        switch entry.action {
        case .read: return "read"
        case .created: return "created"
        case .updated: return "updated"
        case .deleted: return "deleted"
        case .denied: return "denied"
        }
    }

    private var actionColor: Color {
        switch entry.action {
        case .read: return Theme.textMuted
        case .created: return Theme.brand
        case .updated: return Theme.blue
        case .deleted: return Theme.orange
        case .denied: return Theme.red
        }
    }

    private var sourceIcon: String {
        switch entry.source {
        case .app: return "menubar.rectangle"
        case .cli: return "terminal"
        case .mcp: return "sparkles"
        }
    }

    private var sourceColor: Color {
        switch entry.source {
        case .app: return Theme.blue
        case .cli: return Theme.mint
        case .mcp: return Theme.violet
        }
    }

    private var sourceLabel: String {
        switch entry.source {
        case .app: return "App"
        case .cli: return "CLI"
        case .mcp: return "MCP"
        }
    }

    private static let relativeTimeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var relativeTime: String {
        Self.relativeTimeFormatter.localizedString(for: entry.accessedAt, relativeTo: Date())
    }
}

// MARK: - Project Settings Tab

struct ProjectSettingsTab: View {
    @Environment(VaultViewModel.self) private var vault
    let onEditAppearance: () -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var path: String = ""
    @State private var icon: String? = nil
    @State private var isShowingSymbolPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                settingsSection
                dangerZone
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .onAppear { syncFromProject() }
        .onChange(of: vault.selectedProject) { _, _ in syncFromProject() }
        .sheet(isPresented: $isShowingSymbolPicker) {
            SymbolPicker(symbol: $icon)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)

            VStack(spacing: 0) {
                settingsRow(label: "Name") {
                    TextField("Project name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.text)
                        .onSubmit { saveName() }
                }

                Divider().overlay(Theme.sep)

                settingsRow(label: "Icon") {
                    Button {
                        isShowingSymbolPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon ?? "folder")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onChange(of: icon) { _, newIcon in saveIcon(newIcon) }

                Divider().overlay(Theme.sep)

                Button(action: pickDirectory) {
                    settingsRow(label: "Linked folder") {
                        HStack(spacing: 8) {
                            Text(shortPath(path) ?? "Not linked")
                                .font(.system(size: 13))
                                .foregroundStyle(path.isEmpty ? Theme.textDim : Theme.blue)
                                .lineLimit(1)
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textMuted)
                            if !path.isEmpty {
                                Button {
                                    path = ""
                                    savePath()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(.rect)
            }
            .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Danger Zone")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.red)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete project")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text("Permanently delete this project and all its secrets.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Button("Delete Project", role: .destructive, action: onDelete)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.red)
                    .controlSize(.small)
            }
            .padding(16)
            .background(Theme.red.opacity(0.06), in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.red.opacity(0.18), lineWidth: 1))
        }
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func syncFromProject() {
        guard let project = vault.selectedProject else { return }
        name = project.name
        path = project.path ?? ""
        icon = project.icon
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let project = vault.selectedProject, trimmed != project.name else { return }
        vault.renameProject(project, newName: trimmed)
    }

    private func saveIcon(_ newIcon: String?) {
        guard let project = vault.selectedProject else { return }
        vault.setProjectIcon(project, icon: newIcon)
    }

    private func savePath() {
        guard let project = vault.selectedProject else { return }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        vault.linkProject(project, path: trimmed.isEmpty ? nil : trimmed)
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Link"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            savePath()
        }
    }

}
