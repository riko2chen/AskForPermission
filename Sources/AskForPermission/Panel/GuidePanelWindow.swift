import AppKit
import SwiftUI

@MainActor
final class GuidePanelWindow: NSPanel {
    let kind: PermissionKind
    let appName: String
    let bundleURL: URL
    let appIcon: NSImage
    let arrowRecoil = ArrowRecoilModel()
    private(set) weak var draggableView: DraggableAppIconView?

    var onBack: (() -> Void)?

    static let contentSize = GuidePanelContentView.contentSize
    static let cornerRadius: CGFloat = 24

    init(kind: PermissionKind, appName: String, bundleURL: URL, appIcon: NSImage) {
        self.kind = kind
        self.appName = appName
        self.bundleURL = bundleURL
        self.appIcon = appIcon

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        // See FlightReplicantWindow for the Stage Manager reasoning behind
        // `.canJoinAllSpaces` + omitting `.transient`.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false

        let root = GuidePanelContentView(
            kind: kind,
            appName: appName,
            bundleURL: bundleURL,
            appIcon: appIcon,
            arrowRecoil: arrowRecoil,
            onDraggableCreated: { [weak self] view in
                self?.draggableView = view
            },
            onBack: { [weak self] in
                self?.onBack?()
            }
        )
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.contentSize)
        contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
