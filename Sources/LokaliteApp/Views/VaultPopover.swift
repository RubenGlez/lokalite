import AppKit
import SwiftUI
import LokaliteCore

struct VaultPopover: View {
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var selectedTag: String?

    private var allTags: [String] {
        Array(Set(vault.secrets.flatMap(\.tags))).sorted()
    }

    private var filtered: [Secret] {
        var results = vault.secrets
        if let tag = selectedTag {
            results = results.filter { $0.tags.contains(tag) }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(q) ||
                $0.tags.contains { $0.lowercased().contains(q) } ||
                ($0.description?.lowercased().contains(q) ?? false)
            }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if !allTags.isEmpty {
                Divider()
                tagFilter
            }
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
        .onAppear { vault.unlock() }
        .onDisappear { vault.lock() }
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
        .padding(.vertical, 10)
    }

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allTags, id: \.self) { tag in
                    let active = selectedTag == tag
                    Button {
                        selectedTag = active ? nil : tag
                    } label: {
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(active ? Color.accentColor : Color.accentColor.opacity(0.12))
                            .foregroundStyle(active ? .white : Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
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
            ProgressView()
            Text("Authenticating…")
                .foregroundStyle(.secondary)
                .font(.callout)
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
                Label("Manage Secrets", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func openManageWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}
