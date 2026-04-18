import Foundation

enum StageManagerDetection {
    /// Reads `com.apple.WindowManager` / `GloballyEnabled` — the user-facing
    /// toggle in Control Center. When Stage Manager is on, activating another
    /// app pulls its Stage forward and shoves the previously-frontmost Stage
    /// (including our windows) off to the side strip, so the transition flow
    /// needs to compensate.
    static var isActive: Bool {
        guard let value = CFPreferencesCopyAppValue(
            "GloballyEnabled" as CFString,
            "com.apple.WindowManager" as CFString
        ) as? Bool else {
            return false
        }
        return value
    }
}
