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

    func testAllCasesHaveDisplayName() {
        for kind in PermissionKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.shortDescription.isEmpty)
        }
    }
}
