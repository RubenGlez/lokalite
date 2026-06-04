import AppKit
import SwiftUI
import LokaliteCore

struct VaultPopover: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var showingAddSecret = false
    @FocusState private var searchFocused: Bool

    private var filtered: [Secret] {
        guard !searchText.isEmpty else { return vault.secrets }
        let q = searchText.lowercased()
        return vault.secrets.filter {
            $0.name.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            $0.category.label.lowercased().contains(q)
        }
    }

    private var recentSecrets: [Secret] {
        let recents = vault.recentSecretNames.compactMap { name in
            vault.secrets.first { $0.name == name }
        }
        return recents.isEmpty ? Array(vault.secrets.prefix(4)) : recents
    }

    var body: some View {
        VStack(spacing: 0) {
            if vault.isLocked {
                lockedStateView
            } else {
                unlockedStateView
            }
        }
        .frame(minWidth: 360, maxWidth: 360, minHeight: 230)
        .preferredColorScheme(vault.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: vault.isLocked)
        .onAppear {
            vault.unlock()
            if !vault.isLocked { Task { @MainActor in searchFocused = true } }
        }
        .onChange(of: vault.isLocked) { _, locked in
            if !locked { Task { @MainActor in searchFocused = true } }
        }
        .onDisappear { showingAddSecret = false }
        .alert("Error", isPresented: Binding(
            get: { vault.errorMessage != nil },
            set: { if !$0 { vault.errorMessage = nil } }
        )) {
            Button("OK") { vault.errorMessage = nil }
        } message: {
            Text(vault.errorMessage ?? "")
        }
        .sheet(isPresented: $showingAddSecret) {
            AddSecretView()
                .environment(vault)
        }
    }

    private var lockedStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Theme.panelBackground)
                    .frame(width: 48, height: 48)
                Text("L")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }

            VStack(spacing: 6) {
                Text("Workspace locked")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Unlock to search projects and environments")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button("Unlock") {
                vault.unlock()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .controlSize(.small)
            
            Spacer()
        }
    }

    private var unlockedStateView: some View {
        VStack(spacing: 0) {
            contextHeader
            Divider()
            searchBar
            Divider()
            content
            Divider()
            footer
        }
        .background(Theme.panelBackground)
    }

    private var contextHeader: some View {
        HStack(spacing: 5) {
            // Project switcher
            Menu {
                ForEach(vault.projects) { project in
                    Button { vault.selectProject(project) } label: {
                        let icon = project.icon ?? "folder"
                        if icon.unicodeScalars.allSatisfy({ $0.value < 128 }) {
                            Label(project.name, systemImage: icon)
                        } else {
                            Text("\(icon)  \(project.name)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    let projectIcon = vault.selectedProject?.icon ?? "folder"
                    if projectIcon.unicodeScalars.allSatisfy({ $0.value < 128 }) {
                        Image(systemName: projectIcon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(projectIcon)
                            .font(.system(size: 13))
                    }
                    Text(vault.selectedProject?.name ?? "No project")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(vault.projects.isEmpty)

            Image(systemName: "chevron.forward")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)

            // Environment switcher
            Menu {
                Button {
                    vault.selectEnvironment(nil)
                } label: {
                    Label { Text("Default") } icon: { Theme.envCircle(.white.opacity(0.7)) }
                }
                if !vault.environments.isEmpty {
                    Divider()
                    ForEach(vault.environments, id: \.id) { env in
                        Button { vault.selectEnvironment(env) } label: {
                            Label { Text(env.name) } icon: { Theme.envCircle(Theme.color(hex: env.color)) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Theme.envCircle(environmentColor)
                    Text(vault.selectedEnvironment?.name ?? "Default")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(vault.selectedProject == nil)

            Spacer()

            Button {
                showingAddSecret = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.brand)
            .disabled(vault.selectedProject == nil)
            .keyboardShortcut("n", modifiers: .command)
            .help("New secret")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var environmentColor: Color {
        vault.selectedEnvironment.map { Theme.color(hex: $0.color) } ?? .white.opacity(0.7)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search secrets...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.035), in: .rect(cornerRadius: 7))
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if vault.secrets.isEmpty {
            emptyView
        } else if filtered.isEmpty {
            noResultsView
        } else {
            recentsList
        }
    }

    private var recentsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(searchText.isEmpty ? "Recent" : "Results")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textMuted)
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(searchText.isEmpty ? recentSecrets : filtered) { secret in
                    PopoverRecentSecretRow(
                        project: vault.selectedProject?.name ?? "Lokalite",
                        environment: vault.selectedEnvironment?.name ?? vault.selectedProject?.activeEnvironment ?? "default",
                        secret: secret
                    ) {
                        vault.copyToClipboard(secret)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(minHeight: 210, maxHeight: 330, alignment: .top)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Secrets", systemImage: "key")
        } actions: {
            Button("Add your first secret") {
                showingAddSecret = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var noResultsView: some View {
        ContentUnavailableView.search(text: searchText)
            .frame(maxWidth: .infinity)
            .padding(24)
    }

    private var footer: some View {
        HStack {
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit Lokalite")
                    .font(.system(size: 13, weight: .medium))
                    .frame(minHeight: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.text)
            .keyboardShortcut("q", modifiers: .command)

            Spacer()

            Text("⌘Q")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05), in: .rect(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func openManageWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}

private struct PopoverRecentSecretRow: View {
    let project: String
    let environment: String
    let secret: Secret
    let action: () -> Void
    @State private var copied = false

    var body: some View {
        Button(action: copyWithFeedback) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.brand.opacity(0.15))
                    Image(systemName: secret.category.systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.brand)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(project) / \(environment)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(secret.name)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                if copied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: copied)
        .contextMenu {
            Button("Copy", action: copyWithFeedback)
        }
    }

    private func copyWithFeedback() {
        action()
        withAnimation { copied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { copied = false }
        }
    }

}
