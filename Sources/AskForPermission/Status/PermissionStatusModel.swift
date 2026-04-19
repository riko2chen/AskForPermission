import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import IOKit.hid

@MainActor
final class PermissionStatusModel: ObservableObject {
    @Published private(set) var isAccessibilityGranted: Bool = false
    @Published private(set) var isScreenRecordingGranted: Bool = false
    @Published private(set) var isInputMonitoringGranted: Bool = false
    @Published private(set) var isFullDiskAccessGranted: Bool = false
    @Published private(set) var isDeveloperToolsGranted: Bool = false
    @Published private(set) var isAppManagementGranted: Bool = false
    @Published var activePermissionRequest: PermissionKind?
    @Published var inProgressPermission: PermissionKind?

    private var timer: Timer?

    init() {
        refresh()
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    func isGranted(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .accessibility: return isAccessibilityGranted
        case .screenRecording: return isScreenRecordingGranted
        case .inputMonitoring: return isInputMonitoringGranted
        case .fullDiskAccess: return isFullDiskAccessGranted
        case .developerTools: return isDeveloperToolsGranted
        case .appManagement: return isAppManagementGranted
        }
    }

    func refresh() {
        let ax = AXIsProcessTrusted()
        let sc = CGPreflightScreenCaptureAccess()
        let inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        let fullDiskAccess = fullDiskAccessProbe()
        let developerTools = developerToolsTCCService().map(tccAccessPreflight(service:)) ?? false
        let appManagement = appManagementTCCService().map(tccAccessPreflight(service:)) ?? false
        if ax != isAccessibilityGranted { isAccessibilityGranted = ax }
        if sc != isScreenRecordingGranted { isScreenRecordingGranted = sc }
        if inputMonitoring != isInputMonitoringGranted { isInputMonitoringGranted = inputMonitoring }
        if fullDiskAccess != isFullDiskAccessGranted { isFullDiskAccessGranted = fullDiskAccess }
        if developerTools != isDeveloperToolsGranted { isDeveloperToolsGranted = developerTools }
        if appManagement != isAppManagementGranted { isAppManagementGranted = appManagement }
    }

    func publisher(for kind: PermissionKind) -> AnyPublisher<Bool, Never> {
        switch kind {
        case .accessibility: return $isAccessibilityGranted.eraseToAnyPublisher()
        case .screenRecording: return $isScreenRecordingGranted.eraseToAnyPublisher()
        case .inputMonitoring: return $isInputMonitoringGranted.eraseToAnyPublisher()
        case .fullDiskAccess: return $isFullDiskAccessGranted.eraseToAnyPublisher()
        case .developerTools: return $isDeveloperToolsGranted.eraseToAnyPublisher()
        case .appManagement: return $isAppManagementGranted.eraseToAnyPublisher()
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func fullDiskAccessProbe() -> Bool {
        for path in fullDiskAccessProbePaths {
            let fd = open(path, O_RDONLY | O_CLOEXEC)
            if fd >= 0 {
                close(fd)
                return true
            }

            let error = errno
            if error == EPERM || error == EACCES { return false }
            if error != ENOENT { return false }
        }
        return false
    }
}

private let fullDiskAccessProbePaths = [
    (NSHomeDirectory() as NSString).appendingPathComponent("Library/Safari/Bookmarks.plist"),
    (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
]
