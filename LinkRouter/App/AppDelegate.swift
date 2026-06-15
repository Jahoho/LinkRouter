import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppSourceDetector.shared.start()
        URLRequestReceiver.shared.start()
        AppState.shared.refreshBrowsers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        URLRequestReceiver.shared.stop()
        AppSourceDetector.shared.stop()
    }
}
