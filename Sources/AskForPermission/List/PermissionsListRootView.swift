import SwiftUI

struct PermissionsListRootView: View {
    static let rootSize = CGSize(width: 520, height: 680)

    @ObservedObject var state: PermissionStatusModel
    let flow: PermissionRequestFlowController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            // The header stays pinned. Only the row list scrolls when the
            // host container is shorter than `rootSize.height` (e.g. embedded
            // in a tab smaller than the standalone window).
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(PermissionRowCatalog.entries) { entry in
                        PermissionRowView(
                            entry: entry,
                            granted: state.isGranted(entry.kind),
                            active: state.activePermissionRequest == entry.kind,
                            disabled: state.inProgressPermission != nil
                                && state.activePermissionRequest != entry.kind,
                            onRequest: { provider in
                                // Snapshot the row AS IT IS NOW (normal state),
                                // before the dashed-placeholder flip. The flip
                                // itself is deferred into the flow controller so
                                // the row stays as a real card until System
                                // Settings is on screen — otherwise there's a
                                // dead period where the row is already a dashed
                                // placeholder but Settings hasn't opened yet.
                                let sourceSnapshot = captureInProcessScreenRegion(provider.rect)
                                state.inProgressPermission = entry.kind
                                Task { @MainActor in
                                    _ = try? await flow.run(
                                        kind: entry.kind,
                                        sourceRectProvider: { provider.rect },
                                        sourceSnapshot: sourceSnapshot,
                                        state: state
                                    )
                                    state.activePermissionRequest = nil
                                    state.inProgressPermission = nil
                                }
                            }
                        )
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
        .padding(28)
        .frame(width: Self.rootSize.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Permissions")
                .font(.system(size: 20, weight: .semibold))
            Text("This app needs these permissions to work on your Mac.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("These permissions are only used while you use this app.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}
