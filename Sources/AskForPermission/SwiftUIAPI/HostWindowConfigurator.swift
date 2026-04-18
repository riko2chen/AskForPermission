import AppKit
import SwiftUI

/// Hidden zero-size view that applies `AskForPermission.prepareHostWindow`
/// as soon as it is installed in an `NSWindow`. Used as a background on
/// every SwiftUI surface that can launch the flow so hosts don't need to
/// think about Stage Manager themselves.
struct HostWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> ConfiguratorView { ConfiguratorView() }
    func updateNSView(_ nsView: ConfiguratorView, context: Context) {}

    final class ConfiguratorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            AskForPermission.prepareHostWindow(window)
        }
    }
}

extension View {
    /// Applies the collection behavior needed to survive Stage Manager when
    /// System Settings activates. The built-in SwiftUI surfaces
    /// (`PermissionsView`, `.requestsPermission`, `.askForPermission`) call
    /// this automatically — use this explicitly only if you drive the flow
    /// from elsewhere but want the same guarantee.
    public func prepareForPermissionsFlow() -> some View {
        background(HostWindowConfigurator())
    }
}
