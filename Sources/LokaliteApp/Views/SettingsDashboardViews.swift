import AppKit
import SwiftUI
import LokaliteCore

// MARK: - Dashboard Components

struct DashboardEnvironment: Identifiable {
    let id: String
    let name: String
    let color: Color
    let count: Int
    let isActive: Bool
}

struct DashboardSearchField: View {
    let placeholder: String
    @Binding var text: String
    let shortcut: String
    var isFocused: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .optionallyFocused(isFocused)
            Text(shortcut)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textDim)
        }
        .padding(.horizontal, 9)
        .frame(height: Theme.controlHeight)
        .background(Theme.neutral(0.045), in: .rect(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.sep, lineWidth: 1))
    }
}

struct DashboardProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
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
            .background(rowBackground, in: .rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
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

    private var rowBackground: Color {
        if isSelected { return Theme.neutral(0.10) }
        if isHovered { return Theme.neutral(0.05) }
        return .clear
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

struct EnvironmentSummaryCard: View {
    let environment: DashboardEnvironment
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(environment.color)
                        .frame(width: 8, height: 8)
                    Text(environment.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    if environment.isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.green.opacity(0.13), in: .rect(cornerRadius: 5))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(environment.count) secret\(environment.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                .frame(width: max(proxy.size.width, 660), alignment: .topLeading)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: CGFloat(secrets.count) * Theme.rowHeight + Theme.tableHeaderHeight + 1)
    }
}

struct SecretShortcutRow: View {
    let onNewSecret: () -> Void

    var body: some View {
        HStack {
            Button(action: onNewSecret) {
                ShortcutHint(keys: "⌘N", title: "New secret")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }
}

struct ShortcutHint: View {
    let keys: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(keys)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.windowBackground, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.sep, lineWidth: 1))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textMuted)
        }
    }
}

struct DashboardSecretHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Category").frame(width: 110, alignment: .leading)
            Text("Environment").frame(width: 160, alignment: .leading)
            Color.clear.frame(width: 28)
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
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(pillColor(environment))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(pillColor(environment).opacity(0.16), in: .rect(cornerRadius: 5))
                    }
                }
                .frame(width: 160, alignment: .leading)

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
                            .frame(width: 28, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .opacity(isHovered || isSelected ? 1 : 0.7)
                } else {
                    Color.clear.frame(width: 28, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Theme.rowHeight)
            .background(isSelected ? Theme.neutral(0.055) : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
    @State private var gitRemote: String? = nil

    var body: some View {
        InspectorCard(title: "Project Info") {
            VStack(alignment: .leading, spacing: 15) {
                InfoLine(icon: "folder", title: "Linked folder", value: shortPath(project?.path) ?? "Not linked")
                InfoLine(icon: "point.3.connected.trianglepath.dotted", title: "Repository", value: gitRemote ?? "Not configured")
                InfoLine(icon: "square.stack.3d.up", title: "\(environmentCount) environments", value: nil)
                InfoLine(icon: "lock", title: "\(secretCount) secrets", value: nil)
                InfoLine(icon: "clock", title: "Created", value: project?.createdAt.map { createdDateFormatter.string(from: $0) } ?? "Unknown")
            }
        }
        .task(id: project?.path) {
            gitRemote = await detectGitRemote(project?.path)
        }
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.neutral(copied ? 0.070 : 0.045), in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(copied ? Theme.green.opacity(0.35) : Theme.sep, lineWidth: 1))
        }
        .buttonStyle(.plain)
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

struct MCPPanel: View {
    @State private var isInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MCP Server")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                StatusBadge(installed: isInstalled)
            }

            Text("Use Lokalite from your agents and tools.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)

            CopyableCommandLine(text: "lokalite install")

            Text("Registers with Claude Code. For Cursor or Windsurf, add --client cursor or --client windsurf.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)

            Divider().overlay(Theme.sep)

            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/RubenGlez/lokalite")!)
            } label: {
                HStack {
                    Text("Documentation")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Text("Learn how to connect your agents.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
        .onAppear { isInstalled = checkMCPInstalled() }
    }

    private func checkMCPInstalled() -> Bool {
        let claudeConfig = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: claudeConfig),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any] else { return false }
        return servers["lokalite"] != nil
    }
}

struct DeveloperActionsPanel: View {
    @State private var isInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CLI")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                StatusBadge(installed: isInstalled)
            }

            Text("Use Lokalite from terminals and local tools.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)

            VStack(alignment: .leading, spacing: 9) {
                CopyableCommandLine(text: "lokalite status")
                CopyableCommandLine(text: "lokalite shell --env production")
                CopyableCommandLine(text: "lokalite run -- npm run dev")
            }

            Divider().overlay(Theme.sep)

            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/RubenGlez/lokalite")!)
            } label: {
                HStack {
                    Text("Documentation")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Text("Learn how to use the CLI.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.panelBackground, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sep, lineWidth: 1))
        .onAppear { isInstalled = isCLIInstalled() }
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
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
    let icon: String
    let title: String
    let value: String?

    var body: some View {
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
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.blue)
                        .lineLimit(1)
                }
            }
        }
    }
}
