import AppKit
import Foundation

@MainActor
enum SystemSettingsOpener {
    static func open(_ kind: PermissionKind) async throws {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.addsToRecentItems = false
        do {
            try await NSWorkspace.shared.open(kind.systemSettingsURL, configuration: config)
        } catch {
            throw PermissionRequestError(
                code: .openSystemSettingsFailed,
                message: "Failed to open System Settings: \(error.localizedDescription)"
            )
        }
    }
}
