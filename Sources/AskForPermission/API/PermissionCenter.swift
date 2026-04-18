import AppKit
import Foundation

@MainActor
public final class PermissionCenter {
    private let state: PermissionStatusModel
    private let flow: PermissionRequestFlowController
    private let bundleURL: URL
    private let appName: String

    public init(appName: String? = nil) throws {
        let resolvedBundleURL = try Self.resolveHostApplicationBundle()
        let resolvedAppName = appName
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "This App"

        self.bundleURL = resolvedBundleURL
        self.appName = resolvedAppName
        self.state = PermissionStatusModel()
        self.flow = PermissionRequestFlowController(
            bundleURL: resolvedBundleURL,
            appName: resolvedAppName
        )
    }

    public func status(for kind: PermissionKind) -> Bool {
        state.refresh()
        return state.isGranted(kind)
    }

    @discardableResult
    public func request(
        _ kind: PermissionKind,
        sourceRectInScreen: CGRect,
        sourceSnapshot: NSImage? = nil
    ) async throws -> PermissionRequestResult {
        if status(for: kind) { return .alreadyAuthorized }
        let snapshot = sourceSnapshot ?? captureInProcessScreenRegion(sourceRectInScreen)
        return try await flow.run(
            kind: kind,
            sourceRectProvider: { sourceRectInScreen },
            sourceSnapshot: snapshot,
            state: state
        )
    }

    public func makePermissionsWindow() -> NSWindow {
        PermissionsListWindow(state: state, flow: flow)
    }

    var statusState: PermissionStatusModel { state }
    var requestFlow: PermissionRequestFlowController { flow }

    private static func resolveHostApplicationBundle() throws -> URL {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        if bundleURL.pathExtension == "app" { return bundleURL }
        let parent = bundleURL.deletingLastPathComponent().standardizedFileURL
        if parent.pathExtension == "app" { return parent }
        throw PermissionRequestError(
            code: .missingHostApplicationBundle,
            message: "AskForPermission must run from a .app bundle so the host app can be dragged into System Settings."
        )
    }
}
