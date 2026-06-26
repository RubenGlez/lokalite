import AppKit
import SwiftUI
import LokaliteCore

struct VaultPopover: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var showingAddSecret = false
    @State private var selectedIndex = 0
    @State private var revealedSecretID: Secret.ID?
    @State private var envCopied = false
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
        vault.recentSecretNames.compactMap { name in
            vault.secrets.first { $0.name == name }
        }
    }

    private var sections: [(title: String, secrets: [Secret])] {
        guard searchText.isEmpty else { return [("Results", filtered)] }
        let recents = recentSecrets
        guard !recents.isEmpty else { return [("All", vault.secrets)] }
        let recentNames = Set(recents.map(\.name))
        let others = vault.secrets.filter { !recentNames.contains($0.name) }
        var result = [("Recent", recents)]
        if !others.isEmpty { result.append(("All", others)) }
        return result
    }

    private var visibleSecrets: [Secret] {
        sections.flatMap(\.secrets)
    }

    private var selectedSecret: Secret? {
        let list = visibleSecrets
        guard !list.isEmpty else { return nil }
        return list[min(max(selectedIndex, 0), list.count - 1)]
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
            revealedSecretID = nil
            selectedIndex = 0
            vault.unlock()
            if !vault.isLocked { Task { @MainActor in searchFocused = true } }
        }
        .onChange(of: vault.isLocked) { _, locked in
            if !locked { Task { @MainActor in searchFocused = true } }
        }
        .onDisappear {
            showingAddSecret = false
            revealedSecretID = nil
        }
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
                    .frame(width: 52, height: 52)
                Image(systemName: "lock.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Theme.brand)
            }

            VStack(spacing: 6) {
                Text("Lokalite")
                    .font(Theme.mono(14, .semibold))
                    .foregroundStyle(.primary)
                Text("Vault locked. Unlock to reach your secrets.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 230)
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
            if !vault.secrets.isEmpty {
                copyHintBar
            }
            Divider()
            footer
        }
        .background(Theme.panelBackground)
    }

    private var copyHintBar: some View {
        HStack(spacing: 12) {
            hint("⏎", "copy")
            hint("⌥⏎", "KEY=value")
            hint("⌃⏎", "export")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
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

            // Environment switcher — the active environment terminals and agents resolve.
            Menu {
                ForEach(vault.environments, id: \.id) { env in
                    Button { vault.makeEnvironmentActive(env) } label: {
                        HStack {
                            Theme.envCircle(Theme.color(hex: env.color))
                            Text(env.name)
                            if vault.isActiveEnvironment(env) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Theme.envCircle(environmentColor)
                    Text(vault.selectedEnvironment?.name ?? "No environment")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(vault.selectedProject == nil || vault.environments.isEmpty)
            .help("Active environment — what terminals and agents resolve")

            Spacer()

            DevBadge()

            Button {
                showingAddSecret = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.brand)
            .disabled(vault.selectedProject == nil || vault.selectedEnvironment == nil)
            .keyboardShortcut("n", modifiers: .command)
            .help("New secret")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var environmentColor: Color {
        vault.selectedEnvironment.map { Theme.color(hex: $0.color) } ?? Theme.text.opacity(0.7)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search secrets...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($searchFocused)
                .onKeyPress(.downArrow) {
                    moveSelection(1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(-1)
                    return .handled
                }
                .onKeyPress(keys: [.return], phases: .down) { press in
                    guard let secret = selectedSecret else { return .ignored }
                    let format: VaultViewModel.CopyFormat = if press.modifiers.contains(.option) {
                        .dotenvLine
                    } else if press.modifiers.contains(.control) {
                        .exportLine
                    } else {
                        .value
                    }
                    vault.copyToClipboard(secret, format: format)
                    closePopover()
                    return .handled
                }
                .onKeyPress(.space) {
                    guard searchText.isEmpty, let secret = selectedSecret else { return .ignored }
                    toggleReveal(secret)
                    return .handled
                }
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
        .background(Theme.neutral(0.035), in: .rect(cornerRadius: 7))
        .padding(12)
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
    }

    @ViewBuilder
    private var content: some View {
        if vault.secrets.isEmpty {
            emptyView
        } else if filtered.isEmpty {
            noResultsView
        } else {
            secretList
        }
    }

    private var secretList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    let secs = sections
                    ForEach(secs.indices, id: \.self) { sectionIndex in
                        let section = secs[sectionIndex]
                        let offset = secs[..<sectionIndex].reduce(0) { $0 + $1.secrets.count }

                        Text(section.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textMuted)
                            .textCase(.uppercase)
                            .padding(.horizontal, 18)
                            .padding(.top, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(section.secrets.enumerated()), id: \.element.id) { i, secret in
                                PopoverSecretRow(
                                    secret: secret,
                                    isSelected: offset + i == selectedIndex,
                                    isRevealed: revealedSecretID == secret.id,
                                    clearSeconds: Int(vault.clipboardClearSeconds),
                                    onCopy: { format in vault.copyToClipboard(secret, format: format) },
                                    onToggleReveal: { toggleReveal(secret) }
                                )
                                .id(secret.id)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 10)
            }
            .onChange(of: selectedIndex) { _, _ in
                if let secret = selectedSecret { proxy.scrollTo(secret.id) }
            }
        }
        .frame(minHeight: 210, maxHeight: 330, alignment: .top)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No secrets yet", systemImage: "key")
        } actions: {
            Button("Add your first secret") {
                showingAddSecret = true
            }
            .disabled(vault.selectedProject == nil || vault.selectedEnvironment == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var noResultsView: some View {
        ContentUnavailableView.search(text: searchText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                openManageWindow()
            } label: {
                Text("Open Lokalite")
                    .font(.system(size: 13, weight: .medium))
                    .frame(minHeight: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.text)
            .keyboardShortcut("o", modifiers: .command)

            Spacer()

            Button {
                withCopyFeedback($envCopied) { vault.copyEnvFile() }
            } label: {
                Text(envCopied ? "Copied · clears in \(Int(vault.clipboardClearSeconds))s" : "Copy .env")
                    .font(.system(size: 13, weight: .medium))
                    .frame(minHeight: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(envCopied ? Theme.brand : Theme.textMuted)
            .disabled(vault.secrets.isEmpty)
            .help("Copy all secrets in this view as a .env file")

            Button {
                vault.lock()
            } label: {
                Text("Lock")
                    .font(.system(size: 13, weight: .medium))
                    .frame(minHeight: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textMuted)
            .keyboardShortcut("l", modifiers: .command)

            Button("") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.15), value: envCopied)
    }

    private func moveSelection(_ delta: Int) {
        let count = visibleSecrets.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    private func toggleReveal(_ secret: Secret) {
        revealedSecretID = revealedSecretID == secret.id ? nil : secret.id
    }

    private func closePopover() {
        NSApp.windows
            .filter { $0.isVisible && !$0.styleMask.contains(.titled) }
            .forEach { $0.orderOut(nil) }
    }

    private func openManageWindow() {
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}

private struct PopoverSecretRow: View {
    let secret: Secret
    let isSelected: Bool
    let isRevealed: Bool
    let clearSeconds: Int
    let onCopy: (VaultViewModel.CopyFormat) -> Void
    let onToggleReveal: () -> Void
    @State private var copied = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: copyFromClick) {
                HStack(spacing: 11) {
                    CategoryIconTile(category: secret.category, size: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(secret.name)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(secondaryText)
                            .font(.system(size: 11, design: isRevealed ? .monospaced : .default))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()

                    if copied {
                        Label("Copied · clears in \(clearSeconds)s", systemImage: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.brand)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if hovering || isRevealed {
                Button(action: onToggleReveal) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide value" : "Reveal value")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(isSelected ? Theme.neutral(0.07) : .clear, in: .rect(cornerRadius: 6))
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: copied)
        .contextMenu {
            Button("Copy Value") { copy(.value) }
            Button("Copy as KEY=value") { copy(.dotenvLine) }
            Button("Copy as export KEY=value") { copy(.exportLine) }
        }
    }

    private var secondaryText: String {
        if isRevealed { return secret.value }
        if let description = secret.description, !description.isEmpty {
            return "\(secret.category.label) · \(description)"
        }
        return secret.category.label
    }

    private func copyFromClick() {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        if flags.contains(.option) {
            copy(.dotenvLine)
        } else if flags.contains(.control) {
            copy(.exportLine)
        } else {
            copy(.value)
        }
    }

    private func copy(_ format: VaultViewModel.CopyFormat) {
        withCopyFeedback($copied) { onCopy(format) }
    }
}
