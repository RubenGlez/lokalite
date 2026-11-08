import AppKit
import SwiftUI
import LokaliteCore
import SymbolPicker

// MARK: - Root

struct SettingsView: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(SoftwareUpdater.self) private var softwareUpdater
    @State private var projectSearchText = ""
    /// What fills the main area. Secrets is the project's landing view; project
    /// Settings and the (vault-wide) Activity log replace it as full panes with a
    /// back button, instead of sitting on a tab bar.
    @State private var pane: MainPane = .secrets
    /// Icon-only sidebar rail. Persisted so the choice survives relaunches.
    @AppStorage("sidebarCollapsed") private var sidebarCollapsed = false
    /// Project Info column beside the secrets list; toggled from the project header.
    @AppStorage("projectInfoVisible") private var projectInfoVisible = true

    private enum MainPane {
        case secrets, settings, activity
    }

    private enum PresentedSheet: Identifiable {
        case addSecret
        case appSettings
        case editSecret(Secret)
        case moveSecret(Secret)
        case projectAppearance(Project?)
        case environmentAppearance(VaultEnvironment)
        case importEnv(ImportEnvRequest)

        var id: String {
            switch self {
            case .addSecret: "add-secret"
            case .appSettings: "app-settings"
            case .editSecret(let secret): "edit-secret-\(secret.id)"
            case .moveSecret(let secret): "move-secret-\(secret.id)"
            case .projectAppearance(let project): "project-\(project?.id ?? "new")"
            case .environmentAppearance(let environment): "environment-\(environment.id)"
            case .importEnv(let request): "import-env-\(request.id)"
            }
        }
    }

    // Presentation
    @State private var presentedSheet: PresentedSheet?

    // Search
    @FocusState private var projectSearchFocused: Bool
    @FocusState private var secretSearchFocused: Bool


    // Delete confirmations
    @State private var deletingProject: Project?
    @State private var forceDeletingProject: Project?
    @State private var deletingEnv: VaultEnvironment?
    @State private var forceDeletingEnv: VaultEnvironment?
    @State private var deletingSecret: Secret?

    private var filteredProjects: [Project] {
        guard !projectSearchText.isEmpty else { return vault.projects }
        let q = projectSearchText.lowercased()
        return vault.projects.filter {
            $0.name.lowercased().contains(q) ||
            ($0.path?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        ZStack {
            Theme.windowBackground.ignoresSafeArea()

            if vault.isLocked {
                lockedView
            } else if vault.projects.isEmpty {
                onboardingView
            } else {
                dashboard
            }
        }
        .tint(Theme.brand)
        .preferredColorScheme(vault.colorScheme)
        .onAppear {
            if vault.isLocked { vault.unlock() }
            consumePendingAddSecret()
        }
        .onChange(of: vault.pendingAddSecret) { _, _ in
            consumePendingAddSecret()
        }
        .onChange(of: vault.isLocked) { _, isLocked in
            if isLocked {
                presentedSheet = nil
                deletingProject = nil
                forceDeletingProject = nil
                deletingEnv = nil
                forceDeletingEnv = nil
                deletingSecret = nil
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addSecret:
                AddSecretView().environment(vault)
            case .appSettings:
                AppSettingsView().environment(vault).environment(softwareUpdater)
            case .editSecret(let secret):
                EditSecretView(secret: secret).environment(vault)
            case .moveSecret(let secret):
                MoveSecretView(secret: secret).environment(vault)
            case .projectAppearance(let project):
                ProjectAppearanceView(project: project).environment(vault)
            case .environmentAppearance(let environment):
                EnvironmentAppearanceView(environment: environment).environment(vault)
            case .importEnv(let request):
                ImportEnvView(request: request).environment(vault)
            }
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
                if let p = deletingProject, !vault.deleteProject(p) {
                    forceDeletingProject = p
                }
                deletingProject = nil
            }
            Button("Cancel", role: .cancel) { deletingProject = nil }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog(
            "Delete \"\(forceDeletingProject?.name ?? "")\" and all contents?",
            isPresented: Binding(
                get: { forceDeletingProject != nil },
                set: { if !$0 { forceDeletingProject = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Project and Contents", role: .destructive) {
                if let p = forceDeletingProject {
                    vault.deleteProject(p, includingContents: true)
                }
                forceDeletingProject = nil
            }
            Button("Cancel", role: .cancel) { forceDeletingProject = nil }
        } message: {
            Text("This project contains environments and secrets. Deleting anyway removes the project, its environments, and all stored secrets.")
        }
        .confirmationDialog(
            "Delete \"\(deletingEnv?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingEnv != nil },
                set: { if !$0 { deletingEnv = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let e = deletingEnv, !vault.deleteEnvironment(e) {
                    forceDeletingEnv = e
                }
                deletingEnv = nil
            }
            Button("Cancel", role: .cancel) { deletingEnv = nil }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog(
            "Delete \"\(forceDeletingEnv?.name ?? "")\" and its secrets?",
            isPresented: Binding(
                get: { forceDeletingEnv != nil },
                set: { if !$0 { forceDeletingEnv = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Environment and Secrets", role: .destructive) {
                if let e = forceDeletingEnv {
                    vault.deleteEnvironment(e, includingContents: true)
                }
                forceDeletingEnv = nil
            }
            Button("Cancel", role: .cancel) { forceDeletingEnv = nil }
        } message: {
            Text("This environment contains secret values. Deleting anyway removes those values and deletes secrets that only existed in this environment.")
        }
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
        .frame(minWidth: 1060, minHeight: 620)
    }

    // MARK: - Root Layout

    private var dashboard: some View {
        HStack(spacing: 0) {
            redesignedSidebar
                .frame(width: sidebarCollapsed ? 60 : 245)
            Divider().overlay(Theme.sep)
            switch pane {
            case .activity:
                VStack(alignment: .leading, spacing: 0) {
                    paneBackBar
                    ActivityView()
                        .environment(vault)
                }
            case .settings:
                VStack(alignment: .leading, spacing: 0) {
                    paneBackBar
                    ProjectSettingsTab(
                        onEditAppearance: { presentedSheet = .projectAppearance(vault.selectedProject) },
                        onDelete: { deletingProject = vault.selectedProject }
                    )
                    .environment(vault)
                }
            case .secrets:
                mainDashboard
            }
        }
        .background {
            Group {
                Button("") { focusProjectSearch() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("") { toggleSidebar() }
                    .keyboardShortcut("s", modifiers: [.control, .command])
                // ⌘F lands on the Secrets search, from Settings or Activity too.
                Button("") {
                    pane = .secrets
                    Task { @MainActor in secretSearchFocused = true }
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            .hidden()
        }
        // Deleting the project from its Settings pane selects another project;
        // land on that project's Secrets rather than on its Settings.
        .onChange(of: vault.selectedProject?.id) { _, _ in
            if pane == .settings { pane = .secrets }
        }
    }

    private var redesignedSidebar: some View {
        let compact = sidebarCollapsed
        return VStack(alignment: compact ? .center : .leading, spacing: 0) {
            HStack(spacing: 8) {
                if !compact {
                    Text("Lokalite")
                        .font(Theme.mono(20, .semibold))
                        .foregroundStyle(Theme.text)
                    DevBadge()
                    Spacer()
                }
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(IconButtonStyle())
                .help(compact ? "Expand sidebar (⌃⌘S)" : "Collapse sidebar (⌃⌘S)")
            }
            .padding(.top, 24)
            .padding(.leading, compact ? 0 : 20)
            .padding(.trailing, compact ? 0 : 14)

            if compact {
                Button(action: focusProjectSearch) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(IconButtonStyle(size: 36, cornerRadius: 8))
                .help("Search projects (⌘K)")
                .padding(.top, 14)
            } else {
                DashboardSearchField(
                    placeholder: "Search projects...",
                    text: $projectSearchText,
                    shortcut: "⌘K",
                    isFocused: $projectSearchFocused
                )
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }

            HStack {
                if !compact {
                    Text("Projects")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                        .textCase(.uppercase)
                    Spacer()
                }
                Menu {
                    Button("New project") {
                        presentedSheet = .projectAppearance(nil)
                    }
                    Button("Import from .env…") {
                        beginImportFromEnv(mode: .createProject)
                    }
                } label: {
                    // Small plate button: it sits on the "Projects" section label,
                    // so it's shorter than the toolbar buttons.
                    Group {
                        if compact {
                            Image(systemName: "plus")
                        } else {
                            Label("New", systemImage: "plus")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.button)
                .buttonStyle(SurfaceButtonStyle(height: 22, horizontalPadding: compact ? 6 : 7, cornerRadius: 6))
                .menuIndicator(.hidden)
                .fixedSize()
                .help("New project or import from .env")
            }
            .padding(.horizontal, compact ? 0 : 20)
            .padding(.top, compact ? 12 : 26)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: compact ? 4 : 5) {
                    ForEach(compact ? vault.projects : filteredProjects) { project in
                        DashboardProjectRow(
                            project: project,
                            isSelected: pane != .activity && vault.selectedProject?.id == project.id,
                            compact: compact,
                            onSelect: {
                                pane = .secrets
                                vault.selectProject(project)
                            }
                        )
                        .contextMenu {
                            Button("Import from .env…") {
                                pane = .secrets
                                vault.selectProject(project)
                                beginImportFromEnv(mode: .existingProject(project))
                            }
                        }
                    }
                }
                .padding(.horizontal, compact ? 0 : 10)
            }

            Spacer()

            Divider()
                .overlay(Theme.sep)
                .padding(.horizontal, 14)

            SidebarToolsSection(compact: compact)
                .padding(.top, 8)

            Divider()
                .overlay(Theme.sep)
                .padding(.horizontal, 14)
                .padding(.top, 8)

            // Expanded: Activity and Settings share one row. Collapsed: stacked icons.
            Group {
                if compact {
                    VStack(spacing: 0) { activityButton(compact: true); settingsButton(compact: true) }
                } else {
                    // Both icon-only; the tooltips carry the names.
                    HStack(spacing: 4) {
                        activityButton(compact: true)
                        Spacer()
                        settingsButton(compact: true)
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.sidebarBackground)
    }

    private func activityButton(compact: Bool) -> some View {
        sidebarFooterButton("Activity", systemImage: "clock.arrow.circlepath", compact: compact,
                            isSelected: pane == .activity) {
            pane = .activity
        }
    }

    private func settingsButton(compact: Bool) -> some View {
        sidebarFooterButton("Settings", systemImage: "gearshape", compact: compact, isSelected: false) {
            presentedSheet = .appSettings
        }
    }

    @ViewBuilder
    private func sidebarFooterButton(
        _ title: String, systemImage: String, compact: Bool, isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if compact {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle(size: 36, cornerRadius: 8, isOn: isSelected))
            .help(title)
            .padding(.vertical, 2)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.brand : Theme.text)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
            }
            .buttonStyle(RowButtonStyle(isSelected: isSelected))
            .padding(.horizontal, 8)
            .help(title)
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) { sidebarCollapsed.toggle() }
    }

    /// ⌘K / the rail's search icon: expand first if collapsed, then focus the field.
    private func focusProjectSearch() {
        if sidebarCollapsed { toggleSidebar() }
        Task { @MainActor in projectSearchFocused = true }
    }

    private var mainDashboard: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader
            secretsContent
        }
    }

    private var secretsContent: some View {
        SecretsTab(
            onEdit: { presentedSheet = .editSecret($0) },
            onMove: { presentedSheet = .moveSecret($0) },
            onDelete: { deletingSecret = $0 },
            onAdd: { presentedSheet = .addSecret },
            onEditEnvironment: { presentedSheet = .environmentAppearance($0) },
            onDeleteEnvironment: { deletingEnv = $0 },
            showProjectInfo: projectInfoVisible,
            onOpenActivity: {
                vault.activityFilter = ActivityFilter(projectName: vault.selectedProject?.name)
                pane = .activity
            },
            searchFocus: $secretSearchFocused
        )
        .environment(vault)
    }

    /// Back to the selected project's Secrets view, from Settings or Activity.
    private var paneBackBar: some View {
        Button {
            pane = .secrets
        } label: {
            Label(vault.selectedProject?.name ?? "Back", systemImage: "chevron.left")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .buttonStyle(LinkButtonStyle(tone: .muted))
        .keyboardShortcut("[", modifiers: .command)
        .help("Back to \(vault.selectedProject?.name ?? "the project")'s secrets (⌘[)")
        .padding(.horizontal, 36)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                MainProjectIcon(project: vault.selectedProject)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 9) {
                        Text(vault.selectedProject?.name ?? "Lokalite")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        if vault.selectedProject?.path != nil {
                            Text("Linked")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.green.opacity(0.14), in: .rect(cornerRadius: 5))
                        }
                    }
                    Text(shortPath(vault.selectedProject?.path) ?? "Not linked")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }

                Spacer()

                // Icon-only so it doesn't read as a second copy of the sidebar's
                // app-wide Settings; the vault-wide Activity stays in the sidebar.
                BorderedActionButton(action: { pane = .settings }) {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Project settings")
                }
                .help("Project settings: name, icon, linked folder, and deletion")

                BorderedActionButton(isOn: projectInfoVisible, action: {
                    withAnimation(.easeInOut(duration: 0.2)) { projectInfoVisible.toggle() }
                }) {
                    Image(systemName: "sidebar.right")
                        .accessibilityLabel(projectInfoVisible ? "Hide project info" : "Show project info")
                }
                .help(projectInfoVisible ? "Hide project info" : "Show project info")
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
    }

    // MARK: - States

    private var lockedView: some View {
        VStack(spacing: 22) {
            LokaliteLogo(size: 128)
                // The artwork has transparent margin below; pull the wordmark up.
                .padding(.bottom, -14)

            VStack(spacing: 8) {
                Text("lokalite")
                    .font(Theme.mono(22, .semibold))
                    .foregroundStyle(Theme.text)
                Label("Vault locked", systemImage: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
            }

            Button {
                vault.unlock()
            } label: {
                Label("Unlock", systemImage: "lock.open")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(SurfaceButtonStyle(kind: .primary, height: 32, horizontalPadding: 18))
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var onboardingView: some View {
        VStack(spacing: 22) {
            LokaliteLogo(size: 104)

            VStack(spacing: 8) {
                Text("Welcome to Lokalite")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text("Create a project to start storing secrets by environment.")
                    .font(.body)
                    .foregroundStyle(Theme.textMuted)
            }
            VStack(spacing: 12) {
                Button("Create your first project") {
                    presentedSheet = .projectAppearance(nil)
                }
                .buttonStyle(SurfaceButtonStyle(kind: .primary, height: 32, horizontalPadding: 18))
                .keyboardShortcut(.defaultAction)

                Button("Import from .env") {
                    beginImportFromEnv(mode: .createProject)
                }
                .buttonStyle(LinkButtonStyle(tone: .brand))
                .font(.system(size: 13, weight: .medium))
                .help("Pick an existing .env file (or its folder) to create a project from it")
            }

            // Onboarding replaces the whole dashboard, sidebar included, so without
            // this the CLI and MCP setup would be unreachable until a project
            // exists — neither of which needs one. First run is also when both are
            // most likely still uninstalled.
            VStack(spacing: 10) {
                Divider().overlay(Theme.sep)
                SidebarToolsSection()
            }
            .frame(width: 260)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Pick a `.env` file (or a folder containing one), parse it, and open the
    /// guided import sheet. Shared by onboarding, the new-project affordance,
    /// and the per-project import action.
    private func beginImportFromEnv(mode: ImportEnvRequest.Mode) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a .env file, or a folder containing one."
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let projectFolder = isDir.boolValue ? url : url.deletingLastPathComponent()
        let envURL = isDir.boolValue ? url.appendingPathComponent(".env") : url

        guard FileManager.default.fileExists(atPath: envURL.path),
              let content = try? String(contentsOf: envURL, encoding: .utf8) else {
            vault.errorMessage = "No .env file found at \(envURL.path)."
            return
        }
        let pairs = EnvFileFormat.parse(content)
        guard !pairs.isEmpty else {
            vault.errorMessage = "No key=value pairs found in \(envURL.lastPathComponent)."
            return
        }
        let folderName = projectFolder.lastPathComponent
        presentedSheet = .importEnv(ImportEnvRequest(
            mode: mode,
            envURL: envURL,
            suggestedProjectName: folderName.isEmpty ? "Imported" : folderName,
            suggestedLinkPath: projectFolder.path,
            pairs: pairs
        ))
    }

    // MARK: - Actions

    /// The popover hands "new secret" over here (it can't host the sheet itself).
    private func consumePendingAddSecret() {
        guard vault.pendingAddSecret else { return }
        vault.pendingAddSecret = false
        presentedSheet = .addSecret
    }
}
