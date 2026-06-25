import SwiftUI
import LokaliteCore

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
                CategoryIconTile(category: secret.category, size: 38)
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
                        ForEach(availableEnvironments, id: \.id) { env in
                            Text(env.name).tag(env.name as String?)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: destProjectId) { _, projectId in
                availableEnvironments = (try? Vault.shared.listEnvironments(projectId: projectId)) ?? []
                destEnvironmentName = availableEnvironments.first?.name
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
                    .disabled(isSameDestination || destEnvironmentName == nil)
                }
            }
        }
        .frame(width: 380, height: 260)
        .onAppear {
            destProjectId = vault.selectedProject?.id ?? ""
            destEnvironmentName = vault.selectedEnvironment?.name
            if let projectId = vault.selectedProject?.id {
                availableEnvironments = (try? Vault.shared.listEnvironments(projectId: projectId)) ?? []
                destEnvironmentName = destEnvironmentName ?? availableEnvironments.first?.name
            }
        }
    }

    private func performMove() {
        guard let srcProject = vault.selectedProject, let destEnvironmentName else { return }
        if destProjectId == srcProject.id {
            vault.moveSecret(secret, toEnvironmentName: destEnvironmentName)
        } else {
            vault.moveSecret(secret, toProjectId: destProjectId)
        }
    }
}
