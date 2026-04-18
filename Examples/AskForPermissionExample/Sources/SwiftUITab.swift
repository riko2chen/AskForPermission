import AskForPermission
import SwiftUI

struct SwiftUITab: View {
    @StateObject private var observer = PermissionsObserver()
    @State private var pending: PermissionKind?
    @State private var lastResult: String = "—"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SwiftUI entry points")
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                statusRow("Accessibility", kind: .accessibility, granted: observer.accessibility)
                statusRow("Screen Recording", kind: .screenRecording, granted: observer.screenRecording)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Imperative flow (.askForPermission(item:))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("Request Accessibility") { pending = .accessibility }
                    Button("Request Screen Recording") { pending = .screenRecording }
                }
            }

            Text("Last result: \(lastResult)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .askForPermission(item: $pending) { result in
            lastResult = describe(result)
        }
    }

    @ViewBuilder
    private func statusRow(_ title: String, kind: PermissionKind, granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? Color.green : Color.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if granted {
                Text("Granted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap to grant")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                    )
                    .requestsPermission(kind) { result in
                        lastResult = describe(result)
                    }
            }
        }
    }

    private func describe(_ result: PermissionRequestResult) -> String {
        switch result {
        case .alreadyAuthorized: return "alreadyAuthorized"
        case .authorized: return "authorized"
        case .cancelled: return "cancelled"
        case .timedOut: return "timedOut"
        case .unavailable(let error): return "unavailable(\(error.code.rawValue))"
        }
    }
}
