import AskForPermission
import SwiftUI

struct RootTabsView: View {
    var body: some View {
        TabView {
            BuiltInTab()
                .tabItem { Label("Built-in", systemImage: "sparkles") }
            SwiftUITab()
                .tabItem { Label("SwiftUI", systemImage: "swift") }
            AppKitTab()
                .tabItem { Label("AppKit", systemImage: "macwindow") }
        }
        .padding(12)
        .frame(width: 640, height: 440)
    }
}
