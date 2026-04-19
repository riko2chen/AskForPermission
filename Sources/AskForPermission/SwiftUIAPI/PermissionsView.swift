import SwiftUI

/// SwiftUI permissions onboarding view. Mirrors the content of
/// `AskForPermission.permissionsWindowController()` so apps can embed the
/// same UI inside their own window chrome.
///
/// When `AskForPermission.isAvailable` is `false` the view renders an
/// inline diagnostic instead of the permission list.
@MainActor
public struct PermissionsView: View {
    public init() {}

    public var body: some View {
        Group {
            if let center = AskForPermission.sharedCenter() {
                PermissionsListRootView(state: center.statusState, flow: center.requestFlow)
            } else {
                unavailableState
            }
        }
        .background(HostWindowConfigurator())
    }

    private var unavailableState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions UI unavailable")
                .font(.system(size: 14, weight: .semibold))
            Text(AskForPermission.cachedFailure()?.message ?? "Host process is not a .app bundle.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(
            width: PermissionsListRootView.rootSize.width,
            height: PermissionsListRootView.rootSize.height,
            alignment: .topLeading
        )
    }
}
