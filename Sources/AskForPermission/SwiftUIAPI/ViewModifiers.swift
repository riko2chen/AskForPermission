import SwiftUI

extension View {
    /// Runs the guided permission flow when this view is tapped. The view's
    /// on-screen rectangle is the starting frame for the flight animation.
    ///
    /// Use on plain views (`Label`, `Text`) — not on a `Button`, whose own
    /// action would fire alongside the tap gesture. For button ergonomics,
    /// wire `AskForPermission.request(_:from:)` into the button's action
    /// and apply this modifier only for the rect capture.
    public func requestsPermission(
        _ kind: PermissionKind,
        onResult: @escaping (PermissionRequestResult) -> Void = { _ in }
    ) -> some View {
        modifier(RequestsPermissionModifier(kind: kind, onResult: onResult))
    }

    /// Imperative form: when `item` becomes non-nil, run the flow using
    /// this view's rectangle as the source. Resets `item` to nil when the
    /// flow completes.
    public func askForPermission(
        item: Binding<PermissionKind?>,
        onResult: @escaping (PermissionRequestResult) -> Void = { _ in }
    ) -> some View {
        modifier(AskForPermissionItemModifier(item: item, onResult: onResult))
    }
}

private struct RequestsPermissionModifier: ViewModifier {
    let kind: PermissionKind
    let onResult: (PermissionRequestResult) -> Void
    @State private var rect: CGRect = .zero
    @State private var isRunning = false

    func body(content: Content) -> some View {
        content
            .background(ScreenRectReader(rect: $rect))
            .background(HostWindowConfigurator())
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isRunning else { return }
                isRunning = true
                Task { @MainActor in
                    let result = await AskForPermission.request(
                        kind,
                        sourceRectInScreen: rect
                    )
                    isRunning = false
                    onResult(result)
                }
            }
    }
}

private struct AskForPermissionItemModifier: ViewModifier {
    @Binding var item: PermissionKind?
    let onResult: (PermissionRequestResult) -> Void
    @State private var rect: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(ScreenRectReader(rect: $rect))
            .background(HostWindowConfigurator())
            .onChange(of: item) { newValue in
                guard let kind = newValue else { return }
                Task { @MainActor in
                    let result = await AskForPermission.request(
                        kind,
                        sourceRectInScreen: rect
                    )
                    item = nil
                    onResult(result)
                }
            }
    }
}
