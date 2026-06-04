import AppKit
import Foundation

@MainActor
struct ClipboardController {
    func copy(_ value: String, clearAfter delay: Double) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            if NSPasteboard.general.string(forType: .string) == value {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
