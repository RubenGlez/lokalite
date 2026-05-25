import AppKit
import SwiftUI
import LokaliteCore

struct VaultPopover: View {
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var showingAddSecret = false

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
        .onAppear { vault.unlock() }
        .onDisappear { showingAddSecret = false }
        .sheet(isPresented: $showingAddSecret) {
            AddSecretView {
                showingAddSecret = false
            }
                .environmentObject(vault)
        }
    }

    private var lockedStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(red: 0.910, green: 0.627, blue: 0.118).opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.910, green: 0.627, blue: 0.118))
            }
            
            VStack(spacing: 6) {
                Text("Vault is Locked")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Unlock to view your secrets")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Button {
                vault.unlock()
            } label: {
                Text("Unlock")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.910, green: 0.627, blue: 0.118))
                    )
            }
            .buttonStyle(.plain)
            
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
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                Text(vault.selectedProject?.name ?? "No project")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Circle()
                    .fill(environmentColor)
                    .frame(width: 6, height: 6)
                Text(vault.selectedEnvironment?.name ?? "Default")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button {
                showingAddSecret = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(vault.selectedProject == nil)
            .keyboardShortcut("n", modifiers: .command)
            .help("New secret")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var environmentColor: Color {
        switch vault.selectedEnvironment?.color {
        case "#57A2FF": return Color(red: 0.341, green: 0.635, blue: 1.000)
        case "#51DBC1": return Color(red: 0.318, green: 0.859, blue: 0.757)
        case "#A885FF": return Color(red: 0.659, green: 0.522, blue: 1.000)
        case "#FF749F": return Color(red: 1.000, green: 0.455, blue: 0.647)
        case "#FF9A49": return Color(red: 1.000, green: 0.604, blue: 0.286)
        case "#4CD964": return Color(red: 0.302, green: 0.847, blue: 0.569)
        default: return Color(red: 0.910, green: 0.627, blue: 0.118)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search secrets…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered, id: \.id) { secret in
                    SecretRowView(secret: secret)
                    if secret.id != filtered.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .frame(minHeight: 110, maxHeight: 420)
    }



    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "key")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No secrets yet")
                .foregroundStyle(.secondary)
            Button("Add your first secret") {
                showingAddSecret = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var noResultsView: some View {
        Text("No results")
            .foregroundStyle(.secondary)
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
