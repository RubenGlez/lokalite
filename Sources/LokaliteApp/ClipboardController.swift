import AppKit
import Foundation

@MainActor
struct ClipboardController {
    // org.nspasteboard.ConcealedType tells clipboard managers not to record the value.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    func copy(_ value: String, clearAfter delay: Double) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.declareTypes([.string, Self.concealedType], owner: nil)
        NSPasteboard.general.setString(value, forType: .string)
        NSPasteboard.general.setString("", forType: Self.concealedType)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            if NSPasteboard.general.string(forType: .string) == value {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
