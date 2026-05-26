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

    var body: some View {
        VStack(spacing: 0) {
            if vault.isLocked {
                lockedStateView
            } else {
                unlockedStateView
            }
        }
        .frame(minWidth: 340, maxWidth: 340, minHeight: 230)
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
                    .fill(Theme.brand.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.brand)
            }

            VStack(spacing: 6) {
                Text("Vault is Locked")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Unlock to view your secrets")
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
            TextField("Search secrets…", text: $searchText)
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
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if vault.secrets.isEmpty {
            emptyView
        } else if filtered.isEmpty {
            noResultsView
        } else {
            secretsList
        }
    }

    private var secretsList: some View {
        List(filtered) { secret in
            SecretRowView(secret: secret)
                .environment(vault)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 110, maxHeight: 420)
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
                openManageWindow()
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.caption)
                    .frame(minWidth: 56, minHeight: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.caption)
                    .frame(width: 24, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit Lokalite")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func openManageWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}
