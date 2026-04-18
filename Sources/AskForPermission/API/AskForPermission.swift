import AppKit
import Foundation

/// Top-level facade. Prefer this over `PermissionCenter` — none of these
/// entry points throw, and the single shared center is created lazily so
/// callers don't have to manage lifetime.
@MainActor
public enum AskForPermission {
    private static var configuredAppName: String?
    private static var cachedCenter: CachedCenter?

    private enum CachedCenter {
        case ready(PermissionCenter)
        case failed(PermissionRequestError)
    }

    /// Override the display name used in guide copy. If unset, the host
    /// bundle's `CFBundleDisplayName` / `CFBundleName` is used. Calling this
    /// after a permission has already been requested is allowed but only
    /// affects subsequent requests.
    public static func configure(appName: String) {
        configuredAppName = appName
        cachedCenter = nil
    }

    /// `true` when the host process is a `.app` bundle that can be dragged
    /// into System Settings. `false` for CLI binaries, Swift Package test
    /// hosts, and other non-bundled processes.
    public static var isAvailable: Bool {
        switch resolveCenter() {
        case .ready: return true
        case .failed: return false
        }
    }

    /// Current authorization state for `kind`. Returns `false` when
    /// `isAvailable` is `false`.
    public static func status(for kind: PermissionKind) -> Bool {
        guard case .ready(let center) = resolveCenter() else { return false }
        return center.status(for: kind)
    }

    /// Runs the guided request flow. Never throws; runtime issues surface
    /// as `.unavailable(error)`.
    @discardableResult
    public static func request(
        _ kind: PermissionKind,
        sourceRectInScreen: CGRect,
        sourceSnapshot: NSImage? = nil
    ) async -> PermissionRequestResult {
        let center: PermissionCenter
        switch resolveCenter() {
        case .ready(let c): center = c
        case .failed(let error): return .unavailable(error)
        }
        do {
            return try await center.request(
                kind,
                sourceRectInScreen: sourceRectInScreen,
                sourceSnapshot: sourceSnapshot
            )
        } catch let error as PermissionRequestError {
            return .unavailable(error)
        } catch {
            return .unavailable(PermissionRequestError(
                code: .openSystemSettingsFailed,
                message: error.localizedDescription
            ))
        }
    }

    // MARK: - Internal (used by upcoming AppKit/SwiftUI convenience layers)

    static func sharedCenter() -> PermissionCenter? {
        if case .ready(let c) = resolveCenter() { return c }
        return nil
    }

    static func cachedFailure() -> PermissionRequestError? {
        if case .failed(let e) = resolveCenter() { return e }
        return nil
    }

    private static func resolveCenter() -> CachedCenter {
        if let cached = cachedCenter { return cached }
        let resolved: CachedCenter
        do {
            let center = try PermissionCenter(appName: configuredAppName)
            resolved = .ready(center)
        } catch let error as PermissionRequestError {
            resolved = .failed(error)
        } catch {
            resolved = .failed(PermissionRequestError(
                code: .missingHostApplicationBundle,
                message: error.localizedDescription
            ))
        }
        cachedCenter = resolved
        return resolved
    }
}
