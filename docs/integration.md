# Integration, examples, and development

## Requirements

- macOS 13 or later
- Swift 5.9+ (Xcode 15+)
- Your app must ship as a real `.app` bundle at runtime (the drag pasteboard uses `Bundle.main.bundleURL`)

## Installation

### Xcode

`File` → `Add Package Dependencies…` → paste the repository URL or use **Add Local…** to point at your checkout. Add `AskForPermission` to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/riko2chen/AskForPermission.git", from: "0.1.0"),
    // or for a local checkout:
    // .package(path: "../AskForPermission"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AskForPermission", package: "AskForPermission"),
        ]
    ),
]
```

## Running the example

```bash
./Examples/AskForPermissionExample/build.sh
open Examples/AskForPermissionExample/build/AskForPermissionExample.app
```

The build script compiles the library into a module + object file first, then links the example binary against it, so the example goes through `import AskForPermission` exactly like a real dependent would.

## Project layout

```
AskForPermission/
├── Package.swift
├── Sources/AskForPermission/
│   ├── API/            # AskForPermission facade, PermissionCenter, PermissionKind, result/error types, PermissionsObserver
│   ├── SwiftUIAPI/     # PermissionsView, View modifiers, ScreenRectReader
│   ├── Status/         # PermissionStatusModel — TCC status polling
│   ├── List/           # PermissionsListWindow + PermissionsListRootView
│   ├── Rows/           # PermissionRowCatalog, PermissionRowView, RowRectProvider
│   ├── Flow/           # PermissionRequestFlowController — the state machine
│   ├── SystemSettings/ # SystemSettingsOpener, SystemSettingsWindowTracker
│   ├── Panel/          # GuidePanelWindow, GuidePanelContentView, ArrowRecoilModel
│   ├── Replicant/      # FlightReplicantWindow
│   ├── Drag/           # DraggableAppIconView (NSDraggingSource)
│   └── Platform/       # StageManagerDetection, ViewSnapshot
├── Tests/AskForPermissionTests/
└── Examples/AskForPermissionExample/
```

## Development

```bash
# Library
swift build
swift test

# Example .app
./Examples/AskForPermissionExample/build.sh
```

## Known limits

- System Settings window discovery relies on `CGWindowListCopyWindowInfo` and matches the owner name `System Settings` / `System Preferences`. Apple can change this in future releases.
- Screen Recording often requires the host app to relaunch before capture APIs fully work.
- Running outside a `.app` bundle (e.g. via `swift run`) makes `AskForPermission.isAvailable` report `false`, and `request` returns `.unavailable(PermissionRequestError(code: .missingHostApplicationBundle, …))`. `PermissionCenter.init` still throws in that case for back-compat.
- After the user drops onto the Settings list, the flow waits up to **10 s** for the TCC prompt to resolve. It resolves early when: (a) TCC grants, (b) the Settings sheet count drops (user clicked Allow / Don't Allow / Cancel), or (c) the host app regains focus. Past 10 s the row reverts to its CTA state; the global 0.75 s status poller still picks up late grants.
- The library does not fall back to a non-interactive path if the user dismisses System Settings.

## Minimal integration (SwiftUI)

```swift
import AskForPermission
import SwiftUI

@main
struct MyApp: App {
    init() {
        AskForPermission.configure(appName: "My App")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var permissions = PermissionsObserver()
    @State private var pending: PermissionKind?

    var body: some View {
        VStack {
            if permissions.accessibility {
                Text("Ready to go")
            } else {
                Button("Grant accessibility") { pending = .accessibility }
            }
        }
        .askForPermission(item: $pending)
    }
}
```

## Minimal integration (AppKit)

```swift
import AskForPermission
import AppKit

final class MyViewController: NSViewController {
    @objc func grant(_ sender: NSButton) {
        Task { @MainActor in
            _ = await AskForPermission.request(.accessibility, from: sender)
        }
    }
}
```
