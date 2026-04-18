# Public API

## Preferred entry point: `AskForPermission`

The top-level facade. Does not throw; runtime issues surface as
`PermissionRequestResult.unavailable(error)`.

```swift
@MainActor
public enum AskForPermission {
    public static func configure(appName: String)
    public static var isAvailable: Bool { get }

    public static func status(for kind: PermissionKind) -> Bool

    @discardableResult
    public static func request(
        _ kind: PermissionKind,
        sourceRectInScreen: CGRect,
        sourceSnapshot: NSImage? = nil
    ) async -> PermissionRequestResult

    // AppKit convenience
    @discardableResult
    public static func request(
        _ kind: PermissionKind,
        from view: NSView
    ) async -> PermissionRequestResult

    public static func permissionsWindowController() -> NSWindowController?

    /// Apply to any custom NSWindow that hosts `PermissionsView` or fires
    /// the flow. Idempotent; no-op when Stage Manager is off.
    public static func prepareHostWindow(_ window: NSWindow)

    // Live status
    public static func statusUpdates(for kind: PermissionKind) -> AsyncStream<Bool>
}
```

### SwiftUI

```swift
@MainActor
public final class PermissionsObserver: ObservableObject {
    @Published public private(set) var accessibility: Bool
    @Published public private(set) var screenRecording: Bool

    public init()
    public func status(for kind: PermissionKind) -> Bool
}

@MainActor
public struct PermissionsView: View {
    public init()
}

extension View {
    public func requestsPermission(
        _ kind: PermissionKind,
        onResult: @escaping (PermissionRequestResult) -> Void = { _ in }
    ) -> some View

    public func askForPermission(
        item: Binding<PermissionKind?>,
        onResult: @escaping (PermissionRequestResult) -> Void = { _ in }
    ) -> some View

    /// Applies the Stage Manager workaround. The three built-in surfaces
    /// above call this automatically — only needed if you roll your own
    /// trigger.
    public func prepareForPermissionsFlow() -> some View
}
```

## Supporting types

```swift
public enum PermissionKind: String, CaseIterable, Sendable {
    case accessibility
    case screenRecording

    public var displayName: String { get }
    public var shortDescription: String { get }
}

public enum PermissionRequestResult: Sendable, Equatable {
    case alreadyAuthorized
    case authorized
    case cancelled
    case timedOut
    case unavailable(PermissionRequestError)
}

public struct PermissionRequestError: Error, Sendable, Equatable {
    public enum Code: String, Sendable {
        case missingHostApplicationBundle
        case settingsWindowNotFound
        case openSystemSettingsFailed
    }
    public let code: Code
    public let message: String
}
```

## Legacy: `PermissionCenter`

Retained for source compatibility; prefer `AskForPermission` in new code.

```swift
@MainActor
public final class PermissionCenter {
    public init(appName: String? = nil) throws
    public func status(for kind: PermissionKind) -> Bool
    public func request(
        _ kind: PermissionKind,
        sourceRectInScreen: CGRect,
        sourceSnapshot: NSImage? = nil
    ) async throws -> PermissionRequestResult
    public func makePermissionsWindow() -> NSWindow
}
```

## Driving a single request

### AppKit

```swift
@IBAction func grantAccessibility(_ sender: NSButton) {
    Task { @MainActor in
        switch await AskForPermission.request(.accessibility, from: sender) {
        case .alreadyAuthorized, .authorized:
            // good to go
        case .cancelled, .timedOut:
            // user bailed
        case .unavailable(let error):
            NSLog("Permissions flow unavailable: \(error.message)")
        }
    }
}
```

### SwiftUI (tap modifier)

```swift
Text("Grant accessibility")
    .padding()
    .requestsPermission(.accessibility) { result in
        // handle result
    }
```

### SwiftUI (imperative)

```swift
@State private var pending: PermissionKind?

var body: some View {
    Button("Request accessibility") { pending = .accessibility }
        .askForPermission(item: $pending) { result in
            // handle result
        }
}
```

### Live status

```swift
@StateObject private var observer = PermissionsObserver()

var body: some View {
    if observer.accessibility {
        Text("Accessibility granted")
    } else {
        Button("Grant") { … }
    }
}
```

Or as an async sequence:

```swift
for await granted in AskForPermission.statusUpdates(for: .accessibility) {
    // reacts to every change
}
```
