import AppKit
import SwiftUI
import LokaliteCore

struct VaultPopover: View {
    @Environment(VaultViewModel.self) private var vault
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
            AddSecretView()
                .environment(vault)
        }
    }

    private var lockedStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.gold)
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
            .tint(Theme.gold)
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
        Theme.color(hex: vault.selectedEnvironment?.color)
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
        List(filtered) { secret in
            SecretRowView(secret: secret)
                .environment(vault)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
