import XCTest
@testable import AskForPermission

final class PermissionKindTests: XCTestCase {
    func testAccessibilityURLUsesModernPane() {
        XCTAssertEqual(
            PermissionKind.accessibility.systemSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        )
    }

    func testScreenRecordingURLUsesModernPane() {
        XCTAssertEqual(
            PermissionKind.screenRecording.systemSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        )
    }

    func testInputMonitoringURLUsesModernPane() {
        XCTAssertEqual(
            PermissionKind.inputMonitoring.systemSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
        )
    }

    func testFullDiskAccessURLUsesModernPane() {
        XCTAssertEqual(
            PermissionKind.fullDiskAccess.systemSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        )
    }

    func testDeveloperToolsURLUsesModernPane() {
        XCTAssertEqual(
            PermissionKind.developerTools.systemSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_DevTools"
        )
    }

    func testAppManagementURLUsesModernPane() {
        XCTAssertEqual(
            PermissionKind.appManagement.systemSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles"
        )
    }

    func testAllCasesHaveDisplayName() {
        for kind in PermissionKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.shortDescription.isEmpty)
        }
    }
}
