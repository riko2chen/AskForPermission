# Public API

```swift
public enum PermissionKind: String, CaseIterable, Sendable {
    case accessibility
    case screenRecording

    public var displayName: String { get }
    public var shortDescription: String { get }
}

public enum PermissionRequestResult: Sendable {
    case alreadyAuthorized
    case authorized
    case cancelled
    case timedOut
}

public struct PermissionRequestError: Error, Sendable {
    public enum Code: String, Sendable {
        case missingHostApplicationBundle
        case settingsWindowNotFound
        case openSystemSettingsFailed
    }
    public let code: Code
    public let message: String
}

@MainActor
public final class PermissionCenter {
    public init(appName: String? = nil) throws
    public func status(for kind: PermissionKind) -> Bool
    public func request(
        _ kind: PermissionKind,
        sourceRectInScreen: CGRect
    ) async throws -> PermissionRequestResult
    public func makePermissionsWindow() -> NSWindow
}
```

## Driving a single permission request

Use `request(_:sourceRectInScreen:)` when you want to trigger the flow from a specific button in your own UI instead of handing over the built-in window via `makePermissionsWindow()`:

```swift
let center = try PermissionCenter()

if center.status(for: .accessibility) {
    // already authorized
} else {
    let result = try await center.request(
        .accessibility,
        sourceRectInScreen: buttonRectInScreen
    )

    switch result {
    case .alreadyAuthorized, .authorized:
        // good to go
    case .cancelled, .timedOut:
        // user bailed or did not finish in time
    }
}
```

`sourceRectInScreen` is the screen-space rect of the button the user tapped; it becomes the start point of the flight animation.
