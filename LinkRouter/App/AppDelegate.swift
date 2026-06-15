import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        URLRequestReceiver.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        URLRequestReceiver.shared.stop()
    }
}
