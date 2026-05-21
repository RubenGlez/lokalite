import AppKit
import SwiftUI
import LokaliteCore

struct VaultPopover: View {
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""

    private var filtered: [Secret] {
        guard !searchText.isEmpty else { return vault.secrets }
        let q = searchText.lowercased()
        return vault.secrets.filter {
            $0.name.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) } ||
            ($0.description?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
        .onAppear { vault.unlock() }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search secrets…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if vault.isLocked {
            lockedView
        } else if vault.secrets.isEmpty {
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
        .frame(maxHeight: 400)
    }

    private var lockedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Vault locked")
                .foregroundStyle(.secondary)
            Button("Unlock") { vault.unlock() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "key")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No secrets yet")
                .foregroundStyle(.secondary)
            Button("Add your first secret") {
                openManageWindow()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var noResultsView: some View {
        Text("No results for \"\(searchText)\"")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(24)
    }

    private func openManageWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }

    private var footer: some View {
        HStack {
            Button {
                openManageWindow()
            } label: {
                Label("Manage Secrets", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                vault.lock()
            } label: {
                Image(systemName: "lock")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Lock vault")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
