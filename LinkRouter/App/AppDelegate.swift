import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppSourceDetector.shared.start()
        URLRequestReceiver.shared.start()
        AppState.shared.refreshBrowsers()
        AppState.shared.refreshFileDefaultApps()
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

    func application(
        _ sender: NSApplication,
        openFiles filenames: [String]
    ) {
        let fileURLs = filenames.map {
            URL(fileURLWithPath: $0)
        }

        guard
            !fileURLs.isEmpty,
            fileURLs.allSatisfy(
                BrowserLauncher.isSupportedLocalDocumentURL
            )
        else {
            AppState.shared.openLocalDocuments(fileURLs)
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        AppState.shared.openLocalDocuments(fileURLs)
        sender.reply(toOpenOrPrint: .success)
    }

    func application(
        _ application: NSApplication,
        open urls: [URL]
    ) {
        AppState.shared.openLocalDocuments(urls)
    }
}
