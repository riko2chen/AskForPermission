import AppKit
import SwiftUI

/// Vertical-motion recoil for the up-arrow while the guide panel follows a
/// dragged System Settings window.
///
/// The panel follows Settings 1-for-1, so without feedback the glyph reads as
/// rigidly glued. Feeding the tracker's observed velocity into this model
/// produces a whip-tail deformation — the bottom of the arrow stays pinned,
/// the top stretches in the direction opposite to motion (G-force / recoil).
/// Magnitude decays back to identity through a spring when motion stops.
@MainActor
final class ArrowRecoilModel: ObservableObject {
    /// Vertical scale factor, anchored at the arrow's bottom edge. 1 = rest.
    /// Values > 1 stretch upward (overflows the row frame, by design).
    /// Values < 1 compress.
    @Published var recoilScaleY: CGFloat = 1.0

    private var relaxTask: Task<Void, Never>?

    /// Inject observed vertical velocity (points/second, AppKit coords:
    /// + is up, − is down). Repeated calls keep the arrow deformed; the
    /// spring back to identity fires ~150 ms after the last call.
    func kick(verticalVelocityPerSecond dy: CGFloat) {
        relaxTask?.cancel()
        // Saturate around 2200 pt/s so a fast fling caps the stretch at 2×.
        let normalized = max(min(dy / 2200.0, 1.0), -1.0)
        // Opposite-direction stretch: window moving DOWN (dy<0) → scaleY>1,
        // which with .anchor(.bottom) extends the top of the glyph upward,
        // i.e. the arrow's top "trails" the motion like a weight on a string.
        let target = 1.0 - normalized * 1.0
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 220, damping: 13)) {
            recoilScaleY = target
        }
        relaxTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            guard let self else { return }
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 180, damping: 14)) {
                self.recoilScaleY = 1.0
            }
            // After the recoil visibly settles (~1.0s for this spring), dwell
            // 1.0s, then play a one-shot max-amplitude "burp" so the arrow
            // punctuates the end of the interaction with a final flex.
            try? await Task.sleep(for: .milliseconds(1000 + 1000))
            if Task.isCancelled { return }
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 220, damping: 13)) {
                self.recoilScaleY = 2.0
            }
            try? await Task.sleep(for: .milliseconds(220))
            if Task.isCancelled { return }
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 180, damping: 14)) {
                self.recoilScaleY = 1.0
            }
        }
    }

    func reset() {
        relaxTask?.cancel()
        relaxTask = nil
        recoilScaleY = 1.0
    }
}

struct GuidePanelContentView: View {
    let kind: PermissionKind
    let appName: String
    let bundleURL: URL
    let appIcon: NSImage
    let onDraggableCreated: (DraggableAppIconView) -> Void
    let onBack: () -> Void
    /// When true, skip entrance animation (used when rendering a static
    /// snapshot for the replicant's target image).
    let isStaticRender: Bool

    @ObservedObject var arrowRecoil: ArrowRecoilModel

    static let contentSize = CGSize(width: 540, height: 130)
    static let cardCornerRadius: CGFloat = 22

    // Initial state depends on render mode: static snapshot starts at the
    // final pose (so the snapshot looks settled); a live render starts at
    // the pre-entrance pose so the spring can run without a first-frame flash.
    @State private var arrowScale: CGFloat
    @State private var arrowOffsetY: CGFloat
    @State private var arrowOpacity: CGFloat

    init(
        kind: PermissionKind,
        appName: String,
        bundleURL: URL,
        appIcon: NSImage,
        arrowRecoil: ArrowRecoilModel,
        onDraggableCreated: @escaping (DraggableAppIconView) -> Void,
        onBack: @escaping () -> Void,
        isStaticRender: Bool = false
    ) {
        self.kind = kind
        self.appName = appName
        self.bundleURL = bundleURL
        self.appIcon = appIcon
        self.onDraggableCreated = onDraggableCreated
        self.onBack = onBack
        self.isStaticRender = isStaticRender
        self._arrowRecoil = ObservedObject(wrappedValue: arrowRecoil)
        _arrowScale = State(initialValue: isStaticRender ? 1.0 : 0.2)
        _arrowOffsetY = State(initialValue: isStaticRender ? 0 : 18)
        _arrowOpacity = State(initialValue: isStaticRender ? 1 : 0)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            card

            GuideBackButton(action: onBack)
                .padding(.leading, 10)
                .padding(.top, (Self.contentSize.height - 32) / 2)
        }
        .frame(width: Self.contentSize.width,
               height: Self.contentSize.height,
               alignment: .topLeading)
        .onAppear(perform: playEntranceAnimations)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            instructionRow
            draggableRow
                .frame(height: 44)
        }
        .padding(.top, 14)
        .padding(.bottom, 14)
        .padding(.leading, 52)   // room on the left for the back button
        .padding(.trailing, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    // `ImageRenderer` cannot flatten `NSViewRepresentable`, so the static
    // snapshot path uses a pure-SwiftUI stand-in sized/styled identically to
    // `DraggableAppIconView` (box cornerRadius 7, fill white 0.8902,
    // icon 32×32). The live path keeps the real NSView so drag sessions
    // originate from an `NSDraggingSource`.
    @ViewBuilder
    private var draggableRow: some View {
        if isStaticRender {
            HStack(spacing: 10) {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)
                Text(appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(white: 0.8902))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
        } else {
            DraggableAppIconRepresentable(
                bundleURL: bundleURL,
                appName: appName,
                onCreated: onDraggableCreated
            )
        }
    }

    private var instructionRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .shadow(color: Color.accentColor.opacity(0.45), radius: 6, x: 0, y: 2)
                .frame(width: 28, height: 28)
                // Recoil before entrance: deform the glyph itself about its
                // bottom edge, then let the entrance spring scale uniformly.
                .scaleEffect(x: 1, y: arrowRecoil.recoilScaleY, anchor: .bottom)
                .scaleEffect(arrowScale)
                .offset(y: arrowOffsetY)
                .opacity(arrowOpacity)

            captionText
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .opacity(arrowOpacity)

            Spacer(minLength: 0)
        }
    }

    private var captionText: Text {
        Text("Drag ")
            + Text(appName).fontWeight(.semibold)
            + Text(" to the list above to allow ")
            + Text(kind.displayName).fontWeight(.semibold)
    }

    private func playEntranceAnimations() {
        guard !isStaticRender else { return }
        // State already starts pre-entrance (init-time). Animate to final
        // with a visibly underdamped spring; initialVelocity carries the
        // "kicked loose by the card's landing" impulse.
        let spring = Animation.interpolatingSpring(
            mass: 1, stiffness: 200, damping: 11, initialVelocity: 18
        )
        withAnimation(spring) {
            arrowScale = 1.0
            arrowOffsetY = 0
            arrowOpacity = 1
        }
    }
}

private struct GuideBackButton: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
