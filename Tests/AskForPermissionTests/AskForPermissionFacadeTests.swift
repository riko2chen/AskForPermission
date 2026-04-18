import XCTest
@testable import AskForPermission

@MainActor
final class AskForPermissionFacadeTests: XCTestCase {
    // The test host is a Swift Package executable, not a .app bundle, so the
    // facade should always land in the unavailable branch. Each test below
    // documents a facet of that contract.

    func testIsAvailableIsFalseInUnbundledTestHost() {
        XCTAssertFalse(AskForPermission.isAvailable)
    }

    func testStatusReturnsFalseWhenUnavailable() {
        XCTAssertFalse(AskForPermission.status(for: .accessibility))
        XCTAssertFalse(AskForPermission.status(for: .screenRecording))
    }

    func testRequestReturnsUnavailableWhenUnbundled() async {
        let result = await AskForPermission.request(
            .accessibility,
            sourceRectInScreen: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        switch result {
        case .unavailable(let error):
            XCTAssertEqual(error.code, .missingHostApplicationBundle)
        default:
            XCTFail("Expected .unavailable, got \(result)")
        }
    }

    func testStatusUpdatesYieldsFalseAndFinishesWhenUnavailable() async {
        var values: [Bool] = []
        for await value in AskForPermission.statusUpdates(for: .accessibility) {
            values.append(value)
            if values.count >= 1 { break }
        }
        XCTAssertEqual(values, [false])
    }

    func testPermissionsObserverStartsFalseWhenUnavailable() {
        let observer = PermissionsObserver()
        XCTAssertFalse(observer.accessibility)
        XCTAssertFalse(observer.screenRecording)
        XCTAssertFalse(observer.status(for: .accessibility))
    }

    func testPermissionsWindowControllerReturnsNilWhenUnavailable() {
        XCTAssertNil(AskForPermission.permissionsWindowController())
    }

    func testRequestResultUnavailableIsEquatable() {
        let error = PermissionRequestError(code: .openSystemSettingsFailed, message: "x")
        XCTAssertEqual(
            PermissionRequestResult.unavailable(error),
            PermissionRequestResult.unavailable(error)
        )
        XCTAssertNotEqual(
            PermissionRequestResult.unavailable(error),
            PermissionRequestResult.cancelled
        )
    }
}
