import AppKit
import CoreGraphics
import Foundation

@MainActor
final class SystemSettingsWindowTracker {
    private let pollInterval: Duration

    init(pollInterval: Duration = .milliseconds(120)) {
        self.pollInterval = pollInterval
    }

    func waitForWindow(timeout: Duration = .seconds(6)) async throws -> CGRect {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        // Budget for frame-stabilisation AFTER we first spot the window.
        // If Settings is restoring from the Dock via the genie animation,
        // `CGWindowListCopyWindowInfo` returns mid-flight frames; returning
        // any of those would anchor our flight to the wrong end-point. We
        // wait for two consecutive samples to match (pixel-rounded to
        // tolerate sub-pixel jitter on Retina). If it never stabilises
        // within this budget we fall back to the most recent sample so the
        // flow degrades to pre-stability behaviour rather than aborting.
        let stabilisationBudget: Duration = .milliseconds(1_200)

        var firstSeenAt: ContinuousClock.Instant?
        var lastFrame: CGRect?

        while clock.now < deadline {
            if let frame = currentWindowFrame() {
                if let lastFrame, Self.framesMatch(frame, lastFrame) {
                    return frame
                }
                if firstSeenAt == nil { firstSeenAt = clock.now }
                else if let firstSeenAt, clock.now - firstSeenAt >= stabilisationBudget {
                    return frame
                }
                lastFrame = frame
            } else {
                firstSeenAt = nil
                lastFrame = nil
            }
            try await Task.sleep(for: pollInterval)
        }

        if let lastFrame { return lastFrame }
        throw PermissionRequestError(
            code: .settingsWindowNotFound,
            message: "System Settings window did not appear within the expected time."
        )
    }

    private static func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        a.integral == b.integral
    }

    func startTracking(
        onUpdate: @escaping @MainActor (CGRect) -> Void,
        onLoss: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { [pollInterval] in
            var lastFrame: CGRect?
            while !Task.isCancelled {
                let frame = await MainActor.run { self.currentWindowFrame() }
                if let frame {
                    if frame != lastFrame {
                        lastFrame = frame
                        await MainActor.run { onUpdate(frame) }
                    }
                } else if lastFrame != nil {
                    await MainActor.run { onLoss() }
                    return
                }
                try? await Task.sleep(for: pollInterval)
            }
        }
    }

    func currentWindowFrame() -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            return nil
        }

        // Pick the LARGEST qualifying Settings window so transient popovers /
        // secondary panels don't win over the main window.
        var best: CGRect?
        for info in infoList {
            guard let ownerName = info[kCGWindowOwnerName] as? String,
                  ownerName == "System Settings" || ownerName == "System Preferences"
            else {
                continue
            }
            guard let layer = info[kCGWindowLayer] as? Int, layer == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds] as? [String: CGFloat],
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else {
                continue
            }
            if frame.width < 300 || frame.height < 200 { continue }
            if best == nil || frame.width * frame.height > best!.width * best!.height {
                best = frame
            }
        }
        return best
    }
}
