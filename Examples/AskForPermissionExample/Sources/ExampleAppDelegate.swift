import AppKit
import AskForPermission

@MainActor
final class ExampleAppDelegate: NSObject, NSApplicationDelegate {
    private var center: PermissionCenter?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let center = try PermissionCenter(appName: "AskForPermission Example")
            self.center = center

            let window = center.makePermissionsWindow()
            self.window = window

            NSApp.setActivationPolicy(.regular)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            NSLog("Failed to start PermissionCenter: \(error.localizedDescription)")
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
