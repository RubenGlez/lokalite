import AppKit
import SwiftUI

@main
struct LokaliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Manage Secrets", id: "settings") {
            SettingsView()
                .environment(appDelegate.vault)
                .frame(minWidth: 580, minHeight: 460)
        }
        .defaultSize(width: 800, height: 540)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let vault = VaultViewModel()
    let hotkeyManager = GlobalHotkeyManager()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupHotkey()

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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = DialMenuBarIcon.templateImage()
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        let controller = NSHostingController(
            rootView: VaultPopover().environment(vault)
        )
        controller.view.frame.size = NSSize(width: 340, height: 450)

        let p = NSPopover()
        p.contentViewController = controller
        p.behavior = .transient
        self.popover = p
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func setupHotkey() {
        hotkeyManager.onActivate = { [weak self] in self?.togglePopover(nil) }
        let shortcut = GlobalHotkeyManager.Shortcut.fromID(
            UserDefaults.standard.string(forKey: "hotkeyShortcutID") ?? "cmdShiftSpace"
        )
        hotkeyManager.register(shortcut)
    }
}
