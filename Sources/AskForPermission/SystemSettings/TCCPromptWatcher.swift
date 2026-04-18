import AppKit
import CoreGraphics
import Foundation

/// Waits for a TCC permission prompt (the sheet System Settings shows after
/// an app is dropped on its privacy list) to resolve. Returns as soon as
/// *any* of the signals below fire, so cancel / deny / timeout don't leave
/// the caller's UI stuck.
///
/// Signals, earliest wins:
///   1. `state.isGranted(kind)` flips to true — user clicked **Allow**.
///   2. System Settings' on-screen window count drops below its peak — the
///      TCC sheet was shown then dismissed (Allow / Don't Allow / Cancel /
///      Settings closed). A final grant check decides the result.
///   3. The host app becomes frontmost after having lost focus — user
///      returned to the host app instead of completing the prompt.
///   4. `timeout` elapses.
///
/// No entitlements required: `CGWindowListCopyWindowInfo` returns metadata
/// (owner, bounds, layer) even without Screen Recording; we never read
/// pixel data. `NSApp.isActive` is a local query.
@MainActor
enum TCCPromptWatcher {
    static func waitForResolution(
        kind: PermissionKind,
        state: PermissionStatusModel,
        timeout: Duration
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        // Record the highest Settings window count we've seen. Sheets add a
        // new top-level window, so peak > baseline means the prompt appeared.
        // A later count below peak means the prompt dismissed.
        var peakSettingsWindowCount = countSettingsWindows()

        // Track whether our app has lost focus since entering the watcher.
        // Only after we've seen it go inactive do we treat becoming active
        // again as the "user came back" signal — otherwise we'd false-fire
        // if the drag handoff left our app briefly active.
        var hostLostFocus = false

        while clock.now < deadline {
            state.refresh()
            if state.isGranted(kind) { return true }

            let count = countSettingsWindows()
            if count > peakSettingsWindowCount {
                peakSettingsWindowCount = count
            } else if count < peakSettingsWindowCount {
                return await finalGrantCheck(kind: kind, state: state)
            }

            if !NSApp.isActive {
                hostLostFocus = true
            } else if hostLostFocus {
                return await finalGrantCheck(kind: kind, state: state)
            }

            try? await Task.sleep(for: .milliseconds(120))
        }
        return false
    }

    /// Give TCC a tick to commit the decision before we read `isGranted` for
    /// the last time. Without this, Allow sometimes loses the race and we
    /// report `.timedOut` for a request the user did grant.
    private static func finalGrantCheck(
        kind: PermissionKind,
        state: PermissionStatusModel
    ) async -> Bool {
        try? await Task.sleep(for: .milliseconds(200))
        state.refresh()
        return state.isGranted(kind)
    }

    /// Counts on-screen windows owned by System Settings / System
    /// Preferences. The TCC prompt sheet shows up as an additional entry
    /// alongside the main Settings window.
    private static func countSettingsWindows() -> Int {
        let settingsOwners: Set<String> = ["System Settings", "System Preferences"]
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return 0 }
        return info.reduce(into: 0) { total, window in
            if let owner = window[kCGWindowOwnerName as String] as? String,
               settingsOwners.contains(owner) {
                total += 1
            }
        }
    }
}
