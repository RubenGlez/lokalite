import AppKit
import SwiftUI
import LokaliteCore

// MARK: - Dashboard Components

struct DashboardSearchField: View {
    let placeholder: String
    @Binding var text: String
    let shortcut: String
    var isFocused: FocusState<Bool>.Binding? = nil
    @FocusState private var ownFocus: Bool
    @State private var isHovered = false

    private var focus: FocusState<Bool>.Binding { isFocused ?? $ownFocus }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(focus.wrappedValue ? Theme.text : Theme.textMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(focus)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(IconButtonStyle(size: 18, cornerRadius: 9))
                .help("Clear search")
            } else if !shortcut.isEmpty {
                Text(shortcut)
                    .font(Theme.mono(11, .medium))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: Theme.controlHeight)
        .background(Theme.neutral(focus.wrappedValue ? 0.06 : 0.045), in: .rect(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7).stroke(
                focus.wrappedValue ? Theme.brand.opacity(0.6) : isHovered ? Theme.borderStrong : Theme.sep,
                lineWidth: 1
            )
        )
        .shadow(color: focus.wrappedValue ? Theme.glow.opacity(0.5) : .clear, radius: 5)
        .contentShape(.rect)
        .onTapGesture { focus.wrappedValue = true }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: focus.wrappedValue)
    }
}

/// Dropdown styled like `DashboardSearchField` (neutral fill, hairline border,
/// muted chevrons) so filter bars don't drop in the system's tinted popup button.
struct ThemedDropdown<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(label: String, value: Value)]

    private var selectedLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    if option.value == selection {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .menuStyle(.button)
        .buttonStyle(SurfaceButtonStyle())
        .menuIndicator(.hidden)
    }
}

struct DashboardProjectRow: View {
    let project: Project
    let isSelected: Bool
    var compact: Bool = false
    let onSelect: () -> Void

    var body: some View {
        if compact { compactBody } else { fullBody }
    }

    /// Icon-only row for the collapsed sidebar; the name moves to the tooltip.
    private var compactBody: some View {
        Button(action: onSelect) {
            projectIcon
                .frame(width: 40, height: 40)
        }
        .buttonStyle(RowButtonStyle(isSelected: isSelected, cornerRadius: 8))
        .frame(width: 40)
        .help(project.name)
        .accessibilityLabel(project.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fullBody: some View {
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
        }
        .buttonStyle(RowButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

}

struct MainProjectIcon: View {
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

struct DashboardSecretsTable: View {
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
                .frame(width: max(proxy.size.width, 460), alignment: .topLeading)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: CGFloat(secrets.count) * Theme.rowHeight + Theme.tableHeaderHeight + 1)
    }
}

struct DashboardSecretHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Category").frame(width: 110, alignment: .leading)
            Text("Environment").frame(width: 130, alignment: .leading)
            Color.clear.frame(width: 26)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Theme.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, 16)
        .frame(height: Theme.tableHeaderHeight)
    }
}

struct DashboardSecretRow: View {
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
                VStack(alignment: .leading, spacing: 2) {
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
                    if let desc = secret.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.15), value: copied)

                CategoryPill(category: secret.category)
                    .frame(width: 110, alignment: .leading)

                HStack(spacing: 5) {
                    ForEach(Array(environments.prefix(2)), id: \.self) { environment in
                        Text(environment)
                            .lineLimit(1)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(pillColor(environment))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(pillColor(environment).opacity(0.16), in: Capsule())
                    }
                }
                .frame(width: 130, alignment: .leading)

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
                    }
                    .menuStyle(.button)
                    .buttonStyle(IconButtonStyle(size: 26))
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .opacity(isHovered || isSelected ? 1 : 0.6)
                } else {
                    Color.clear.frame(width: 26, height: 26)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Theme.rowHeight)
        }
        .buttonStyle(RowButtonStyle(isSelected: isSelected, cornerRadius: 0))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        withCopyFeedback($copied) { onCopy() }
    }

    private func pillColor(_ name: String) -> Color {
        environmentColors[name] ?? Theme.textMuted
    }
}

private let createdDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

struct ProjectInfoPanel: View {
    let project: Project?
    let environmentCount: Int
    let secretCount: Int
    /// Opens the folder picker to link this project (repo line, no folder yet).
    var onLinkFolder: () -> Void = {}
    /// Opens Activity filtered to this project.
    var onOpenActivity: () -> Void = {}
    @State private var gitRemote: String? = nil
    @State private var lastActivity: Date? = nil

    var body: some View {
        InspectorCard(title: "Project Info") {
            VStack(alignment: .leading, spacing: 6) {
                repositoryLine
                InfoLine(icon: "square.stack.3d.up", title: "\(environmentCount) environments", value: nil)
                InfoLine(icon: "lock", title: "\(secretCount) secrets", value: nil)
                activityLine
                InfoLine(icon: "calendar", title: "Created",
                         value: project?.createdAt.map { createdDateFormatter.string(from: $0) } ?? "Unknown",
                         isPlaceholder: project?.createdAt == nil)
            }
        }
        .task(id: project?.path) {
            gitRemote = await detectGitRemote(project?.path)
        }
        // Re-read when the project or its contents change (edits log activity).
        .task(id: "\(project?.id ?? "")-\(secretCount)-\(environmentCount)") {
            lastActivity = project.flatMap { project in
                try? Vault.shared.listActivity(limit: 1, filter: ActivityFilter(projectName: project.name)).first?.accessedAt
            }
        }
    }

    /// Read from the linked folder's `origin` remote. Each state gets the shortcut
    /// that moves it forward: open the repo, reveal the folder, or link one.
    @ViewBuilder
    private var repositoryLine: some View {
        let icon = "point.3.connected.trianglepath.dotted"
        if let remote = gitRemote {
            let web = webURL(forRemote: remote)
            InfoLine(icon: icon, title: "Repository", value: displayRemote(remote),
                     trailing: web == nil ? nil : .external,
                     help: web == nil ? remote : "Open \(web!.absoluteString)",
                     action: web.map { url in { NSWorkspace.shared.open(url) } })
                .contextMenu {
                    Button("Copy URL") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(web?.absoluteString ?? remote, forType: .string)
                    }
                }
        } else if let path = project?.path {
            InfoLine(icon: icon, title: "Repository", value: "No git remote", isPlaceholder: true,
                     trailing: .external, help: "Open the linked folder in Finder",
                     action: { NSWorkspace.shared.open(URL(fileURLWithPath: path)) })
        } else {
            InfoLine(icon: icon, title: "Repository", value: "No linked folder", isPlaceholder: true,
                     trailing: .inApp, help: "Link a folder to this project",
                     action: onLinkFolder)
        }
    }

    @ViewBuilder
    private var activityLine: some View {
        if let lastActivity {
            InfoLine(icon: "clock.arrow.circlepath", title: "Last activity",
                     value: Self.relativeFormatter.localizedString(for: lastActivity, relativeTo: Date()),
                     trailing: .inApp, help: "Show this project's activity",
                     action: onOpenActivity)
        } else {
            InfoLine(icon: "clock.arrow.circlepath", title: "Last activity", value: "No activity yet", isPlaceholder: true)
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    /// `git@host:owner/repo.git`, `ssh://git@host/owner/repo.git` or
    /// `https://host/owner/repo.git` → `https://host/owner/repo`.
    private func webURL(forRemote remote: String) -> URL? {
        var r = remote
        if r.hasSuffix(".git") { r.removeLast(4) }
        if r.hasPrefix("http://") || r.hasPrefix("https://") {
            return URL(string: r)
        }
        if r.hasPrefix("ssh://") {
            r.removeFirst("ssh://".count)
            if let at = r.firstIndex(of: "@") { r = String(r[r.index(after: at)...]) }
            // Drop an explicit port: ssh://git@host:22/owner/repo
            if let colon = r.firstIndex(of: ":"), let slash = r.firstIndex(of: "/"), colon < slash {
                r = String(r[..<colon]) + String(r[slash...])
            }
            return URL(string: "https://" + r)
        }
        // scp-like: git@host:owner/repo
        if let at = r.firstIndex(of: "@"), let colon = r.firstIndex(of: ":"), at < colon {
            let host = r[r.index(after: at)..<colon]
            let path = r[r.index(after: colon)...]
            return URL(string: "https://\(host)/\(path)")
        }
        return nil
    }

    /// `owner/repo` reads better in a narrow column than the full remote.
    private func displayRemote(_ remote: String) -> String {
        guard let web = webURL(forRemote: remote) else { return remote }
        let path = web.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? remote : path
    }

    private func detectGitRemote(_ path: String?) async -> String? {
        guard let path, !path.isEmpty else { return nil }
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", path, "remote", "get-url", "origin"]
            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                let url = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return url?.isEmpty == false ? url : nil
            } catch {
                return nil
            }
        }.value
    }
}


struct CopyableCommandLine: View {
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
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SurfaceButtonStyle(height: nil, cornerRadius: 6, isOn: copied))
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

/// CLI popover. Not installed: how to get it. Installed: where it is and how to start.
struct CLIToolPanel: View {
    let status: ToolingStatus

    var body: some View {
        ToolPanel(title: "CLI", installed: status.cliInstalled) {
            if let path = status.cliPath {
                Text("Use your secrets from any terminal without writing them to disk.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                ToolPanelPath(path: path)
                ToolPanelLabel("Quick start")
                VStack(alignment: .leading, spacing: 7) {
                    CopyableCommandLine(text: "lokalite status")
                    CopyableCommandLine(text: "lokalite run -- npm run dev")
                    CopyableCommandLine(text: "lokalite shell")
                }
            } else {
                Text("Not installed on this Mac. The CLI loads secrets into terminals, and MCP clients launch it to reach your vault.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                ToolPanelLabel("Install with Homebrew")
                CopyableCommandLine(text: LokaliteLinks.brewInstall)
                Button {
                    NSWorkspace.shared.open(LokaliteLinks.latestRelease)
                } label: {
                    Label("Download the installer (.pkg)", systemImage: "arrow.down.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(LinkButtonStyle(tone: .brand))
            }
        }
    }
}

/// MCP popover: registration status per client, each addable in one click.
struct MCPToolPanel: View {
    let status: ToolingStatus
    let onChange: () -> Void
    @State private var justAdded: MCPClient?
    @State private var error: String?

    var body: some View {
        ToolPanel(title: "MCP Server", installed: status.mcpInstalled) {
            Text("Lets agents use your secrets without the values ever reaching the chat.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if !status.cliInstalled {
                Label("Install the CLI first: MCP clients launch it to reach the vault.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(MCPClient.allCases, id: \.self) { client in
                    clientRow(client)
                    if client != MCPClient.allCases.last {
                        Divider().overlay(Theme.sep)
                    }
                }
            }
            .background(Theme.neutral(0.03), in: .rect(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.sep, lineWidth: 1))

            if let justAdded {
                Text("Restart \(justAdded.displayName) to load the server.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func clientRow(_ client: MCPClient) -> some View {
        HStack {
            Text(client.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            if status.registeredClients.contains(client) {
                Label("Added", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.green)
            } else {
                Button("Add") { add(client) }
                    .buttonStyle(SurfaceButtonStyle(height: 22, horizontalPadding: 9, cornerRadius: 6))
                    .disabled(!status.cliInstalled)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
    }

    private func add(_ client: MCPClient) {
        // Absolute path: GUI clients (Claude Desktop, Cursor) don't inherit the
        // shell's PATH, so a bare `lokalite` may not resolve for them.
        do {
            try client.register(command: status.cliPath ?? "lokalite")
            error = nil
            justAdded = client
        } catch {
            self.error = "Couldn't update \(client.displayName)'s config: \(error.localizedDescription)"
        }
        onChange()
    }
}

/// Shared frame for the sidebar tool popovers: title, status, content, docs link.
struct ToolPanel<Content: View>: View {
    let title: String
    let installed: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                Spacer()
                StatusBadge(installed: installed)
            }
            content
            Divider().overlay(Theme.sep)
            Button {
                NSWorkspace.shared.open(LokaliteLinks.docs)
            } label: {
                HStack {
                    Text("Documentation")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, 8)
                .frame(height: 28)
            }
            .buttonStyle(RowButtonStyle(cornerRadius: 6))
            .padding(.horizontal, -8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct ToolPanelLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.textDim)
            .textCase(.uppercase)
    }
}

private struct ToolPanelPath: View {
    let path: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.green)
            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// Installing the CLI and registering the MCP server are machine-wide facts, not
/// project ones, so they sit in the sidebar beside Activity rather than inside a
/// project. The row is a status glyph; the popover adapts to that status.
struct SidebarToolsSection: View {
    var compact: Bool = false
    @State private var status = ToolingStatus(cliPath: nil, registeredClients: [])

    var body: some View {
        VStack(spacing: compact ? 4 : 0) {
            SidebarToolRow(title: "CLI", icon: "terminal", installed: status.cliInstalled,
                           compact: compact, onOpen: refresh) {
                CLIToolPanel(status: status)
            }
            SidebarToolRow(title: "MCP Server", icon: "sparkles", installed: status.mcpInstalled,
                           compact: compact, onOpen: refresh) {
                MCPToolPanel(status: status, onChange: refresh)
            }
        }
        .onAppear(perform: refresh)
        // A `brew install` in Terminal lands while the app is in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        status = ToolingStatus.probe()
    }
}

struct SidebarToolRow<Detail: View>: View {
    let title: String
    let icon: String
    let installed: Bool
    var compact: Bool = false
    var onOpen: () -> Void = {}
    @ViewBuilder let detail: Detail

    @State private var showingDetail = false

    var body: some View {
        Group {
            if compact {
                // Collapsed sidebar: tool icon with the install-status dot as a badge.
                Button(action: open) {
                    Image(systemName: icon)
                        .overlay(alignment: .topTrailing) { statusDot.offset(x: 5, y: -3) }
                }
                .buttonStyle(IconButtonStyle(size: 36, cornerRadius: 8, isOn: showingDetail))
            } else {
                Button(action: open) {
                    HStack(spacing: 9) {
                        statusDot
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textDim)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                }
                .buttonStyle(RowButtonStyle(isSelected: showingDetail, showsSelectionBar: false))
                .padding(.horizontal, 8)
            }
        }
        .accessibilityLabel("\(title), \(installed ? "installed" : "not installed")")
        .help(installed ? "\(title) is installed" : "\(title) is not installed")
        .popover(isPresented: $showingDetail, arrowEdge: .trailing) {
            detail
                .frame(width: 320)
                .padding(4)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(installed ? Theme.green : Theme.textDim)
            .frame(width: 6, height: 6)
            .shadow(color: installed ? Theme.glow : .clear, radius: 3)
    }

    private func open() {
        onOpen()
        showingDetail = true
    }
}

struct StatusBadge: View {
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

struct InspectorCard<Content: View>: View {
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                Spacer()
                if let accessory {
                    Text(accessory)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Theme.neutral(0.06), in: .rect(cornerRadius: 5))
                }
            }
            content
        }
        .padding(16)
        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
    }
}

struct InfoLine: View {
    enum Trailing { case external, inApp }

    let icon: String
    let title: String
    let value: String?
    var isPlaceholder: Bool = false
    /// Arrow hinting where a click goes: ↗ leaves the app, › stays in it.
    var trailing: Trailing? = nil
    var help: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(RowButtonStyle(cornerRadius: 6, showsSelectionBar: false))
                .padding(.horizontal, -8)
                .help(help ?? "")
        } else {
            content
                .padding(.horizontal, -8)
                .help(help ?? value ?? "")
        }
    }

    private var content: some View {
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
                    // Plain text, not link-blue; the hover state and arrow mark clickables.
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundStyle(isPlaceholder ? Theme.textDim : Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 4)
            if let trailing, action != nil {
                Image(systemName: trailing == .external ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
