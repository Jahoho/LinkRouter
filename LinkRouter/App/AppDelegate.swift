import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppSourceDetector.shared.start()
        URLRequestReceiver.shared.start()
        AppState.shared.refreshBrowsers()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppState.shared.shouldShowOnboarding else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(
            Selector(("showSettingsWindow:")),
            to: nil,
            from: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        URLRequestReceiver.shared.stop()
        AppSourceDetector.shared.stop()
    }
}
