import AppKit
import SwiftUI

@main
struct LokaliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
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

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { positionButtons(from: view) }
    }

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
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupHotkey()
        setupWindowBehavior()

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
        controller.view.frame.size = NSSize(width: 360, height: 420)

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

    private func setupWindowBehavior() {
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.windows.first { $0.identifier?.rawValue == "settings" }?
                .isMovableByWindowBackground = true
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
