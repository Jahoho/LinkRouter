import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var lastRequest: IncomingURLRequest?
    @Published private(set) var receivedRequestCount = 0
    @Published private(set) var availableBrowsers: [Browser] = []
    @Published private(set) var browserLaunchStatus: String?
    @Published private(set) var isLaunchingBrowser = false
    @Published private(set) var lastRoutingResult: RoutingResult?
    @Published private(set) var routingConfiguration: RoutingConfiguration
    @Published private(set) var configurationStatus: ConfigurationLoadStatus
    @Published private(set) var configurationEditMessage: String?
    @Published private(set) var configurationEditFailed = false

    let configurationFileURL: URL

    private let configurationStore: ConfigurationStore
    private let configurationEditor = RoutingConfigurationEditor()

    init(configurationStore: ConfigurationStore = .shared) {
        let loadResult = configurationStore.loadOrCreateSeed()

        self.configurationStore = configurationStore
        routingConfiguration = loadResult.configuration
        configurationStatus = loadResult.status
        configurationFileURL = configurationStore.configurationURL

        RoutingLogger.shared.logConfigurationStatus(loadResult.status)
    }

    var canEditConfiguration: Bool {
        !configurationStatus.isUsingInMemoryFallback
    }

    func handle(_ request: IncomingURLRequest) {
        lastRequest = request
        receivedRequestCount += 1
        RoutingLogger.shared.logReceived(request)

        RoutingCoordinator.shared.route(
            request,
            configuration: routingConfiguration
        ) { [weak self] result in
            self?.lastRoutingResult = result
        }
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

    func addRule(
        _ rule: RoutingRule
    ) -> Result<Void, ConfigurationEditingError> {
        applyConfigurationChange(action: "Added rule") {
            try configurationEditor.adding(
                rule,
                to: routingConfiguration
            )
        }
    }

    func updateRule(
        _ rule: RoutingRule
    ) -> Result<Void, ConfigurationEditingError> {
        applyConfigurationChange(action: "Updated rule") {
            try configurationEditor.updating(
                rule,
                in: routingConfiguration
            )
        }
    }

    func deleteRule(
        id: String
    ) -> Result<Void, ConfigurationEditingError> {
        applyConfigurationChange(action: "Deleted rule") {
            try configurationEditor.deleting(
                ruleID: id,
                from: routingConfiguration
            )
        }
    }

    func setRuleEnabled(
        id: String,
        enabled: Bool
    ) -> Result<Void, ConfigurationEditingError> {
        applyConfigurationChange(action: "Changed rule status") {
            try configurationEditor.settingEnabled(
                enabled,
                for: id,
                in: routingConfiguration
            )
        }
    }

    func setFallbackBrowser(
        bundleIdentifier: String
    ) -> Result<Void, ConfigurationEditingError> {
        guard
            let browser = availableBrowsers.first(where: {
                $0.bundleIdentifier == bundleIdentifier
            })
        else {
            return failure(.saveFailed("The selected browser is unavailable."))
        }

        return applyConfigurationChange(
            action: "Changed fallback browser"
        ) {
            configurationEditor.settingFallback(
                browser,
                in: routingConfiguration
            )
        }
    }

    private func applyConfigurationChange(
        action: String,
        change: () throws -> RoutingConfiguration
    ) -> Result<Void, ConfigurationEditingError> {
        guard canEditConfiguration else {
            return failure(.editingDisabled)
        }

        do {
            let updatedConfiguration = try change()
            try configurationStore.save(updatedConfiguration)

            routingConfiguration = updatedConfiguration
            configurationStatus = .saved
            configurationEditMessage = "\(action) and saved."
            configurationEditFailed = false
            RoutingLogger.shared.logConfigurationChange(action)
            return .success(())
        } catch let error as ConfigurationEditingError {
            return failure(error)
        } catch {
            return failure(.saveFailed(error.localizedDescription))
        }
    }

    private func failure(
        _ error: ConfigurationEditingError
    ) -> Result<Void, ConfigurationEditingError> {
        configurationEditMessage = error.localizedDescription
        configurationEditFailed = true
        return .failure(error)
    }
}
