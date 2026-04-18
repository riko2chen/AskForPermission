import Combine
import Foundation

/// SwiftUI-friendly wrapper around the shared permission state. Publishes
/// each permission as its own `@Published` property so views can read what
/// they need without touching the underlying state model.
///
/// The observer reads from the shared `AskForPermission` center. When
/// `AskForPermission.isAvailable` is `false` (non-bundled host), both
/// properties stay at `false` and never update.
@MainActor
public final class PermissionsObserver: ObservableObject {
    @Published public private(set) var accessibility: Bool = false
    @Published public private(set) var screenRecording: Bool = false

    public init() {
        guard let center = AskForPermission.sharedCenter() else { return }
        let state = center.statusState
        accessibility = state.isAccessibilityGranted
        screenRecording = state.isScreenRecordingGranted
        state.$isAccessibilityGranted.assign(to: &$accessibility)
        state.$isScreenRecordingGranted.assign(to: &$screenRecording)
    }

    public func status(for kind: PermissionKind) -> Bool {
        switch kind {
        case .accessibility: return accessibility
        case .screenRecording: return screenRecording
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
