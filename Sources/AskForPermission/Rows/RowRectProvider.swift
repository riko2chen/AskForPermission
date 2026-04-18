import AppKit
import SwiftUI

@MainActor
final class RowRectProvider {
    var rect: CGRect = .zero
}

struct RowRectProbeView: NSViewRepresentable {
    let provider: RowRectProvider

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(onUpdate: { [provider] newRect in
            DispatchQueue.main.async { provider.rect = newRect }
        })
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {}

    final class ProbeView: NSView {
        let onUpdate: (CGRect) -> Void
        private var windowObservers: [NSObjectProtocol] = []

        init(onUpdate: @escaping (CGRect) -> Void) {
            self.onUpdate = onUpdate
            super.init(frame: .zero)
            postsFrameChangedNotifications = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        deinit {
            let center = NotificationCenter.default
            for token in windowObservers { center.removeObserver(token) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            unsubscribeFromWindow()
            if let window { subscribe(to: window) }
            publishFrame()
        }

        override func layout() {
            super.layout()
            publishFrame()
        }

        override func resize(withOldSuperviewSize oldSize: NSSize) {
            super.resize(withOldSuperviewSize: oldSize)
            publishFrame()
        }

        private func subscribe(to window: NSWindow) {
            let center = NotificationCenter.default
            let names: [Notification.Name] = [
                NSWindow.didMoveNotification,
                NSWindow.didResizeNotification,
                NSWindow.didChangeScreenNotification,
                NSWindow.didChangeBackingPropertiesNotification,
            ]
            for name in names {
                let token = center.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.publishFrame()
                }
                windowObservers.append(token)
            }
        }

        private func unsubscribeFromWindow() {
            let center = NotificationCenter.default
            for token in windowObservers { center.removeObserver(token) }
            windowObservers.removeAll()
        }

        private func publishFrame() {
            guard let window else { return }
            let frameInWindow = convert(bounds, to: nil)
            let frameInScreen = window.convertToScreen(frameInWindow)
            onUpdate(frameInScreen)
        }
    }
}
