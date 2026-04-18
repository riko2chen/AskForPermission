import Foundation

public enum PermissionKind: String, CaseIterable, Sendable {
    case accessibility
    case screenRecording

    public var displayName: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        }
    }

    public var shortDescription: String {
        switch self {
        case .accessibility:
            return "Needed to click, type, and read on-screen content for you."
        case .screenRecording:
            return "Needed to take screenshots so it knows where to click."
        }
    }

    var systemSettingsQuery: String {
        switch self {
        case .accessibility: return "Privacy_Accessibility"
        case .screenRecording: return "Privacy_ScreenCapture"
        }
    }

    var systemSettingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(systemSettingsQuery)")!
    }
}
