import AppKit
import SwiftUI
import LokaliteCore
import SymbolPicker

// MARK: - Root

struct SettingsView: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(SoftwareUpdater.self) private var softwareUpdater
    @State private var selectedSecret: Secret?
    @State private var selectedTab = "Overview"
    @State private var projectSearchText = ""
    /// The activity log spans every project, so it lives beside Settings in the
    /// sidebar and replaces the project pane instead of being a project tab.
    @State private var showingActivity = false

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
    @State private var searchText = ""
    @FocusState private var projectSearchFocused: Bool
    @FocusState private var secretSearchFocused: Bool


    // Delete confirmations
    @State private var deletingProject: Project?
    @State private var forceDeletingProject: Project?
    @State private var deletingEnv: VaultEnvironment?
    @State private var forceDeletingEnv: VaultEnvironment?
    @State private var deletingSecret: Secret?

    private var filteredSecrets: [Secret] {
        guard !searchText.isEmpty else { return vault.secrets }
        let q = searchText.lowercased()
        return vault.secrets.filter {
            $0.name.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            $0.category.label.lowercased().contains(q)
        }
    }

    private var filteredProjects: [Project] {
        guard !projectSearchText.isEmpty else { return vault.projects }
        let q = projectSearchText.lowercased()
        return vault.projects.filter {
            $0.name.lowercased().contains(q) ||
            ($0.path?.lowercased().contains(q) ?? false)
        }
    }

    private var selectedEnvironmentName: String {
        vault.selectedEnvironment?.name ?? "No environment"
    }

    private var environmentCards: [DashboardEnvironment] {
        vault.environments.map { environment in
            DashboardEnvironment(
                id: environment.id,
                name: environment.name,
                color: Theme.color(hex: environment.color),
                count: vault.environmentSecretCounts[environment.id] ?? 0,
                isActive: vault.activeEnvironmentName == environment.name
            )
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
        .onChange(of: vault.secrets) { _, newSecrets in
            guard let selected = selectedSecret else { return }
            let updated = newSecrets.first { $0.id == selected.id }
            selectedSecret = updated
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
        .frame(minWidth: 980, minHeight: 620)
    }

    // MARK: - Root Layout

    private var dashboard: some View {
        HStack(spacing: 0) {
            redesignedSidebar
                .frame(width: 245)
            Divider().overlay(Theme.sep)
            if showingActivity {
                ActivityView()
                    .environment(vault)
            } else {
                mainDashboard
            }
        }
        .background {
            Group {
                Button("") { projectSearchFocused = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button("") { secretSearchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
            }
            .hidden()
        }
    }

    private var redesignedSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Lokalite")
                    .font(Theme.mono(20, .semibold))
                    .foregroundStyle(Theme.text)
                DevBadge()
            }
            .padding(.top, 28)
            .padding(.horizontal, 20)

            DashboardSearchField(
                placeholder: "Search projects...",
                text: $projectSearchText,
                shortcut: "⌘K",
                isFocused: $projectSearchFocused
            )
            .padding(.horizontal, 20)
            .padding(.top, 18)

            HStack {
                Text("Projects")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                Spacer()
                Menu {
                    Button("New project") {
                        presentedSheet = .projectAppearance(nil)
                    }
                    Button("Import from .env…") {
                        beginImportFromEnv(mode: .createProject)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(Theme.textMuted)
                .help("New project")
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(filteredProjects) { project in
                        DashboardProjectRow(
                            project: project,
                            isSelected: !showingActivity && vault.selectedProject?.id == project.id,
                            onSelect: {
                                selectedSecret = nil
                                showingActivity = false
                                vault.selectProject(project)
                            }
                        )
                        .contextMenu {
                            Button("Import from .env…") {
                                selectedSecret = nil
                                showingActivity = false
                                vault.selectProject(project)
                                beginImportFromEnv(mode: .existingProject(project))
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer()

            Divider()
                .overlay(Theme.sep)
                .padding(.horizontal, 14)

            Button {
                showingActivity = true
            } label: {
                Label("Activity", systemImage: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(showingActivity ? Theme.brand : Theme.text)
            .padding(.top, 6)

            Button {
                presentedSheet = .appSettings
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.text)
            .padding(.bottom, 8)
        }
        .background(Theme.sidebarBackground)
    }

    private var mainDashboard: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader
            tabContent
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case "Environments":
            EnvironmentsTab()
                .environment(vault)
        case "Secrets":
            SecretsTab(
                onEdit: { presentedSheet = .editSecret($0) },
                onMove: { presentedSheet = .moveSecret($0) },
                onDelete: { deletingSecret = $0 },
                onAdd: { presentedSheet = .addSecret }
            )
            .environment(vault)
        case "Settings":
            ProjectSettingsTab(
                onEditAppearance: { presentedSheet = .projectAppearance(vault.selectedProject) },
                onDelete: { deletingProject = vault.selectedProject }
            )
            .environment(vault)
        default:
            overviewContent
        }
    }

    private var overviewContent: some View {
        GeometryReader { proxy in
            ScrollView {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 26) {
                        environmentsSection
                        secretsSection
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    Rectangle()
                        .fill(Theme.sep)
                        .frame(width: 1)
                        .padding(.vertical, 4)

                    overviewSideColumn
                        .frame(width: min(proxy.size.width * 0.25, 300))
                }
                .padding(.horizontal, 36)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
        }
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
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(["Overview", "Environments", "Secrets", "Settings"], id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 10) {
                                HStack(spacing: 7) {
                                    Image(systemName: tabIcon(tab))
                                        .font(.system(size: 13, weight: .medium))
                                    Text(tab)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                Rectangle()
                                    .fill(selectedTab == tab ? Theme.brand : .clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selectedTab == tab ? Theme.text : Theme.textMuted)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 0)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.sep)
                .frame(height: 1)
        }
    }

    // MARK: - Sections

    private var environmentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Environments")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                BorderedActionButton(action: { selectedTab = "Environments" }) {
                    Label("Manage", systemImage: "arrow.right")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(environmentCards) { environment in
                        EnvironmentSummaryCard(environment: environment) {
                            if let match = vault.environments.first(where: { $0.id == environment.id }) {
                                vault.makeEnvironmentActive(match)
                            }
                        }
                        .frame(width: 210)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var secretsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Secrets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                DashboardSearchField(
                    placeholder: "Search secrets...",
                    text: $searchText,
                    shortcut: "⌘F",
                    isFocused: $secretSearchFocused
                )
                .frame(width: 200)
            }

        if filteredSecrets.isEmpty {
                emptySecretsPanel
        } else {
                DashboardSecretsTable(
                    secrets: filteredSecrets,
                    environmentNames: vault.secretEnvironmentNames,
                    environmentColors: vault.environmentColors,
                    selectedEnvironmentName: selectedEnvironmentName,
                    selectedSecret: selectedSecret,
                    showActions: false,
                    onSelect: { vault.copyToClipboard($0) },
                    onCopy: { vault.copyToClipboard($0) },
                    onEdit: { _ in },
                    onMove: { _ in },
                    onDelete: { _ in }
                )
                SecretShortcutRow(onNewSecret: { presentedSheet = .addSecret })
            }
        }
    }

    private var emptySecretsPanel: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(Theme.textDim)
            Text(searchText.isEmpty ? "No secrets in \(selectedEnvironmentName)" : "No matching secrets")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Button {
                presentedSheet = .addSecret
            } label: {
                Label("New secret", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
    }

    private var overviewSideColumn: some View {
        VStack(spacing: 14) {
            ProjectInfoPanel(project: vault.selectedProject, environmentCount: vault.environments.count, secretCount: vault.projectSecretCount)
            DeveloperActionsPanel()
            MCPPanel()
        }
    }

    // MARK: - States

    private var lockedView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.brand.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Theme.brand)
            }

            VStack(spacing: 7) {
                Text("Lokalite")
                    .font(Theme.mono(20, .semibold))
                    .foregroundStyle(Theme.text)
                Text("Vault locked. Unlock to reach your projects and secrets.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
            }

            Button("Unlock") {
                vault.unlock()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var onboardingView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Welcome to Lokalite")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text("Create a project to start storing secrets by environment.")
                    .font(.body)
                    .foregroundStyle(Theme.textMuted)
            }
            VStack(spacing: 10) {
                Button("Create your first project") {
                    presentedSheet = .projectAppearance(nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
                .controlSize(.large)

                Button("Import from .env") {
                    beginImportFromEnv(mode: .createProject)
                }
                .buttonStyle(.link)
                .help("Pick an existing .env file (or its folder) to create a project from it")
            }
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

    private func tabIcon(_ tab: String) -> String {
        switch tab {
        case "Overview": return "square.grid.2x2"
        case "Environments": return "cube"
        case "Secrets": return "lock"
        default: return "gearshape"
        }
    }
}
