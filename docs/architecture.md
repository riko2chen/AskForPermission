# Architecture

## Request flow

1. `PermissionCenter.request(_:sourceRectInScreen:)` calls `SystemSettingsOpener.open(_:)`, which launches System Settings via `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility` (or `Privacy_ScreenCapture`).
2. `SystemSettingsWindowTracker` polls `CGWindowListCopyWindowInfo` until the System Settings window is on screen, waits for its frame to stabilise, and returns it.
3. `PermissionRequestFlowController` spawns a borderless **flight replicant** (an `NSPanel`) at the caller-supplied source rect and animates it along a quadratic bézier curve to a docked position next to the System Settings window.
4. Once the flight ends, the **guide panel** fades in. Its `DraggableAppIconView` is a real `NSDraggingSource`; the pasteboard item is the host app's bundle URL as `NSURL`.
5. The controller suspends via `CheckedContinuation` until the drag session ends. Dropping the icon on the System Settings list writes the app into TCC.
6. The controller polls `AXIsProcessTrusted()` / `CGPreflightScreenCaptureAccess()`. When the permission flips, the panel dismisses and `request` returns `.authorized`.
7. While the panel is visible, a secondary tracking task keeps re-anchoring it as the user drags the System Settings window around the screen.

## Design notes

### Animation

- **Single-window flight.** The in-air card is one borderless `NSPanel` that holds source and target images as layered `CALayer`s and drives a sigmoid crossfade centred at the flight's apex. One window, one set of shadows, simpler hierarchy.
- **Explicit parabolic path.** The trajectory is a quadratic bézier with a fixed 160pt apex height, paired with an ease-in-out cubic.
- **Bounce-on-arrival spring.** The guide card and its glyphs land with `interpolatingSpring(mass=1, stiffness=200, damping=11, initialVelocity=0)`. The spring is deliberately underdamped — the card visibly overshoots and settles, and the back button / up-arrow animate on with the same shape.
- **Layered shadow stack.** Replicant shadows use `shadowRadius = 2 / 15 / 3` for ambient / key / destination passes, blended with the flight's blur bell `4·t·(1-t)` so motion blur peaks at apex and vanishes at rest.

Card / replicant corner radius is 24; the replicant animates 12 → 24 across flight so it "grows up" from a row-sized card into the full guide panel. The draggable app pill is a 32×32 icon inside a 7pt rounded container filled with `white(0.8902)`, with 27pt of bottom padding on the card.

### Platform integration

- **Stage Manager.** Overlays set `.canJoinAllSpaces` + `.fullScreenAuxiliary` (and omit `.transient`) so they survive piles being rearranged when Settings activates. The permissions window only elevates to `.canJoinAllSpaces` when Stage Manager is detected (via `com.apple.WindowManager` / `GloballyEnabled`), so users without it don't see it on every Space.
- **Seamless source ↔ target hand-off.** The source row stays as a real card until the replicant is ordered front at the source rect, then flips to its dashed `COMPLETE IN SYSTEM SETTINGS` placeholder behind the replicant. The replicant carries a snapshot of the row taken synchronously at click time, so neither end of the flight has a visual gap. On the reverse flight the row un-dashes at the apex, again hidden by the replicant.
- **Cold-launching Settings.** If Settings is closed — or minimised to the Dock — when `request(_:)` is called, we open it via `x-apple.systempreferences:` and wait for its window frame to stabilise (two pixel-rounded samples in a row, with a 1.2s stabilisation budget) before computing the docked target position. This rides out both the cold-start window appearing and the genie animation from the Dock, so the flight lands where Settings actually ends up, not at a mid-animation frame.
