import AppKit
import AskForPermission
import SwiftUI

struct AppKitTab: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { AppKitTabView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
final class AppKitTabView: NSView {
    private let axButton = NSButton(title: "Request Accessibility", target: nil, action: nil)
    private let scButton = NSButton(title: "Request Screen Recording", target: nil, action: nil)
    private let openWindowButton = NSButton(title: "Open built-in permissions window", target: nil, action: nil)
    private let resultLabel = NSTextField(labelWithString: "Last result: —")
    private var controller: NSWindowController?

    init() {
        super.init(frame: .zero)

        axButton.bezelStyle = .rounded
        scButton.bezelStyle = .rounded
        openWindowButton.bezelStyle = .rounded
        axButton.target = self
        axButton.action = #selector(requestAX)
        scButton.target = self
        scButton.action = #selector(requestSC)
        openWindowButton.target = self
        openWindowButton.action = #selector(openPermissionsWindow)

        resultLabel.textColor = .secondaryLabelColor
        resultLabel.font = .systemFont(ofSize: 11)

        let heading = NSTextField(labelWithString: "AppKit entry points")
        heading.font = .systemFont(ofSize: 18, weight: .semibold)

        let subhead = NSTextField(labelWithString: "AskForPermission.request(_:from: NSView) auto-captures the button rect.")
        subhead.font = .systemFont(ofSize: 11)
        subhead.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            heading,
            subhead,
            axButton,
            scButton,
            NSBox.horizontalDivider(),
            openWindowButton,
            resultLabel,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func requestAX() { request(.accessibility, from: axButton) }
    @objc private func requestSC() { request(.screenRecording, from: scButton) }

    @objc private func openPermissionsWindow() {
        guard let controller = AskForPermission.permissionsWindowController() else {
            resultLabel.stringValue = "Last result: unavailable (not a .app bundle)"
            return
        }
        self.controller = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func request(_ kind: PermissionKind, from view: NSView) {
        Task { @MainActor in
            let result = await AskForPermission.request(kind, from: view)
            self.resultLabel.stringValue = "Last result: \(Self.describe(result))"
        }
    }

    private static func describe(_ result: PermissionRequestResult) -> String {
        switch result {
        case .alreadyAuthorized: return "alreadyAuthorized"
        case .authorized: return "authorized"
        case .cancelled: return "cancelled"
        case .timedOut: return "timedOut"
        case .unavailable(let error): return "unavailable(\(error.code.rawValue))"
        }
    }
}

private extension NSBox {
    static func horizontalDivider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
