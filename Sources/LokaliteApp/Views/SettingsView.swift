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
    static let controlHeight: CGFloat = 30
    static let rowHeight: CGFloat = 44
    static let brand      = Color(red: 0.349, green: 0.722, blue: 0.369)
    static let brandSubtle = brand.opacity(0.12)
    static let neutralSubtle = Color.white.opacity(0.06)
    static let sep        = Color(red: 0.102, green: 0.129, blue: 0.157)
    static let windowBackground = Color(red: 0.039, green: 0.055, blue: 0.075)
    static let sidebarBackground = Color(red: 0.075, green: 0.094, blue: 0.114)
    static let panelBackground = sidebarBackground
    static let text       = Color(red: 0.961, green: 0.961, blue: 0.961)
    static let textMuted  = Color(red: 0.627, green: 0.627, blue: 0.627)
    static let textDim    = Color(red: 0.420, green: 0.420, blue: 0.420)
    static let bgHigh     = Color.white.opacity(0.055)
    static let red        = Color(red: 1.000, green: 0.482, blue: 0.447)
    static let green      = brand
    static let blue       = Color(red: 0.427, green: 0.686, blue: 0.945)
    static let mint       = Color(red: 0.384, green: 0.824, blue: 0.765)
    static let violet     = Color(red: 0.608, green: 0.529, blue: 0.945)
    static let pink       = Color(red: 0.929, green: 0.522, blue: 0.690)
    static let orange     = Color(red: 0.949, green: 0.800, blue: 0.376)
    static let amber      = Color(red: 0.925, green: 0.635, blue: 0.365)
    static let slate      = Color(red: 0.565, green: 0.624, blue: 0.690)

    static let environmentPalette = ["#6DAFF1", "#F2CC60", "#FF7B72", "#9B87F1", "#ED85B0", "#ECB15D", "#62D2C3", "#909FAF"]

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
        guard let hex else { return brand }
        switch hex {
        case "#6DAFF1", "#8FD3FF": return blue
        case "#F2CC60": return orange
        case "#FF7B72": return red
        case "#9B87F1": return violet
        case "#ED85B0": return pink
        case "#ECB15D": return amber
        case "#62D2C3": return mint
        case "#909FAF": return slate
        case "#A0A0A0": return textMuted
        default: return brand
        }
    }
}


// MARK: - Shared control helpers

private struct BorderedActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(height: Theme.controlHeight)
                .padding(.horizontal, 10)
                .background(Theme.bgHigh, in: .rect(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.sep, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
    @State private var selectedTab = "Overview"
    @State private var projectSearchText = ""

    private enum PresentedSheet: Identifiable {
        case addSecret
        case appSettings
        case editSecret(Secret)
        case moveSecret(Secret)
        case projectAppearance(Project?)
        case environmentAppearance(VaultEnvironment)

        var id: String {
            switch self {
            case .addSecret: "add-secret"
            case .appSettings: "app-settings"
            case .editSecret(let secret): "edit-secret-\(secret.id)"
            case .moveSecret(let secret): "move-secret-\(secret.id)"
            case .projectAppearance(let project): "project-\(project?.id ?? "new")"
            case .environmentAppearance(let environment): "environment-\(environment.id)"
            }
        }
    }

    // Presentation
    @State private var presentedSheet: PresentedSheet?

    // Search
    @State private var searchText = ""
    @FocusState private var projectSearchFocused: Bool
    @FocusState private var secretSearchFocused: Bool

    // Copy shell export feedback
    @State private var shellExportCopied = false

    // Delete confirmations
    @State private var deletingProject: Project?
    @State private var deletingEnv: VaultEnvironment?
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
        vault.selectedEnvironment?.name ?? vault.selectedProject?.activeEnvironment ?? "default"
    }

    private var environmentCards: [DashboardEnvironment] {
        var cards = [
            DashboardEnvironment(
                id: "default",
                name: "default",
                color: .white.opacity(0.7),
                count: vault.environmentSecretCounts["default"] ?? 0,
                isActive: vault.selectedEnvironment == nil
            )
        ]

        cards += vault.environments.map { environment in
            DashboardEnvironment(
                id: environment.id,
                name: environment.name,
                color: Theme.color(hex: environment.color),
                count: vault.environmentSecretCounts[environment.id] ?? 0,
                isActive: vault.selectedEnvironment?.id == environment.id
            )
        }

        return cards
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
        }
        .onChange(of: vault.isLocked) { _, isLocked in
            if isLocked {
                presentedSheet = nil
                deletingProject = nil
                deletingEnv = nil
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
                AppSettingsView().environment(vault)
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
        .frame(minWidth: 980, minHeight: 620)
    }

    // MARK: - Root Layout

    private var dashboard: some View {
        HStack(spacing: 0) {
            redesignedSidebar
                .frame(width: 245)
            Divider().overlay(Theme.sep)
            mainDashboard
        }
        .background {
            Group {
                Button("") { projectSearchFocused = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button("") { secretSearchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                Button("") { copyShellExport() }
                    .keyboardShortcut("e", modifiers: .command)
            }
            .hidden()
        }
    }

    private var redesignedSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lokalite")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
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
                Button {
                    presentedSheet = .projectAppearance(nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
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
                            isSelected: vault.selectedProject?.id == project.id,
                            onSelect: {
                                selectedSecret = nil
                                vault.selectProject(project)
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer()

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

            Divider().overlay(Theme.sep)
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 7, height: 7)
                Text("Lokalite CLI")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Text("v1.2.0")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
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
        case "Activity":
            ActivityTab()
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
                    .frame(width: 235)
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)
            .padding(.bottom, 28)
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
                    ForEach(["Overview", "Environments", "Secrets", "Activity", "Settings"], id: \.self) { tab in
                        Button {
                            handleTab(tab)
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
                            if environment.id == "default" {
                                vault.selectEnvironment(nil)
                            } else if let match = vault.environments.first(where: { $0.id == environment.id }) {
                                vault.selectEnvironment(match)
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
                    environmentColors: Dictionary(uniqueKeysWithValues: vault.environments.map { ($0.name, Theme.color(hex: $0.color)) }),
                    selectedEnvironmentName: selectedEnvironmentName,
                    selectedSecret: selectedSecret,
                    showActions: false,
                    onSelect: { vault.copyToClipboard($0) },
                    onCopy: { vault.copyToClipboard($0) },
                    onEdit: { _ in },
                    onMove: { _ in },
                    onDelete: { _ in }
                )
                SecretShortcutRow(onNewSecret: { presentedSheet = .addSecret }, shellExportCopied: shellExportCopied)
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
        VStack(spacing: 16) {
            Text("Lokalite")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Unlock your local workspace context.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
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
            Button("Create your first project") {
                presentedSheet = .projectAppearance(nil)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func handleTab(_ tab: String) {
        selectedTab = tab
    }

    private func tabIcon(_ tab: String) -> String {
        switch tab {
        case "Overview": return "square.grid.2x2"
        case "Environments": return "cube"
        case "Secrets": return "lock"
        case "Activity": return "clock"
        default: return "gearshape"
        }
    }

    private func copyShellExport() {
        let envFlag = vault.selectedEnvironment.map { "--env \($0.name)" } ?? ""
        let cmd = "eval $(lokalite shell\(envFlag.isEmpty ? "" : " \(envFlag)"))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        shellExportCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            shellExportCopied = false
        }
    }

    private func shortPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }
}

// MARK: - Dashboard Components

private struct DashboardEnvironment: Identifiable {
    let id: String
    let name: String
    let color: Color
    let count: Int
    let isActive: Bool
}

private struct DashboardSearchField: View {
    let placeholder: String
    @Binding var text: String
    let shortcut: String
    var isFocused: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textMuted)
            if let isFocused {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused(isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            Text(shortcut)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textDim)
        }
        .padding(.horizontal, 9)
        .frame(height: Theme.controlHeight)
        .background(Color.white.opacity(0.045), in: .rect(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.sep, lineWidth: 1))
    }
}

private struct DashboardProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                projectIcon
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(shortPath(project.path) ?? "Not linked")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: Theme.rowHeight)
            .background(rowBackground, in: .rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private var projectIcon: some View {
        let color = project.path == nil ? Theme.textMuted : Theme.green
        let icon = project.icon ?? "folder"
        if icon.unicodeScalars.allSatisfy({ $0.value < 128 }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
        } else {
            Text(icon)
                .font(.system(size: 15))
                .foregroundStyle(project.path == nil ? .secondary : .primary)
        }
    }

    private var rowBackground: Color {
        if isSelected { return Color.white.opacity(0.10) }
        if isHovered { return Color.white.opacity(0.05) }
        return .clear
    }

    private func shortPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }
}

private struct MainProjectIcon: View {
    let project: Project?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Theme.green.opacity(0.18))
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Theme.green.opacity(0.28), lineWidth: 1)
            projectIcon
        }
        .frame(width: 52, height: 52)
    }

    @ViewBuilder
    private var projectIcon: some View {
        let icon = project?.icon ?? "folder"
        if icon.unicodeScalars.allSatisfy({ $0.value < 128 }) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Theme.green)
        } else {
            Text(icon)
                .font(.system(size: 25))
        }
    }
}

private struct EnvironmentSummaryCard: View {
    let environment: DashboardEnvironment
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(environment.color)
                        .frame(width: 6, height: 6)
                    Text(environment.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    if environment.isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.green.opacity(0.13), in: .rect(cornerRadius: 5))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(environment.count) secret\(environment.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardSecretsTable: View {
    let secrets: [Secret]
    let environmentNames: [String: [String]]
    let environmentColors: [String: Color]
    let selectedEnvironmentName: String
    let selectedSecret: Secret?
    var showActions: Bool = true
    let onSelect: (Secret) -> Void
    let onCopy: (Secret) -> Void
    let onEdit: (Secret) -> Void
    let onMove: (Secret) -> Void
    let onDelete: (Secret) -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    DashboardSecretHeader()
                        .background(Theme.sidebarBackground)

                    Divider()
                        .overlay(Theme.sep)

                    VStack(spacing: 0) {
                        ForEach(secrets) { secret in
                            DashboardSecretRow(
                                secret: secret,
                                environments: environmentNames[secret.name] ?? [selectedEnvironmentName],
                                environmentColors: environmentColors,
                                isSelected: selectedSecret?.id == secret.id,
                                showActions: showActions,
                                onSelect: { onSelect(secret) },
                                onCopy: { onCopy(secret) },
                                onEdit: { onEdit(secret) },
                                onMove: { onMove(secret) },
                                onDelete: { onDelete(secret) }
                            )
                            if secret.id != secrets.last?.id {
                                Divider()
                                    .overlay(Theme.sep)
                            }
                        }
                    }
                    .background(Theme.windowBackground)
                }
                .frame(width: max(proxy.size.width, 660), alignment: .topLeading)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: CGFloat(secrets.count) * Theme.rowHeight + 37)
    }
}

private struct SecretShortcutRow: View {
    let onNewSecret: () -> Void
    let shellExportCopied: Bool

    var body: some View {
        HStack(spacing: 72) {
            Button(action: onNewSecret) {
                ShortcutHint(keys: "⌘N", title: "New secret")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)

            ShortcutHint(
                keys: "⌘E",
                title: shellExportCopied ? "Copied!" : "Copy shell export"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

private struct ShortcutHint: View {
    let keys: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(keys)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.windowBackground, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.sep, lineWidth: 1))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textMuted)
        }
    }
}

private struct DashboardSecretHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Environment").frame(width: 190, alignment: .leading)
            Color.clear.frame(width: 28)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Theme.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, 16)
        .frame(height: 36)
    }
}

private struct DashboardSecretRow: View {
    let secret: Secret
    let environments: [String]
    let environmentColors: [String: Color]
    let isSelected: Bool
    var showActions: Bool = true
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var copied = false

    var body: some View {
        Button(action: showActions ? onSelect : copyWithFeedback) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(secret.name)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if copied {
                        Label("Copied", systemImage: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.brand)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.15), value: copied)

                HStack(spacing: 5) {
                    ForEach(Array(environments.prefix(3)), id: \.self) { environment in
                        Text(environment)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(pillColor(environment))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(pillColor(environment).opacity(0.16), in: .rect(cornerRadius: 5))
                    }
                }
                .frame(width: 190, alignment: .leading)

                if showActions {
                    Menu {
                        Button("Copy", action: onCopy)
                        Divider()
                        Button("Edit...", action: onEdit)
                        Button("Move...", action: onMove)
                        Divider()
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .opacity(isHovered || isSelected ? 1 : 0.7)
                } else {
                    Color.clear.frame(width: 28, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Theme.rowHeight)
            .background(isSelected ? Color.white.opacity(0.055) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
        .contextMenu {
            Button("Copy", action: showActions ? onCopy : copyWithFeedback)
            if showActions {
                Divider()
                Button("Edit...", action: onEdit)
                Button("Move...", action: onMove)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
    }

    private func copyWithFeedback() {
        onCopy()
        withAnimation { copied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { copied = false }
        }
    }

    private func pillColor(_ name: String) -> Color {
        environmentColors[name] ?? Theme.green
    }
}

private struct ProjectInfoPanel: View {
    let project: Project?
    let environmentCount: Int
    let secretCount: Int

    var body: some View {
        InspectorCard(title: "Project Info") {
            VStack(alignment: .leading, spacing: 15) {
                InfoLine(icon: "folder", title: "Linked folder", value: shortPath(project?.path) ?? "Not linked")
                InfoLine(icon: "point.3.connected.trianglepath.dotted", title: "Repository", value: "Not configured")
                InfoLine(icon: "square.stack.3d.up", title: "\(environmentCount + 1) environments", value: nil)
                InfoLine(icon: "lock", title: "\(secretCount) secrets", value: nil)
                InfoLine(icon: "clock", title: "Created", value: "Local vault")
            }
        }
    }

    private func shortPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }
}


private struct CopyableCommandLine: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            copy()
        } label: {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer()
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(copied ? Theme.green : Theme.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(copied ? 0.070 : 0.045), in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(copied ? Theme.green.opacity(0.35) : Theme.sep, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(copied ? "Copied" : "Copy command")
        .animation(.easeInOut(duration: 0.15), value: copied)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            copied = false
        }
    }
}

private struct MCPPanel: View {
    @State private var isInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MCP Server")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                StatusBadge(installed: isInstalled)
            }

            Text("Use Lokalite from your agents and tools.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)

            CopyableCommandLine(text: "lokalite install")

            Divider().overlay(Theme.sep)

            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/RubenGlez/lokalite")!)
            } label: {
                HStack {
                    Text("Documentation")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Text("Learn how to connect your agents.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
        .onAppear { isInstalled = checkMCPInstalled() }
    }

    private func checkMCPInstalled() -> Bool {
        let claudeConfig = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: claudeConfig),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any] else { return false }
        return servers["lokalite"] != nil
    }
}

private struct DeveloperActionsPanel: View {
    @State private var isInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CLI")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                StatusBadge(installed: isInstalled)
            }

            Text("Use Lokalite from terminals and local tools.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)

            VStack(alignment: .leading, spacing: 9) {
                CopyableCommandLine(text: "lokalite status")
                CopyableCommandLine(text: "lokalite shell --env production")
                CopyableCommandLine(text: "lokalite run -- npm run dev")
            }

            Divider().overlay(Theme.sep)

            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/RubenGlez/lokalite")!)
            } label: {
                HStack {
                    Text("Documentation")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Text("Learn how to use the CLI.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
        .onAppear { isInstalled = checkCLIInstalled() }
    }

    private func checkCLIInstalled() -> Bool {
        let paths = ["/usr/local/bin/lokalite", "/opt/homebrew/bin/lokalite", "/usr/bin/lokalite"]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }
}

private struct StatusBadge: View {
    let installed: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(installed ? Theme.green : Theme.textDim)
                .frame(width: 6, height: 6)
            Text(installed ? "Installed" : "Not installed")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(installed ? Theme.green : Theme.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((installed ? Theme.green : Theme.textDim).opacity(0.13), in: .rect(cornerRadius: 5))
    }
}

private struct InspectorCard<Content: View>: View {
    let title: String
    let accessory: String?
    @ViewBuilder let content: Content

    init(title: String, accessory: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if let accessory {
                    Text(accessory)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 5))
                }
            }
            content
        }
        .padding(16)
        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
    }
}

private struct InfoLine: View {
    let icon: String
    let title: String
    let value: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                if let value {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.blue)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Identity

private struct IdentityBadge: View {
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

private struct CategoryPill: View {
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

private struct ProjectAppearanceView: View {
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
    }
}

private struct EnvironmentEditorRow: View {
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

private struct SecretRow: View {
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

                    Picker("Appearance", selection: Binding(
                        get: { vault.appearanceMode },
                        set: { vault.appearanceMode = $0 }
                    )) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    Picker("Global Shortcut", selection: Binding(
                        get: { vault.hotkeyShortcutID },
                        set: { vault.hotkeyShortcutID = $0 }
                    )) {
                        ForEach(GlobalHotkeyManager.Shortcut.allOptions, id: \.id) { shortcut in
                            Text(shortcut.displayName).tag(shortcut.id)
                        }
                    }
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
        .frame(width: 440, height: 360)
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
                IdentityBadge(icon: secret.category.defaultIcon, color: .white, size: 38)
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
                            .foregroundStyle(Theme.brand)
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

// MARK: - Environments Tab

private struct EnvironmentsTab: View {
    @Environment(VaultViewModel.self) private var vault
    @State private var newName = ""
    @State private var newColor = Theme.environmentPalette[0]
    @State private var editingEnvironment: VaultEnvironment?
    @State private var deletingEnvironment: VaultEnvironment?

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
                            .background(Color.white.opacity(0.045), in: .rect(cornerRadius: 7))
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
                if let e = deletingEnvironment { vault.deleteEnvironment(e) }
                deletingEnvironment = nil
            }
            Button("Cancel", role: .cancel) { deletingEnvironment = nil }
        } message: { Text("This cannot be undone.") }
    }
}

private struct EnvironmentTabRow: View {
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

private struct SecretsTab: View {
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
        vault.selectedEnvironment?.name ?? vault.selectedProject?.activeEnvironment ?? "default"
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
                            environmentColors: Dictionary(uniqueKeysWithValues: vault.environments.map { ($0.name, Theme.color(hex: $0.color)) }),
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

// MARK: - Activity Tab

private struct ActivityTab: View {
    @Environment(VaultViewModel.self) private var vault

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Activity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 36)
                .padding(.top, 24)
                .padding(.bottom, 16)

            if vault.activityEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.textDim)
                    Text("No activity yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Secrets accessed via the app, CLI, or MCP will appear here.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .padding(.bottom, 28)
                }
            }
        }
    }
}

private struct ActivityRow: View {
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
                Text(entry.secretName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(entry.projectName) / \(entry.environmentName)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(sourceLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(sourceColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sourceColor.opacity(0.13), in: .rect(cornerRadius: 4))
                Text(relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Theme.rowHeight)
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

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.accessedAt, relativeTo: Date())
    }
}

// MARK: - Project Settings Tab

private struct ProjectSettingsTab: View {
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

                settingsRow(label: "Linked folder") {
                    HStack(spacing: 8) {
                        Text(shortPath(path) ?? "Not linked")
                            .font(.system(size: 13))
                            .foregroundStyle(path.isEmpty ? Theme.textDim : Theme.blue)
                            .lineLimit(1)
                        Button {
                            pickDirectory()
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
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

    private func shortPath(_ p: String) -> String? {
        guard !p.isEmpty else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return p.replacingOccurrences(of: home, with: "~")
    }
}

