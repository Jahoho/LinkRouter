import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable(String)

    var isEnabled: Bool {
        if case .enabled = self {
            return true
        }

        return false
    }

    var title: String {
        switch self {
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        case .requiresApproval:
            return "Requires approval"
        case .unavailable:
            return "Unavailable"
        }
    }

    var detail: String {
        switch self {
        case .enabled:
            return "LinkRouter will open when you log in."
        case .disabled:
            return "LinkRouter will not open automatically."
        case .requiresApproval:
            return "Approve LinkRouter in System Settings to enable launch at login."
        case let .unavailable(message):
            return message
        }
    }

    static func current() -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable("macOS could not locate this app as a login item.")
        @unknown default:
            return .unavailable("macOS returned an unknown login item status.")
        }
    }
}

enum SetupHealthLevel: Equatable {
    case ok
    case warning
    case error

    var title: String {
        switch self {
        case .ok:
            return "OK"
        case .warning:
            return "Check"
        case .error:
            return "Needs attention"
        }
    }
}

struct SetupHealthItem: Identifiable, Equatable {
    let id: String
    let title: String
    let level: SetupHealthLevel
    let detail: String
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    private static let recentSourceApplicationLimit = 8
    private static let recentRoutingHistoryLimit = 20

    @Published private(set) var lastRequest: IncomingURLRequest?
    @Published private(set) var receivedRequestCount = 0
    @Published private(set) var recentSourceApplications:
        [RecentSourceApplication] = []
    @Published private(set) var recentRoutingHistory:
        [RoutingHistoryItem] = []
    @Published private(set) var availableBrowsers: [Browser] = []
    @Published private(set) var defaultBrowserStatus: DefaultBrowserStatus =
        .unknown
    @Published private(set) var launchAtLoginStatus:
        LaunchAtLoginStatus = .current()
    @Published private(set) var launchAtLoginMessage: String?
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

    var setupHealthItems: [SetupHealthItem] {
        let fallbackBrowserAvailable = availableBrowsers.contains {
            $0.bundleIdentifier.caseInsensitiveCompare(
                routingConfiguration.defaultBrowserBundleIdentifier
            ) == .orderedSame
        }

        return [
            SetupHealthItem(
                id: "listener",
                title: "URL listener",
                level: .ok,
                detail: "LinkRouter is running and ready to receive URL events."
            ),
            SetupHealthItem(
                id: "default-browser",
                title: "Default web browser",
                level: defaultBrowserStatus.isLinkRouterDefault
                    ? .ok
                    : .warning,
                detail: defaultBrowserStatus.detail
            ),
            SetupHealthItem(
                id: "configuration",
                title: "Configuration storage",
                level: configurationStatus.isUsingInMemoryFallback
                    ? .error
                    : .ok,
                detail: configurationStatus.detail
            ),
            SetupHealthItem(
                id: "fallback-browser",
                title: "Fallback browser",
                level: fallbackBrowserAvailable ? .ok : .error,
                detail: fallbackBrowserAvailable
                    ? "\(routingConfiguration.defaultBrowserName) is available as the fallback browser."
                    : "\(routingConfiguration.defaultBrowserName) is unavailable. Choose an installed fallback browser."
            ),
            SetupHealthItem(
                id: "source-detection",
                title: "Source detection",
                level: recentSourceApplications.isEmpty ? .warning : .ok,
                detail: recentSourceApplications.isEmpty
                    ? "Open a link from Mail, Codex, WeChat, or another app to verify source detection."
                    : "Recent source apps have been detected."
            ),
            SetupHealthItem(
                id: "routing-history",
                title: "Routing history",
                level: recentRoutingHistory.isEmpty ? .warning : .ok,
                detail: recentRoutingHistory.isEmpty
                    ? "Route a link to populate recent history diagnostics."
                    : "Recent routing diagnostics are available."
            ),
            SetupHealthItem(
                id: "launch-at-login",
                title: "Launch at login",
                level: launchAtLoginHealthLevel,
                detail: launchAtLoginStatus.detail
            )
        ]
    }

    var setupHealthSummary: String {
        let items = setupHealthItems
        let attentionCount = items.filter { item in
            item.level != .ok
        }.count

        if attentionCount == 0 {
            return "All checks passed"
        }

        return "\(attentionCount) checks need review"
    }

    private var launchAtLoginHealthLevel: SetupHealthLevel {
        switch launchAtLoginStatus {
        case .enabled:
            return .ok
        case .disabled, .requiresApproval:
            return .warning
        case .unavailable:
            return .error
        }
    }

    func handle(_ request: IncomingURLRequest) {
        lastRequest = request
        receivedRequestCount += 1
        rememberSourceApplication(
            request.source,
            at: request.receivedAt
        )
        RoutingLogger.shared.logReceived(request)

        RoutingCoordinator.shared.route(
            request,
            configuration: routingConfiguration
        ) { [weak self] result in
            guard let self else {
                return
            }

            self.lastRoutingResult = result
            self.recordRoutingHistory(
                request: request,
                result: result
            )
        }
    }

    func refreshBrowsers() {
        availableBrowsers = BrowserDiscovery.shared
            .discoverInstalledBrowsers()
        refreshDefaultBrowserStatus()
        RoutingLogger.shared.logBrowserDiscovery(availableBrowsers)
    }

    func refreshDefaultBrowserStatus() {
        defaultBrowserStatus = BrowserDiscovery.shared
            .currentDefaultBrowserStatus()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = .current()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            launchAtLoginStatus = .current()
            launchAtLoginMessage = enabled
                ? "Launch at login was enabled."
                : "Launch at login was disabled."
        } catch {
            launchAtLoginStatus = .current()
            launchAtLoginMessage =
                "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }

    func recordRoutingHistory(
        request: IncomingURLRequest,
        result: RoutingResult
    ) {
        recentRoutingHistory.insert(
            RoutingHistoryItem(
                request: request,
                result: result
            ),
            at: 0
        )

        if recentRoutingHistory.count > Self.recentRoutingHistoryLimit {
            recentRoutingHistory = Array(
                recentRoutingHistory
                    .prefix(Self.recentRoutingHistoryLimit)
            )
        }
    }

    func rememberSourceApplication(
        _ source: SourceDetectionResult,
        at date: Date
    ) {
        guard
            let application = source.application,
            AppSourceDetector.isCredibleSource(application)
        else {
            return
        }

        let recentSourceApplication = RecentSourceApplication(
            application: application,
            lastSeenAt: date,
            method: source.method,
            confidence: source.confidence
        )

        recentSourceApplications.removeAll { existing in
            existing.application.bundleIdentifier
                .caseInsensitiveCompare(application.bundleIdentifier)
                == .orderedSame
        }
        recentSourceApplications.insert(recentSourceApplication, at: 0)

        if recentSourceApplications.count
            > Self.recentSourceApplicationLimit
        {
            recentSourceApplications = Array(
                recentSourceApplications
                    .prefix(Self.recentSourceApplicationLimit)
            )
        }
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
