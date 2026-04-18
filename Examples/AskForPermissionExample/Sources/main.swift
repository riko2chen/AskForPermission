import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = ExampleAppDelegate()
    app.delegate = delegate
    app.run()
}
