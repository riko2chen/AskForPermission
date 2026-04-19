# AskForPermission

[English](README.md) · [中文](README.zh.md)

A macOS Swift package that delivers a polished onboarding flow for macOS TCC permissions: open the correct System Settings pane, float a guide card beside it, and let the user drag the host app's icon into the permission list.

For macOS app developers who need any TCC permission granted by dragging an app into a list.

https://github.com/user-attachments/assets/8360c7a3-2546-4f8c-92d7-247ae460f5ce

![Demo](docs/assets/demo.gif)

## Supported permissions

Any Privacy & Security pane that follows the "drag app into a list" flow:

| Permission | `PermissionKind` |
|---|---|
| Accessibility | `.accessibility` |
| Screen & System Audio Recording | `.screenRecording` |
| Input Monitoring | `.inputMonitoring` |
| Full Disk Access | `.fullDiskAccess` |
| Developer Tools | `.developerTools` |
| App Management | `.appManagement` |

Detection mechanics and out-of-scope permissions are covered in [`docs/architecture.md`](docs/architecture.md#supported-permissions).

## Compared to Codex Computer Use

The flow mirrors the Codex Computer Use onboarding experience visually and behaviourally. Implementation choices differ on a few axes.

**Shared**

- Card flies out from the button position and docks beside the System Settings window
- Draggable app icon on the card; drop onto the list to grant
- Underdamped spring on arrival, so the card and arrow visibly overshoot and settle
- Card follows the System Settings window as it moves
- Works under Stage Manager

**Different**

- Flight: single `NSPanel` with a layered `CALayer` crossfade
- Path: explicit quadratic bézier with a fixed 160pt apex height
- No visual gap at either end of the flight (the source row only flips to its dashed placeholder once the replicant is in position)
- Cold-launch / restore from Dock: waits for the Settings window frame to stabilise before computing the target position

## Try the example

After cloning, the bundled example app demonstrates every entry point (built-in window, SwiftUI surface, and AppKit convenience) in a single tabbed window.

```bash
git clone https://github.com/riko2chen/AskForPermission.git
cd AskForPermission
./Examples/AskForPermissionExample/build.sh
open Examples/AskForPermissionExample/build/AskForPermissionExample.app
```

Requirements: macOS 13 or later, Xcode 15+ (for Swift 5.9 toolchain). The build script produces a signed `.app` in `Examples/AskForPermissionExample/build/` — no Xcode project needed.

To reset the example's TCC grants between runs:

```bash
tccutil reset All com.example.askforpermission.example
killall AskForPermissionExample 2>/dev/null
```

## Minimal integration

```swift
import AppKit
import AskForPermission

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AskForPermission.configure(appName: "My App")
        controller = AskForPermission.permissionsWindowController()
        controller?.showWindow(nil)
    }
}
```

This drops the built-in permissions window into your app. For SwiftUI hosts, use the `PermissionsView` view directly, or attach `.requestsPermission(_:)` / `.askForPermission(item:)` to your own buttons. For a button-driven single-permission request from AppKit, call `AskForPermission.request(_:from: NSButton)`. See [docs/api.md](docs/api.md) for the full surface.

## Documentation

- [Architecture and request flow](docs/architecture.md)
- [Public API reference](docs/api.md)
- [Installation, examples, and development](docs/integration.md)

## License

MIT.
