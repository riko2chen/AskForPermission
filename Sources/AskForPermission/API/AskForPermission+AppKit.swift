import AppKit

extension AskForPermission {
    /// Runs the guided flow using `view`'s on-screen rectangle as the
    /// flight's starting frame. `view` must be installed in a window;
    /// otherwise this returns `.unavailable` without opening System Settings.
    @discardableResult
    public static func request(
        _ kind: PermissionKind,
        from view: NSView
    ) async -> PermissionRequestResult {
        guard let window = view.window, let screenRect = screenRect(of: view) else {
            return .unavailable(PermissionRequestError(
                code: .missingHostApplicationBundle,
                message: "AskForPermission.request(_:from:) requires the view to be in a window."
            ))
        }
        prepareHostWindow(window)
        return await request(kind, sourceRectInScreen: screenRect, sourceSnapshot: nil)
    }

    /// Returns a retained `NSWindowController` wrapping the permissions
    /// onboarding window. Returns `nil` when `isAvailable` is `false`.
    /// Callers must keep the controller alive — dropping it closes the
    /// window.
    public static func permissionsWindowController() -> NSWindowController? {
        guard let center = sharedCenter() else { return nil }
        return PermissionsWindowController(window: center.makePermissionsWindow())
    }

    /// Configures `window` so the guided flow survives Stage Manager when
    /// System Settings activates. Without this, Stage Manager shoves the
    /// host window off to the side strip the moment Settings becomes
    /// frontmost, which breaks the flight's starting frame.
    ///
    /// Call on any custom window that hosts `PermissionsView` or triggers
    /// `request(_:from:)`. The SwiftUI surface applies this automatically
    /// when the view moves to a window; `permissionsWindowController()`'s
    /// window is already configured. No-op when Stage Manager is off.
    /// Idempotent.
    public static func prepareHostWindow(_ window: NSWindow) {
        guard StageManagerDetection.isActive else { return }
        window.collectionBehavior.insert(.canJoinAllSpaces)
    }

    private static func screenRect(of view: NSView) -> CGRect? {
        guard let window = view.window else { return nil }
        let rectInWindow = view.convert(view.bounds, to: nil)
        return window.convertToScreen(rectInWindow)
    }
}

@MainActor
private final class PermissionsWindowController: NSWindowController {
    override init(window: NSWindow?) {
        super.init(window: window)
        window?.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

extension PermissionsWindowController: NSWindowDelegate {}
