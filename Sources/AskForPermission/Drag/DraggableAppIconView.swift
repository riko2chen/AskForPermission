import AppKit
import SwiftUI

@MainActor
final class DraggableAppIconView: NSView, NSDraggingSource {
    private let dragThreshold: CGFloat = 3
    private let bundleURL: URL
    private let appName: String
    private let appIcon: NSImage
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let background: NSView
    private let iconSize: NSSize = NSSize(width: 32, height: 32)
    private var mouseDownEvent: NSEvent?
    private var hasStartedDrag = false

    var onDragStarted: (() -> Void)?
    var onDragMoved: ((NSPoint) -> Void)?
    var onDragEnded: ((NSDragOperation) -> Void)?

    init(bundleURL: URL, appName: String) {
        self.bundleURL = bundleURL
        self.appName = appName
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 32, height: 32)
        self.appIcon = icon
        self.iconView = NSImageView(image: icon)
        self.nameLabel = NSTextField(labelWithString: appName)
        self.background = NSView()

        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 44))
        wantsLayer = true
        setupSubviews()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 44)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override var isFlipped: Bool { false }

    private func setupSubviews() {
        background.wantsLayer = true
        background.layer?.cornerRadius = 7
        background.layer?.backgroundColor = NSColor(calibratedWhite: 0.8902, alpha: 1).cgColor
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(iconView)

        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        // Allow the label to compress if the hosting view shrinks below the
        // label's intrinsic width, so AppKit doesn't log
        // "Unable to simultaneously satisfy constraints" during drag setup.
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        background.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize.width),
            iconView.heightAnchor.constraint(equalToConstant: iconSize.height),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
        let labelTrailing = nameLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: background.trailingAnchor, constant: -10
        )
        labelTrailing.priority = .defaultHigh
        labelTrailing.isActive = true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        hasStartedDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent, !hasStartedDrag else {
            super.mouseDragged(with: event)
            return
        }
        let distance = hypot(
            event.locationInWindow.x - down.locationInWindow.x,
            event.locationInWindow.y - down.locationInWindow.y
        )
        guard distance >= dragThreshold else { return }
        hasStartedDrag = true
        startDrag(with: down)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
        hasStartedDrag = false
        super.mouseUp(with: event)
    }

    private func startDrag(with event: NSEvent) {
        onDragStarted?()
        let item = NSDraggingItem(pasteboardWriter: bundleURL as NSURL)

        // Drag preview = full row snapshot, so the entire horizontal row
        // (icon + app name, padded background) flies into System Settings
        // instead of just the 32×32 icon.
        let rowImage = renderRowSnapshot() ?? appIcon
        item.setDraggingFrame(bounds, contents: rowImage)

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .none
    }

    private func renderRowSnapshot() -> NSImage? {
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        let raw = NSImage(size: bounds.size)
        raw.addRepresentation(rep)

        // Clip to the same 7pt rounded rect as the inner box so the drag
        // preview matches what the user sees in the card.
        let clipped = NSImage(size: bounds.size)
        clipped.lockFocus()
        let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: bounds.size),
                                xRadius: 7, yRadius: 7)
        path.addClip()
        raw.draw(in: NSRect(origin: .zero, size: bounds.size))
        clipped.unlockFocus()
        return clipped
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation { .copy }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {}

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        onDragMoved?(screenPoint)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        hasStartedDrag = false
        onDragEnded?(operation)
    }
}

struct DraggableAppIconRepresentable: NSViewRepresentable {
    let bundleURL: URL
    let appName: String
    let onCreated: (DraggableAppIconView) -> Void

    func makeNSView(context: Context) -> DraggableAppIconView {
        let view = DraggableAppIconView(bundleURL: bundleURL, appName: appName)
        DispatchQueue.main.async { onCreated(view) }
        return view
    }

    func updateNSView(_ nsView: DraggableAppIconView, context: Context) {}
}
