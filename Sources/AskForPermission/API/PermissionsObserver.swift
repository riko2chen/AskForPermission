import Combine
import Foundation

/// SwiftUI-friendly wrapper around the shared permission state; in a non-bundled host, all six properties stay `false` and never update.
@MainActor
public final class PermissionsObserver: ObservableObject {
    @Published public private(set) var accessibility: Bool = false
    @Published public private(set) var screenRecording: Bool = false
    @Published public private(set) var inputMonitoring: Bool = false
    @Published public private(set) var fullDiskAccess: Bool = false
    @Published public private(set) var developerTools: Bool = false
    @Published public private(set) var appManagement: Bool = false

    public init() {
        guard let center = AskForPermission.sharedCenter() else { return }
        let state = center.statusState
        accessibility = state.isAccessibilityGranted
        screenRecording = state.isScreenRecordingGranted
        inputMonitoring = state.isInputMonitoringGranted
        fullDiskAccess = state.isFullDiskAccessGranted
        developerTools = state.isDeveloperToolsGranted
        appManagement = state.isAppManagementGranted
        state.$isAccessibilityGranted.assign(to: &$accessibility)
        state.$isScreenRecordingGranted.assign(to: &$screenRecording)
        state.$isInputMonitoringGranted.assign(to: &$inputMonitoring)
        state.$isFullDiskAccessGranted.assign(to: &$fullDiskAccess)
        state.$isDeveloperToolsGranted.assign(to: &$developerTools)
        state.$isAppManagementGranted.assign(to: &$appManagement)
    }

    public func status(for kind: PermissionKind) -> Bool {
        switch kind {
        case .accessibility: return accessibility
        case .screenRecording: return screenRecording
        case .inputMonitoring: return inputMonitoring
        case .fullDiskAccess: return fullDiskAccess
        case .developerTools: return developerTools
        case .appManagement: return appManagement
        }
    }
}

extension AskForPermission {
    /// Emits the current authorization state for `kind` plus every change
    /// until the consumer cancels. Finishes immediately with a single
    /// `false` when `isAvailable` is `false`.
    public static func statusUpdates(for kind: PermissionKind) -> AsyncStream<Bool> {
        AsyncStream { continuation in
            guard let center = AskForPermission.sharedCenter() else {
                continuation.yield(false)
                continuation.finish()
                return
            }
            let publisher = center.statusState.publisher(for: kind)
            let task = Task { @MainActor in
                for await value in publisher.values {
                    continuation.yield(value)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
