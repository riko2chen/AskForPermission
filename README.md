# AskForPermission

[English](README.md) · [中文](README.zh.md)

A macOS Swift package that delivers a polished onboarding flow for Accessibility and Screen Recording: open the correct System Settings pane, float a guide card beside it, and let the user drag the host app's icon into the permission list.

For macOS app developers who need either of these two TCC permissions.

![Demo](docs/assets/demo.gif)

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

## Minimal integration

```swift
import AppKit
import AskForPermission

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var center: PermissionCenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = try? PermissionCenter(appName: "My App")
        self.center = center
        center?.makePermissionsWindow().makeKeyAndOrderFront(nil)
    }
}
```

This drops the built-in permissions window into your app. For a button-driven single-permission request, see [docs/api.md](docs/api.md).

## Documentation

- [Architecture and request flow](docs/architecture.md)
- [Public API reference](docs/api.md)
- [Installation, examples, and development](docs/integration.md)

## License

MIT.
