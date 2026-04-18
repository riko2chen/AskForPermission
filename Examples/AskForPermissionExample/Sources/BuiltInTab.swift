import AskForPermission
import SwiftUI

struct BuiltInTab: View {
    var body: some View {
        VStack {
            PermissionsView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
