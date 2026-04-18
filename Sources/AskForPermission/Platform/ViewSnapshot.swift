import AppKit

/// Synchronously captures the visual contents of whichever in-process NSWindow
/// currently contains the given screen-space rectangle, returning an NSImage
/// the same size as the rectangle. Returns nil if no in-process window covers
/// the rectangle.
///
/// Uses `NSView.cacheDisplay(in:to:)` against the window's content view, which
/// does not require Screen Recording permission (we render our own views, not
/// the global screen buffer).
@MainActor
func captureInProcessScreenRegion(_ screenRect: CGRect) -> NSImage? {
    for window in NSApp.windows {
        guard window.isVisible, !window.isMiniaturized else { continue }
        guard window.frame.intersects(screenRect) else { continue }
        guard let contentView = window.contentView else { continue }

        let rectInWindow = window.convertFromScreen(screenRect)
        let rectInContent = contentView.convert(rectInWindow, from: nil)
        guard rectInContent.width > 1 && rectInContent.height > 1 else { continue }
        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: rectInContent) else {
            continue
        }
        contentView.cacheDisplay(in: rectInContent, to: rep)
        let image = NSImage(size: rectInContent.size)
        image.addRepresentation(rep)
        return image
    }
    return nil
}
