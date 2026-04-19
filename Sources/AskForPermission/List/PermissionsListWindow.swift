import AppKit
import SwiftUI

@MainActor
final class PermissionsListWindow: NSWindow {
    init(state: PermissionStatusModel, flow: PermissionRequestFlowController) {
        let size = PermissionsListRootView.rootSize
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Permissions"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        center()
        isReleasedWhenClosed = false

        // When Stage Manager is on, a normal titled window gets shoved to the
        // side strip the moment Settings activates, which kills the origin of
        // our flight. `.canJoinAllSpaces` lets the window stay on-screen while
        // Stage Manager rearranges piles. We only set it when Stage Manager is
        // active so users without it don't see this window on every Space.
        if StageManagerDetection.isActive {
            collectionBehavior.insert(.canJoinAllSpaces)
        }

        contentView = NSHostingView(rootView: PermissionsListRootView(state: state, flow: flow))
    }
}
