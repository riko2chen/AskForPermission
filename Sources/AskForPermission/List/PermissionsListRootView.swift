import SwiftUI

struct PermissionsListRootView: View {
    @ObservedObject var state: PermissionStatusModel
    let flow: PermissionRequestFlowController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
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
            Spacer()
        }
        .padding(28)
        .frame(width: 520, height: 360, alignment: .topLeading)
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
