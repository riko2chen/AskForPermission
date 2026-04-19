import Foundation

public enum PermissionKind: String, CaseIterable, Sendable {
    case accessibility
    case screenRecording
    case inputMonitoring
    case fullDiskAccess
    case developerTools
    case appManagement

    public var displayName: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .inputMonitoring: return "Input Monitoring"
        case .fullDiskAccess: return "Full Disk Access"
        case .developerTools: return "Developer Tools"
        case .appManagement: return "App Management"
        }
    }

    public var shortDescription: String {
        switch self {
        case .accessibility:
            return "Needed to click, type, and read on-screen content for you."
        case .screenRecording:
            return "Needed to take screenshots so it knows where to click."
        case .inputMonitoring:
            return "Needed to observe keyboard and mouse input for you."
        case .fullDiskAccess:
            return "Needed to read protected app data and files for you."
        case .developerTools:
            return "Needed to run trusted developer tools for you."
        case .appManagement:
            return "Needed to manage other app bundles for you."
        }
    }

    var systemSettingsQuery: String {
        switch self {
        case .accessibility: return "Privacy_Accessibility"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .inputMonitoring: return "Privacy_ListenEvent"
        case .fullDiskAccess: return "Privacy_AllFiles"
        case .developerTools: return "Privacy_DevTools"
        case .appManagement: return "Privacy_AppBundles"
        }
    }

    var systemSettingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(systemSettingsQuery)")!
    }
}
