import AppKit
import Combine
import SwiftUI

@MainActor
final class FlightReplicantModel: ObservableObject {
    @Published var sourceImage: NSImage?
    @Published var targetImage: NSImage?
    @Published var progress: CGFloat = 0
    @Published var blurRadius: CGFloat = 0
    @Published var cornerRadius: CGFloat = 12
    @Published var shadowOpacity: CGFloat = 0
    @Published var contentSize: CGSize = .zero
}

struct FlightReplicantContentView: View {
    @ObservedObject var model: FlightReplicantModel

    var body: some View {
        ZStack {
            // No `.aspectRatio(...)` — both images are stretched to fill the
            // replicant's rect so a row-sized source snapshot grows smoothly
            // into the full panel-sized target snapshot without letterboxing.
            if let src = model.sourceImage {
                Image(nsImage: src)
                    .resizable()
                    .interpolation(.high)
                    .opacity(1 - model.progress)
            }
            if let tgt = model.targetImage {
                Image(nsImage: tgt)
                    .resizable()
                    .interpolation(.high)
                    .opacity(model.progress)
            }
        }
        .frame(width: model.contentSize.width, height: model.contentSize.height)
        .clipShape(RoundedRectangle(cornerRadius: model.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: model.cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08 * model.shadowOpacity), lineWidth: 1)
        )
        // Composite the image stack as a single unit *before* blurring, so
        // the blur applies uniformly to the rasterized result.
        // `.compositingGroup()` is the lightweight path here — unlike
        // `.drawingGroup()`, it doesn't allocate a Metal surface that can
        // produce a yellow "render failed" placeholder on macOS 26 when the
        // content's color space / size exceeds the group's limits.
        .compositingGroup()
        .blur(radius: model.blurRadius)
        // 3-layer shadow stack: ambient (2), key (15), destination (3).
        .shadow(color: .black.opacity(0.18 * model.shadowOpacity), radius: 2, y: 0)
        .shadow(color: .black.opacity(0.22 * model.shadowOpacity), radius: 15, y: -6)
        .shadow(color: .black.opacity(0.14 * model.shadowOpacity), radius: 3, y: 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class FlightReplicantWindow: NSPanel {
    // Padding around the content inside the window so shadows/blur don't clip.
    static let chromeInset: CGFloat = 40

    let model = FlightReplicantModel()
    private let hostingView: NSHostingView<FlightReplicantContentView>

    init() {
        self.hostingView = NSHostingView(rootView: FlightReplicantContentView(model: model))

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .screenSaver
        // `.canJoinAllSpaces` is what keeps the overlay visible across Stage
        // Manager transitions — when Settings activates, Stage Manager moves
        // our app's normal windows off-screen, and without this flag the
        // replicant gets hidden with them. `.transient` is omitted because
        // Stage Manager treats transient windows as part of the owning app's
        // Stage and pulls them aside with it.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true

        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setSourceImage(_ image: NSImage?) { model.sourceImage = image }
    func setTargetImage(_ image: NSImage?) { model.targetImage = image }

    /// Positions the replicant so that the logical content rect lives at
    /// `contentFrame`, expanded by `chromeInset` on every side so that blur
    /// halos and drop shadows have room to render outside the content.
    func apply(
        frame contentFrame: NSRect,
        cornerRadius: CGFloat,
        progress: CGFloat,
        shadowOpacity: CGFloat,
        blurRadius: CGFloat
    ) {
        let inset = Self.chromeInset
        let windowFrame = NSRect(
            x: contentFrame.minX - inset,
            y: contentFrame.minY - inset,
            width: contentFrame.width + inset * 2,
            height: contentFrame.height + inset * 2
        )
        setFrame(windowFrame, display: false)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.cornerRadius = cornerRadius
            model.progress = progress
            model.shadowOpacity = shadowOpacity
            model.blurRadius = blurRadius
            model.contentSize = contentFrame.size
        }
    }
}
