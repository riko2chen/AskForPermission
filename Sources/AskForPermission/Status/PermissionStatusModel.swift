import AppKit
import ApplicationServices
import Combine
import CoreGraphics

@MainActor
final class PermissionStatusModel: ObservableObject {
    @Published private(set) var isAccessibilityGranted: Bool = false
    @Published private(set) var isScreenRecordingGranted: Bool = false
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
        }
    }

    func refresh() {
        let ax = AXIsProcessTrusted()
        let sc = CGPreflightScreenCaptureAccess()
        if ax != isAccessibilityGranted { isAccessibilityGranted = ax }
        if sc != isScreenRecordingGranted { isScreenRecordingGranted = sc }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}
