import AppKit
import SwiftUI

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        hotkeyManager.onActivate = {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        let shortcut = GlobalHotkeyManager.Shortcut.fromID(AppPreferences().hotkeyShortcutID)
        hotkeyManager.register(shortcut)
    }
}
