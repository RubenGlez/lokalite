import Foundation
import Sparkle
import LokaliteCore

/// Wraps Sparkle's updater so the menu-bar app can offer "Check for Updates…".
///
/// Sparkle needs a Developer ID-signed, notarized bundle with an embedded
/// `Sparkle.framework` and an `SUFeedURL` in Info.plist to work; only release
/// builds produce those. Development builds run from `swift build`/Xcode without
/// a feed URL, so the updater stays inert there and the UI hides its controls.
@Observable
@MainActor
final class SoftwareUpdater {
    @ObservationIgnored let controller: SPUStandardUpdaterController?

    init() {
        if VaultConfiguration.isDevelopmentBuild {
            controller = nil
        } else {
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
