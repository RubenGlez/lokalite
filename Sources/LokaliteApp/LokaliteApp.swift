import SwiftUI
import AppKit

@main
struct LokaliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vault = VaultViewModel()

    var body: some Scene {
        MenuBarExtra {
            VaultPopover()
                .environmentObject(vault)
        } label: {
            Image(systemName: "key.fill")
        }
        .menuBarExtraStyle(.window)

        Window("Manage Secrets", id: "settings") {
            SettingsView()
                .environmentObject(vault)
                .frame(minWidth: 580, minHeight: 460)
        }
        .defaultSize(width: 640, height: 520)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
