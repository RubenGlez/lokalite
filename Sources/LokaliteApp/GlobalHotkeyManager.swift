import Carbon.HIToolbox
import Foundation

final class GlobalHotkeyManager {
    var onActivate: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    struct Shortcut: Equatable, Hashable {
        let id: String
        let keyCode: UInt32
        let modifiers: UInt32
        let displayName: String

        static let cmdShiftSpace = Shortcut(id: "cmdShiftSpace",
            keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey), displayName: "⌘⇧Space")
        static let cmdShiftL = Shortcut(id: "cmdShiftL",
            keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey | shiftKey), displayName: "⌘⇧L")
        static let cmdShiftK = Shortcut(id: "cmdShiftK",
            keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | shiftKey), displayName: "⌘⇧K")
        static let ctrlOptionSpace = Shortcut(id: "ctrlOptionSpace",
            keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), displayName: "⌃⌥Space")
        static let disabled = Shortcut(id: "disabled", keyCode: 0, modifiers: 0, displayName: "Disabled")

        static let allOptions: [Shortcut] = [.cmdShiftSpace, .cmdShiftL, .cmdShiftK, .ctrlOptionSpace, .disabled]

        static func fromID(_ id: String) -> Shortcut {
            allOptions.first { $0.id == id } ?? .cmdShiftSpace
        }
    }

    func register(_ shortcut: Shortcut) {
        unregister()
        guard shortcut.keyCode > 0 else { return }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x4C4B4C54
        hotKeyID.id = 1

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let ptr = userData else { return OSStatus(noErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { manager.onActivate?() }
                return OSStatus(noErr)
            },
            1, &eventSpec, selfPtr, &eventHandlerRef
        )

        RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
    }

    deinit { unregister() }
}

extension Notification.Name {
    static let hotkeyShortcutChanged = Notification.Name("hotkeyShortcutChanged")
}
