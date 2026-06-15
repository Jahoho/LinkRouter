import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var lastRequest: IncomingURLRequest?
    @Published private(set) var receivedRequestCount = 0
    @Published private(set) var availableBrowsers: [Browser] = []
    @Published private(set) var browserLaunchStatus: String?
    @Published private(set) var isLaunchingBrowser = false

    private init() {}

    func record(_ request: IncomingURLRequest) {
        lastRequest = request
        receivedRequestCount += 1
        RoutingLogger.shared.logReceived(request)
    }

    func refreshBrowsers() {
        availableBrowsers = BrowserDiscovery.shared
            .discoverInstalledBrowsers()
        RoutingLogger.shared.logBrowserDiscovery(availableBrowsers)
    }

    func openTestPage(in browser: Browser) {
        guard
            !isLaunchingBrowser,
            let testURL = URL(string: "https://example.com")
        else {
            return
        }

        isLaunchingBrowser = true
        browserLaunchStatus = "Opening \(browser.name)..."

        BrowserLauncher.shared.open(testURL, in: browser) {
            [weak self] result in
            guard let self else {
                return
            }

            self.isLaunchingBrowser = false

            switch result {
            case .success:
                self.browserLaunchStatus = "Opened test page in \(browser.name)."
                RoutingLogger.shared.logBrowserLaunchSucceeded(
                    browser: browser,
                    url: testURL
                )
            case let .failure(error):
                self.browserLaunchStatus = error.localizedDescription
                RoutingLogger.shared.logBrowserLaunchFailed(
                    browser: browser,
                    error: error
                )
            }
        }
    }
}
