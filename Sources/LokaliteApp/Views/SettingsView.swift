import SwiftUI
import LokaliteCore

struct SettingsView: View {
    @EnvironmentObject private var vault: VaultViewModel
    @State private var selected: Secret?
    @State private var showingAdd = false
    @State private var searchText = ""

    private var filtered: [Secret] {
        guard !searchText.isEmpty else { return vault.secrets }
        let q = searchText.lowercased()
        return vault.secrets.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New secret")
            }
        }
        .onAppear {
            if vault.isLocked { vault.unlock() }
        }
        .sheet(isPresented: $showingAdd) {
            AddSecretView()
                .environmentObject(vault)
        }
    }

    private var sidebar: some View {
        List(filtered, id: \.id, selection: $selected) { secret in
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name)
                    .font(.system(.body, design: .monospaced))
                if let desc = secret.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .tag(secret)
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Filter secrets")
        .navigationTitle("Secrets")
    }

    @ViewBuilder
    private var detail: some View {
        if let secret = selected {
            SecretDetailView(secret: secret)
                .environmentObject(vault)
                .id(secret.id)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "key")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("Select a secret")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct SecretDetailView: View {
    let secret: Secret
    @EnvironmentObject private var vault: VaultViewModel
    @State private var editingValue = ""
    @State private var revealed = false
    @State private var saved = false
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section("Name") {
                Text(secret.name)
                    .font(.system(.body, design: .monospaced))
            }

            Section("Value") {
                HStack {
                    if revealed {
                        TextField("Value", text: $editingValue)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("Value", text: $editingValue)
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

            if let desc = secret.description {
                Section("Description") {
                    Text(desc).foregroundStyle(.secondary)
                }
            }

            if !secret.tags.isEmpty {
                Section("Tags") {
                    HStack {
                        ForEach(secret.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { editingValue = secret.value }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                Button("Save") {
                    vault.update(name: secret.name, value: editingValue)
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { saved = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editingValue == secret.value || editingValue.isEmpty)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    confirmDelete = true
                }
                .foregroundStyle(.red)
            }
        }
        .confirmationDialog(
            "Delete \(secret.name)?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { vault.delete(secret) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .animation(.easeInOut(duration: 0.2), value: saved)
    }
}
