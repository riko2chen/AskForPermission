import Foundation

enum PermissionRowCatalog {
    struct Entry: Identifiable {
        let id: String
        let kind: PermissionKind
        let accentSystemImage: String

        init(kind: PermissionKind, accentSystemImage: String) {
            self.id = kind.rawValue
            self.kind = kind
            self.accentSystemImage = accentSystemImage
        }
    }

    static let entries: [Entry] = [
        Entry(kind: .accessibility, accentSystemImage: "figure.wave"),
        Entry(kind: .screenRecording, accentSystemImage: "rectangle.inset.filled.and.cursorarrow"),
    ]
}
