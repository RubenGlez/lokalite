import AppKit
import SwiftUI
import LokaliteCore

@main
struct LokaliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            VaultPopover()
                .environment(appDelegate.vault)
                .frame(width: 360, height: 420)
        } label: {
            MenuBarIcon()
            if VaultConfiguration.isDevelopmentBuild {
                Text("DEV")
            }
        }
        .menuBarExtraStyle(.window)

        Window("Lokalite", id: "settings") {
            SettingsView()
                .environment(appDelegate.vault)
                .frame(minWidth: 980, minHeight: 620)
                .background(WindowButtonPositioner())
        }
        .defaultSize(width: 1180, height: 720)
        .windowStyle(.hiddenTitleBar)
    }
}

private struct WindowButtonPositioner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { positionButtons(from: view) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    private func positionButtons(from view: NSView) {
        guard let window = view.window,
              let close = window.standardWindowButton(.closeButton),
              let minimize = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let container = close.superview
        else { return }

        let topInset: CGFloat = 20
        let leadingInset: CGFloat = 20
        let spacing: CGFloat = 26
        let y = container.bounds.height - topInset - close.frame.height

        close.setFrameOrigin(NSPoint(x: leadingInset, y: y))
        minimize.setFrameOrigin(NSPoint(x: leadingInset + spacing, y: y))
        zoom.setFrameOrigin(NSPoint(x: leadingInset + spacing * 2, y: y))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let vault = VaultViewModel()
    let hotkeyManager = GlobalHotkeyManager()
    private var windowEventMonitor: Any?
    private var windowKeyObserver: NSObjectProtocol?
    private var statusItemMenuMonitor: Any?
    private var daemonServer: VaultSocketServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        startVaultDaemon()
        setupHotkey()
        setupWindowBehavior()
        setupStatusItemMenu()

        NotificationCenter.default.addObserver(
            forName: .hotkeyShortcutChanged, object: nil, queue: .main
        ) { [weak self] note in
            guard let id = note.object as? String else { return }
            Task { @MainActor [weak self] in
                self?.hotkeyManager.register(GlobalHotkeyManager.Shortcut.fromID(id))
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        daemonServer?.stop()
    }

    // The app is the vault daemon (ADR 0014): it owns the only unlocked Vault and
    // brokers requests from the CLI/MCP over a Unix socket so those processes never
    // hold the key. NOTE: the server serves on background threads while the app's
    // main thread also uses Vault.shared — verify/guard that concurrency before the
    // CLI/MCP default to the daemon.
    private func startVaultDaemon() {
        let server = VaultSocketServer(
            socketPath: VaultConfiguration.daemonSocketURL.path,
            service: Vault.shared
        )
        do {
            try server.start()
            daemonServer = server
        } catch {
            NSLog("Lokalite: vault daemon failed to start: \(error.localizedDescription)")
        }
    }

    private func setupWindowBehavior() {
        windowEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard event.clickCount == 2,
                  let window = event.window,
                  window.identifier?.rawValue == "settings" else { return event }

            let location = event.locationInWindow
            let windowHeight = window.frame.height
            guard location.y > windowHeight - 54 else { return event }

            if let hit = window.contentView?.hitTest(location), hit is NSControl {
                return event
            }

            window.zoom(nil)
            return nil
        }
        windowKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow,
                  window.identifier?.rawValue == "settings" else { return }
            window.isMovableByWindowBackground = true
            Task { @MainActor [weak self] in
                if let obs = self?.windowKeyObserver {
                    NotificationCenter.default.removeObserver(obs)
                    self?.windowKeyObserver = nil
                }
            }
        }
    }

    // MenuBarExtra has no public right-click API, so intercept right-clicks on the
    // status bar item's window and show a Quit menu there.
    private func setupStatusItemMenu() {
        statusItemMenuMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            guard let window = event.window,
                  NSStringFromClass(type(of: window)).contains("NSStatusBarWindow"),
                  let contentView = window.contentView else { return event }

            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit Lokalite",
                                    action: #selector(NSApplication.terminate(_:)),
                                    keyEquivalent: "q"))
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
            return nil
        }
    }

    private func setupHotkey() {
        hotkeyManager.onActivate = { [weak self] in
            self?.togglePopover()
        }
        let shortcut = GlobalHotkeyManager.Shortcut.fromID(AppPreferences().hotkeyShortcutID)
        hotkeyManager.register(shortcut)
    }

    // MenuBarExtra exposes no API to open its popover programmatically, so locate
    // the status item's button and synthesize a click — the same toggle a real
    // click performs (opening it, or closing it if already open).
    private func togglePopover() {
        guard let button = statusItemButton() else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        button.performClick(nil)
    }

    private func statusItemButton() -> NSStatusBarButton? {
        for window in NSApp.windows
        where NSStringFromClass(type(of: window)).contains("NSStatusBarWindow") {
            if let button = window.contentView?.firstDescendant(ofType: NSStatusBarButton.self) {
                return button
            }
        }
        return nil
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let found = subview.firstDescendant(ofType: type) { return found }
        }
        return nil
    }
}
