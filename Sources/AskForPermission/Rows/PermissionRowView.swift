import AppKit
import SwiftUI

struct PermissionRowView: View {
    let entry: PermissionRowCatalog.Entry
    let granted: Bool
    let active: Bool
    var disabled: Bool = false
    let onRequest: (RowRectProvider) -> Void

    @State private var rectProvider = RowRectProvider()

    static let rowHeight: CGFloat = 64

    var body: some View {
        ZStack {
            if active {
                activePlaceholder
                    .transition(.opacity)
            } else {
                normalRow
                    .transition(.opacity)
            }
        }
        .frame(height: Self.rowHeight)
        .background(RowRectProbeView(provider: rectProvider))
        .animation(.easeInOut(duration: 0.18), value: active)
        .animation(.interpolatingSpring(mass: 1, stiffness: 200, damping: 14, initialVelocity: 6),
                   value: granted)
    }

    private var activePlaceholder: some View {
        Text("COMPLETE IN SYSTEM SETTINGS")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.secondary.opacity(0.9))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        Color.secondary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.3, dash: [6, 4])
                    )
            )
    }

    private var normalRow: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: entry.accentSystemImage)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.kind.displayName).font(.system(size: 13, weight: .semibold))
                Text(entry.kind.shortDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            trailingControl
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var trailingControl: some View {
        if granted {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.green)
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.6).combined(with: .opacity),
                removal: .opacity
            ))
        } else {
            Button {
                onRequest(rectProvider)
            } label: {
                Text("COMPLETE IN SYSTEM SETTINGS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .padding(.horizontal, 12).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .disabled(disabled)
        }
    }
}
