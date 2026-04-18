import SwiftUI

struct ScreenRectReader: NSViewRepresentable {
    @Binding var rect: CGRect

    func makeNSView(context: Context) -> RowRectProbeView.ProbeView {
        RowRectProbeView.ProbeView(onUpdate: { newRect in
            DispatchQueue.main.async { rect = newRect }
        })
    }

    func updateNSView(_ nsView: RowRectProbeView.ProbeView, context: Context) {}
}
