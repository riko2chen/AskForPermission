import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class PermissionRequestFlowController {
    private let bundleURL: URL
    private let appName: String
    private let appIcon: NSImage

    private var panel: GuidePanelWindow?
    private var replicant: FlightReplicantWindow?
    private var trackingTask: Task<Void, Never>?
    private var dragContinuation: CheckedContinuation<DragOutcome, Never>?

    // Previous panel-frame sample, used to derive the vertical velocity we
    // feed into the arrow recoil model on each tracker tick.
    private var lastPanelMidY: CGFloat?
    private var lastPanelSampleTime: CFTimeInterval?

    private enum DragOutcome {
        case dropped(NSDragOperation)
        case userCancelled
    }

    init(bundleURL: URL, appName: String) {
        self.bundleURL = bundleURL
        self.appName = appName
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 72, height: 72)
        self.appIcon = icon
    }

    func run(
        kind: PermissionKind,
        sourceRectProvider: @escaping @MainActor () -> CGRect,
        sourceSnapshot: NSImage?,
        state: PermissionStatusModel
    ) async throws -> PermissionRequestResult {
        state.inProgressPermission = kind
        defer {
            state.inProgressPermission = nil
            teardown()
        }

        let initialSourceRect = sourceRectProvider()

        // Remember which in-process window owns the source row so we can
        // bring it back to the foreground after System Settings activates —
        // otherwise the user never sees the flight start at the row.
        let sourceWindow: NSWindow? = NSApp.windows.first { w in
            w.isVisible && !w.isMiniaturized && w.frame.intersects(initialSourceRect)
        }

        try await SystemSettingsOpener.open(kind)

        let tracker = SystemSettingsWindowTracker()
        let settingsFrame = try await tracker.waitForWindow(timeout: .seconds(6))

        // System Settings is now frontmost. Reactivate our app and pull the
        // source window back on top so the flight's starting frame is visible.
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        sourceWindow?.orderFrontRegardless()

        let panel = GuidePanelWindow(
            kind: kind,
            appName: appName,
            bundleURL: bundleURL,
            appIcon: appIcon
        )
        panel.onBack = { [weak self] in self?.handleBackTap() }
        self.panel = panel

        let targetFrame = dockedFrame(for: panel, near: settingsFrame)
        // Re-query so the flight launches from the row's CURRENT screen
        // position — the user may have dragged the host window between the
        // click and System Settings actually appearing.
        let sourceFrame = sourceRectProvider()

        let targetImage = renderPanelSnapshot(panel: panel, targetFrame: targetFrame)

        let replicant = FlightReplicantWindow()
        replicant.setSourceImage(sourceSnapshot)
        replicant.setTargetImage(targetImage)
        self.replicant = replicant

        // Flip the row to its dashed-placeholder state RIGHT before the
        // flight starts. The replicant appears at the source rect at the
        // same frame and masks the row's cross-fade, so the handoff is
        // invisible. Flipping at click time instead produced a "vacuum"
        // on the card while we were still waiting for Settings to appear.
        state.activePermissionRequest = kind

        await runEntranceAnimation(
            sourceFrame: sourceFrame,
            targetFrame: targetFrame,
            replicant: replicant,
            panel: panel
        )

        // Flight complete — hand focus back to System Settings so the user
        // can drop on its list. Our guide panel is a non-activating
        // floating panel so it stays visible above Settings.
        activateSystemSettings()

        // Seed the velocity sampler with the post-entrance resting position
        // so the first tracker update measures displacement from the docked
        // frame, not from zero.
        lastPanelMidY = targetFrame.midY
        lastPanelSampleTime = CACurrentMediaTime()

        trackingTask = tracker.startTracking(
            onUpdate: { [weak self] frame in
                guard let self, let panel = self.panel else { return }
                let updated = self.dockedFrame(for: panel, near: frame)
                let now = CACurrentMediaTime()
                if let prevY = self.lastPanelMidY,
                   let prevT = self.lastPanelSampleTime,
                   now - prevT > 0 {
                    let dy = updated.midY - prevY
                    let vy = dy / CGFloat(now - prevT)
                    panel.arrowRecoil.kick(verticalVelocityPerSecond: vy)
                }
                self.lastPanelMidY = updated.midY
                self.lastPanelSampleTime = now
                panel.setFrame(updated, display: true, animate: false)
            },
            onLoss: { [weak self] in self?.teardown() }
        )

        panel.draggableView?.onDragEnded = { [weak self] operation in
            self?.dragContinuation?.resume(returning: .dropped(operation))
            self?.dragContinuation = nil
        }

        let outcome = await awaitDropOnSettingsList()
        // Re-query so the card flies home to the row's CURRENT position —
        // the user may have moved the window during the wait.
        let reverseSourceFrame = sourceRectProvider()
        // Clear the row's "active/dashed" state at the reverse flight's
        // apex so the row flips back to its normal (or granted) layout
        // while the replicant is overhead — not after landing, which used
        // to cause a visible flash as the row un-dashed post-reveal.
        let clearActiveState: @MainActor () -> Void = {
            state.activePermissionRequest = nil
            state.inProgressPermission = nil
        }
        switch outcome {
        case .userCancelled:
            await runReverseTransition(
                sourceFrame: reverseSourceFrame,
                targetFrame: targetFrame,
                panel: panel,
                sourceImage: sourceSnapshot,
                targetImage: targetImage,
                onApex: clearActiveState
            )
            return .cancelled
        case .dropped:
            // Drop landed on Settings' permission list — macOS now shows its
            // own TCC prompt on top. The reverse flight would compete with
            // that system dialog, so we just hide the guide panel and
            // replicant outright. We deliberately KEEP the row in its dashed
            // "COMPLETE IN SYSTEM SETTINGS" state while the user decides in
            // the TCC dialog: if they click Allow, `isGranted` flips and we
            // clear the dashed state so the row cross-fades to "Done ✓"; if
            // they dismiss/deny (poll times out), we clear the dashed state
            // so the row reverts to the initial CTA button layout.
            panel.orderOut(nil)
            replicant.orderOut(nil)
            let granted = await TCCPromptWatcher.waitForResolution(
                kind: kind,
                state: state,
                timeout: .seconds(10)
            )
            clearActiveState()
            return granted ? .authorized : .timedOut
        }
    }

    // MARK: - Back button / drag wait

    private func handleBackTap() {
        dragContinuation?.resume(returning: .userCancelled)
        dragContinuation = nil
    }

    private func awaitDropOnSettingsList() async -> DragOutcome {
        await withCheckedContinuation { (continuation: CheckedContinuation<DragOutcome, Never>) in
            self.dragContinuation = continuation
        }
    }

    // MARK: - Geometry

    private func dockedFrame(
        for panel: NSWindow,
        near settingsFrame: CGRect
    ) -> NSRect {
        let size = panel.frame.size
        let appKitSettings = convertToAppKitCoordinates(settingsFrame)
        let screen = NSScreen.screens.first { $0.frame.intersects(appKitSettings) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? appKitSettings

        // Dock the card INSIDE the Settings window, aligned to its bottom-right
        // corner with a fixed inset. AppKit Y is bottom-up, so `minY` is the
        // bottom edge of Settings.
        let inset: CGFloat = 16
        let preferredX = appKitSettings.maxX - size.width - inset
        let preferredY = appKitSettings.minY + inset

        // Keep the card on-screen if Settings is positioned such that its
        // bottom-right corner pushes the card off the visible frame.
        let x = min(max(preferredX, visible.minX + 8), visible.maxX - size.width - 8)
        let y = min(max(preferredY, visible.minY + 8), visible.maxY - size.height - 8)

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func activateSystemSettings() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences")
        guard let settings = apps.first else { return }
        if #available(macOS 14.0, *) {
            settings.activate(from: .current, options: [])
        } else {
            settings.activate(options: [])
        }
    }

    private func convertToAppKitCoordinates(_ cgRect: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return cgRect }
        let primaryHeight = primary.frame.height
        return NSRect(
            x: cgRect.origin.x,
            y: primaryHeight - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    // MARK: - Snapshot

    private func renderPanelSnapshot(
        panel: GuidePanelWindow,
        targetFrame: NSRect
    ) -> NSImage? {
        // Render the SwiftUI content directly via ImageRenderer. Doing this
        // off-screen (without first ordering the window front) avoids the
        // cacheDisplay failures that started happening on macOS 26.
        let root = GuidePanelContentView(
            kind: panel.kind,
            appName: panel.appName,
            bundleURL: panel.bundleURL,
            appIcon: panel.appIcon,
            arrowRecoil: ArrowRecoilModel(),  // inert: snapshot is a still frame
            onDraggableCreated: { _ in },
            onBack: {},
            isStaticRender: true
        )
        let renderer = ImageRenderer(content: root)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(
            width: targetFrame.width,
            height: targetFrame.height
        )
        return renderer.nsImage
    }

    // MARK: - Entrance animation (parabola + blur bell + apex crossfade)

    private func runEntranceAnimation(
        sourceFrame: NSRect,
        targetFrame: NSRect,
        replicant: FlightReplicantWindow,
        panel: GuidePanelWindow
    ) async {
        replicant.apply(
            frame: sourceFrame,
            cornerRadius: 12,
            progress: 0,
            shadowOpacity: 0,
            blurRadius: 0
        )
        replicant.orderFrontRegardless()

        let duration: TimeInterval = 0.78
        let maxBlur: CGFloat = 12
        let arcHeight: CGFloat = 160

        let startTime = CACurrentMediaTime()
        while true {
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(max(elapsed / duration, 0), 1)
            let eased = easeInOutCubic(t)

            let center = parabolicPoint(
                t: eased,
                start: CGPoint(x: sourceFrame.midX, y: sourceFrame.midY),
                end: CGPoint(x: targetFrame.midX, y: targetFrame.midY),
                arcHeight: arcHeight
            )
            let width = sourceFrame.width + (targetFrame.width - sourceFrame.width) * CGFloat(eased)
            let height = sourceFrame.height + (targetFrame.height - sourceFrame.height) * CGFloat(eased)
            let frame = NSRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height
            )
            let cornerRadius = 12 + (GuidePanelWindow.cornerRadius - 12) * CGFloat(eased)
            let blurRadius = bellBlur(t) * maxBlur
            let crossfade = apexCrossfade(t)  // 0 → 1 sigmoid centered at apex

            replicant.apply(
                frame: frame,
                cornerRadius: cornerRadius,
                progress: crossfade,
                shadowOpacity: CGFloat(eased),
                blurRadius: blurRadius
            )

            if t >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }

        panel.setFrame(targetFrame, display: true, animate: false)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        replicant.orderOut(nil)
    }

    // MARK: - Reverse transition (target → source with reversed curves)

    private func runReverseTransition(
        sourceFrame: NSRect,
        targetFrame: NSRect,
        panel: GuidePanelWindow,
        sourceImage: NSImage?,
        targetImage: NSImage?,
        onApex: @MainActor @escaping () -> Void = {}
    ) async {
        let replicant = self.replicant ?? {
            let r = FlightReplicantWindow()
            r.setSourceImage(sourceImage)
            r.setTargetImage(targetImage)
            self.replicant = r
            return r
        }()

        replicant.apply(
            frame: targetFrame,
            cornerRadius: GuidePanelWindow.cornerRadius,
            progress: 1,
            shadowOpacity: 1,
            blurRadius: 0
        )
        replicant.orderFrontRegardless()
        panel.orderOut(nil)

        let duration: TimeInterval = 0.6
        let maxBlur: CGFloat = 12
        let arcHeight: CGFloat = 160
        let startTime = CACurrentMediaTime()
        var apexFired = false
        while true {
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(max(elapsed / duration, 0), 1)
            let eased = easeInOutCubic(t)
            let reverseT = 1 - eased

            // Fire onApex once as the replicant passes the parabola's peak.
            // The replicant is at its furthest point from the source row AND
            // directly on the crossfade midpoint (target snapshot → source
            // snapshot within the replicant itself), so swapping the row's
            // dashed "active" state back to its final state is hidden by the
            // replicant's own content swap and by the card being mid-air.
            if !apexFired && t >= 0.5 {
                apexFired = true
                onApex()
            }

            let center = parabolicPoint(
                t: reverseT,
                start: CGPoint(x: sourceFrame.midX, y: sourceFrame.midY),
                end: CGPoint(x: targetFrame.midX, y: targetFrame.midY),
                arcHeight: arcHeight
            )
            let width = sourceFrame.width + (targetFrame.width - sourceFrame.width) * CGFloat(reverseT)
            let height = sourceFrame.height + (targetFrame.height - sourceFrame.height) * CGFloat(reverseT)
            let frame = NSRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height
            )
            let cornerRadius = 12 + (GuidePanelWindow.cornerRadius - 12) * CGFloat(reverseT)
            let blurRadius = bellBlur(t) * maxBlur
            let crossfade = 1 - apexCrossfade(t)

            replicant.apply(
                frame: frame,
                cornerRadius: cornerRadius,
                progress: crossfade,
                shadowOpacity: CGFloat(reverseT),
                blurRadius: blurRadius
            )
            if t >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
        replicant.orderOut(nil)
    }

    // MARK: - Teardown

    private func teardown() {
        trackingTask?.cancel()
        trackingTask = nil
        panel?.orderOut(nil)
        panel = nil
        replicant?.orderOut(nil)
        replicant = nil
        dragContinuation?.resume(returning: .userCancelled)
        dragContinuation = nil
    }

    // MARK: - Math

    private func parabolicPoint(
        t: Double,
        start: CGPoint,
        end: CGPoint,
        arcHeight: CGFloat
    ) -> CGPoint {
        let control = CGPoint(
            x: (start.x + end.x) / 2,
            y: max(start.y, end.y) + arcHeight
        )
        let u = 1 - t
        return CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
    }

    /// Bell-shaped blur curve: 0 at t=0, peaks at t=0.5 (apex of parabola), 0 at t=1.
    /// Quadratic: 4·t·(1-t), which is 0 at edges, 1 at midpoint.
    private func bellBlur(_ t: Double) -> CGFloat {
        CGFloat(4 * t * (1 - t))
    }

    /// Sigmoid-like crossfade concentrated near the apex (t=0.5).
    /// Content stays as source image through the first ~35% of the flight,
    /// then swaps to target over ~30%, then stays target through the last 35%.
    private func apexCrossfade(_ t: Double) -> CGFloat {
        if t < 0.35 { return 0 }
        if t > 0.65 { return 1 }
        let local = (t - 0.35) / 0.3
        // smoothstep
        let s = local * local * (3 - 2 * local)
        return CGFloat(s)
    }

    private func easeInOutCubic(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
}
