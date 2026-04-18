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
    .package(url: "https://github.com/your-org/AskForPermission.git", from: "0.1.0"),
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
│   ├── API/            # PermissionCenter, PermissionKind, PermissionRequestResult, PermissionRequestError
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
- Running outside a `.app` bundle (e.g. via `swift run`) throws `PermissionRequestError(code: .missingHostApplicationBundle)` because the drag pasteboard needs a bundle URL.
- The library does not fall back to a non-interactive path if the user dismisses System Settings.
