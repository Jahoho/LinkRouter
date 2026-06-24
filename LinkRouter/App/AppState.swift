import Foundation
import ServiceManagement

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }

    func text(_ english: String, _ chinese: String) -> String {
        switch self {
        case .english:
            return english
        case .chinese:
            return chinese
        }
    }
}

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
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .enabled:
            return language.text("Enabled", "已启用")
        case .disabled:
            return language.text("Disabled", "已停用")
        case .requiresApproval:
            return language.text("Requires approval", "需要批准")
        case .unavailable:
            return language.text("Unavailable", "不可用")
        }
    }

    var detail: String {
        detail(language: .english)
    }

    func detail(language: AppLanguage) -> String {
        switch self {
        case .enabled:
            return language.text(
                "LinkRouter will open when you log in.",
                "LinkRouter 会在你登录时自动打开。"
            )
        case .disabled:
            return language.text(
                "LinkRouter will not open automatically.",
                "LinkRouter 不会自动启动。"
            )
        case .requiresApproval:
            return language.text(
                "Approve LinkRouter in System Settings to enable launch at login.",
                "请在系统设置中批准 LinkRouter，才能启用登录启动。"
            )
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
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .ok:
            return language.text("OK", "正常")
        case .warning:
            return language.text("Check", "需检查")
        case .error:
            return language.text("Needs attention", "需要处理")
        }
    }
}

struct SetupHealthItem: Identifiable, Equatable {
    let id: String
    let title: String
    let level: SetupHealthLevel
    let detail: String
}

enum SourceCompatibilityStatus: Equatable {
    case reliable
    case needsMoreSamples
    case unstable

    func title(language: AppLanguage) -> String {
        switch self {
        case .reliable:
            return language.text("Reliable", "较稳定")
        case .needsMoreSamples:
            return language.text("Needs more samples", "样本不足")
        case .unstable:
            return language.text("Unstable", "不稳定")
        }
    }
}

struct SourceCompatibilityReport: Identifiable, Equatable {
    let bundleIdentifier: String
    let appName: String
    let sampleCount: Int
    let highConfidenceCount: Int
    let mediumConfidenceCount: Int
    let unknownConfidenceCount: Int
    let detectionMethods: [SourceDetectionMethod]
    let latestSeenAt: Date

    var id: String {
        bundleIdentifier
    }

    var averageConfidenceScore: Double {
        guard sampleCount > 0 else {
            return 0
        }

        let total =
            Double(highConfidenceCount)
            + Double(mediumConfidenceCount) * 0.6
        return total / Double(sampleCount)
    }

    var status: SourceCompatibilityStatus {
        if sampleCount < 2 {
            return .needsMoreSamples
        }

        if averageConfidenceScore >= 0.8 {
            return .reliable
        }

        return .unstable
    }

    var confidenceSummary: String {
        "\(highConfidenceCount) high / \(mediumConfidenceCount) medium / \(unknownConfidenceCount) unknown"
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    private static let recentSourceApplicationLimit = 8
    private static let recentRoutingHistoryLimit = 20
    private static let onboardingCompletedKey =
        "LinkRouterOnboardingCompleted"
    private static let languageKey = "LinkRouterLanguage"

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
    @Published private(set) var pauseRoutingUntil: Date?
    @Published private(set) var nextLinkBrowserOverride: Browser?
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var language: AppLanguage
    @Published private(set) var routingConfiguration: RoutingConfiguration
    @Published private(set) var configurationStatus: ConfigurationLoadStatus
    @Published private(set) var configurationEditMessage: String?
    @Published private(set) var configurationEditFailed = false

    let configurationFileURL: URL

    private let configurationStore: ConfigurationStore
    private let configurationEditor = RoutingConfigurationEditor()
    private let userDefaults: UserDefaults

    init(
        configurationStore: ConfigurationStore = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        let loadResult = configurationStore.loadOrCreateSeed()

        self.configurationStore = configurationStore
        self.userDefaults = userDefaults
        hasCompletedOnboarding = userDefaults.bool(
            forKey: Self.onboardingCompletedKey
        )
        language = AppLanguage(
            rawValue: userDefaults.string(forKey: Self.languageKey) ?? ""
        ) ?? .english
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
                title: text("URL listener", "链接监听"),
                level: .ok,
                detail: text(
                    "LinkRouter is running and ready to receive URL events.",
                    "LinkRouter 正在运行，可以接收链接事件。"
                )
            ),
            SetupHealthItem(
                id: "default-browser",
                title: text("Default web browser", "默认网页浏览器"),
                level: defaultBrowserStatus.isLinkRouterDefault
                    ? .ok
                    : .warning,
                detail: localized(defaultBrowserStatus).detail
            ),
            SetupHealthItem(
                id: "configuration",
                title: text("Configuration storage", "配置存储"),
                level: configurationStatus.isUsingInMemoryFallback
                    ? .error
                    : .ok,
                detail: localized(configurationStatus).detail
            ),
            SetupHealthItem(
                id: "fallback-browser",
                title: text("Fallback browser", "兜底浏览器"),
                level: fallbackBrowserAvailable ? .ok : .error,
                detail: fallbackBrowserAvailable
                    ? text(
                        "\(routingConfiguration.defaultBrowserName) is available as the fallback browser.",
                        "\(routingConfiguration.defaultBrowserName) 可作为兜底浏览器。"
                    )
                    : text(
                        "\(routingConfiguration.defaultBrowserName) is unavailable. Choose an installed fallback browser.",
                        "\(routingConfiguration.defaultBrowserName) 当前不可用。请选择一个已安装的兜底浏览器。"
                    )
            ),
            SetupHealthItem(
                id: "source-detection",
                title: text("Source detection", "来源识别"),
                level: recentSourceApplications.isEmpty ? .warning : .ok,
                detail: recentSourceApplications.isEmpty
                    ? text(
                        "Open a link from Mail, Codex, WeChat, or another app to verify source detection.",
                        "请从 Mail、Codex、微信或其他 App 打开链接，以验证来源识别。"
                    )
                    : text(
                        "Recent source apps have been detected.",
                        "已经检测到最近的来源 App。"
                    )
            ),
            SetupHealthItem(
                id: "routing-history",
                title: text("Routing history", "路由历史"),
                level: recentRoutingHistory.isEmpty ? .warning : .ok,
                detail: recentRoutingHistory.isEmpty
                    ? text(
                        "Route a link to populate recent history diagnostics.",
                        "打开一次链接后，这里会出现最近路由诊断。"
                    )
                    : text(
                        "Recent routing diagnostics are available.",
                        "最近路由诊断可用。"
                    )
            ),
            SetupHealthItem(
                id: "launch-at-login",
                title: text("Launch at login", "登录时启动"),
                level: launchAtLoginHealthLevel,
                detail: launchAtLoginStatus.detail(language: language)
            )
        ]
    }

    var setupHealthSummary: String {
        let items = setupHealthItems
        let attentionCount = items.filter { item in
            item.level != .ok
        }.count

        if attentionCount == 0 {
            return text("All checks passed", "所有检查已通过")
        }

        return text(
            "\(attentionCount) checks need review",
            "\(attentionCount) 项需要检查"
        )
    }

    var sourceCompatibilityReports: [SourceCompatibilityReport] {
        let groupedHistory = Dictionary(grouping: recentRoutingHistory) {
            item in
            item.sourceApplication?.bundleIdentifier
        }

        return groupedHistory.compactMap { bundleIdentifier, items in
            guard let bundleIdentifier else {
                return nil
            }

            let namedItems = items.compactMap(\.sourceApplication)
            guard let latestItem = items.max(by: {
                $0.routedAt < $1.routedAt
            }) else {
                return nil
            }

            let appName =
                latestItem.sourceApplication?.name
                ?? namedItems.first?.name
                ?? bundleIdentifier
            let methods = orderedDetectionMethods(from: items)

            return SourceCompatibilityReport(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                sampleCount: items.count,
                highConfidenceCount: items.filter {
                    $0.confidence == .high
                }.count,
                mediumConfidenceCount: items.filter {
                    $0.confidence == .medium
                }.count,
                unknownConfidenceCount: items.filter {
                    $0.confidence == .unknown
                }.count,
                detectionMethods: methods,
                latestSeenAt: latestItem.routedAt
            )
        }
        .sorted { first, second in
            if first.status != second.status {
                return sourceCompatibilityRank(first.status)
                    < sourceCompatibilityRank(second.status)
            }

            if first.sampleCount != second.sampleCount {
                return first.sampleCount > second.sampleCount
            }

            return first.latestSeenAt > second.latestSeenAt
        }
    }

    var unknownSourceHistoryCount: Int {
        recentRoutingHistory.filter {
            $0.sourceApplication == nil
        }.count
    }

    var isRoutingPaused: Bool {
        guard let pauseRoutingUntil else {
            return false
        }

        return pauseRoutingUntil > Date()
    }

    var routingControlSummary: String {
        if let nextLinkBrowserOverride {
            return text(
                "Next link will open in \(nextLinkBrowserOverride.name).",
                "下一次链接会用 \(nextLinkBrowserOverride.name) 打开。"
            )
        }

        if isRoutingPaused {
            return text(
                "Routing is paused; links use the fallback browser.",
                "路由已暂停；链接会使用兜底浏览器。"
            )
        }

        return text("Routing rules are active.", "路由规则已启用。")
    }

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        userDefaults.set(language.rawValue, forKey: Self.languageKey)
    }

    func text(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }

    func localized(
        _ status: DefaultBrowserStatus
    ) -> (title: String, detail: String) {
        let title: String

        if status.isLinkRouterDefault {
            title = text("LinkRouter is default", "LinkRouter 是默认浏览器")
        } else if let currentBrowserName = status.currentBrowserName {
            title = text(
                "\(currentBrowserName) is default",
                "\(currentBrowserName) 是默认浏览器"
            )
        } else {
            title = text("Unable to determine", "无法确定")
        }

        let detail: String
        if status.isLinkRouterDefault {
            detail = text(
                "New web links should be delivered to LinkRouter first.",
                "新的网页链接会先交给 LinkRouter 处理。"
            )
        } else if let currentBrowserName = status.currentBrowserName {
            detail = text(
                "New web links currently go directly to \(currentBrowserName).",
                "新的网页链接目前会直接交给 \(currentBrowserName)。"
            )
        } else {
            detail = text(
                status.detail,
                "macOS 没有返回默认 HTTPS 处理程序。"
            )
        }

        return (title, detail)
    }

    func localized(
        _ status: ConfigurationLoadStatus
    ) -> (title: String, detail: String) {
        switch status {
        case .loaded:
            return (
                text("Loaded from disk", "已从磁盘加载"),
                text(
                    "The saved configuration passed validation.",
                    "已保存配置通过校验。"
                )
            )
        case .createdSeed:
            return (
                text("Created default configuration", "已创建默认配置"),
                text(
                    "A new schema version \(RoutingConfiguration.currentSchemaVersion) configuration was created.",
                    "已创建 schema version \(RoutingConfiguration.currentSchemaVersion) 的新配置。"
                )
            )
        case .saved:
            return (
                text("Saved to disk", "已保存到磁盘"),
                text(
                    "The current rules and fallback browser were saved.",
                    "当前规则和兜底浏览器已保存。"
                )
            )
        case let .usingInMemoryFallback(reason):
            return (
                text("Using in-memory fallback", "正在使用内存兜底配置"),
                reason
            )
        }
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

        let effectiveConfiguration = routingConfiguration(for: request)

        RoutingCoordinator.shared.route(
            request,
            configuration: effectiveConfiguration
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
                ? text(
                    "Launch at login was enabled.",
                    "已启用登录时启动。"
                )
                : text(
                    "Launch at login was disabled.",
                    "已关闭登录时启动。"
                )
        } catch {
            launchAtLoginStatus = .current()
            launchAtLoginMessage =
                text(
                    "Launch at login could not be changed: \(error.localizedDescription)",
                    "无法修改登录启动状态：\(error.localizedDescription)"
                )
        }
    }

    func pauseRoutingForTenMinutes() {
        pauseRoutingUntil = Date().addingTimeInterval(10 * 60)
        nextLinkBrowserOverride = nil
    }

    func resumeRouting() {
        pauseRoutingUntil = nil
    }

    func openNextLink(in browser: Browser) {
        nextLinkBrowserOverride = browser
        pauseRoutingUntil = nil
    }

    func clearNextLinkOverride() {
        nextLinkBrowserOverride = nil
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: Self.onboardingCompletedKey)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        userDefaults.set(false, forKey: Self.onboardingCompletedKey)
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

    func exportConfiguration(
        to url: URL
    ) -> Result<Void, ConfigurationEditingError> {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(routingConfiguration)
            try data.write(to: url, options: .atomic)
            configurationEditMessage = "Exported configuration."
            configurationEditFailed = false
            return .success(())
        } catch {
            return failure(.saveFailed(error.localizedDescription))
        }
    }

    func importConfiguration(
        from url: URL
    ) -> Result<Void, ConfigurationEditingError> {
        applyConfigurationChange(action: "Imported configuration") {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                RoutingConfiguration.self,
                from: data
            )
        }
    }

    func resetConfiguration() -> Result<Void, ConfigurationEditingError> {
        applyConfigurationChange(action: "Reset configuration") {
            RoutingConfiguration.seed
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

    private func orderedDetectionMethods(
        from items: [RoutingHistoryItem]
    ) -> [SourceDetectionMethod] {
        var methods: [SourceDetectionMethod] = []

        for item in items.sorted(by: { $0.routedAt > $1.routedAt }) {
            if !methods.contains(item.detectionMethod) {
                methods.append(item.detectionMethod)
            }
        }

        return methods
    }

    private func sourceCompatibilityRank(
        _ status: SourceCompatibilityStatus
    ) -> Int {
        switch status {
        case .reliable:
            return 0
        case .needsMoreSamples:
            return 1
        case .unstable:
            return 2
        }
    }

    private func routingConfiguration(
        for request: IncomingURLRequest
    ) -> RoutingConfiguration {
        if let nextLinkBrowserOverride {
            self.nextLinkBrowserOverride = nil
            return fallbackOnlyConfiguration(
                browser: nextLinkBrowserOverride
            )
        }

        if let pauseRoutingUntil,
           pauseRoutingUntil <= request.receivedAt {
            self.pauseRoutingUntil = nil
        }

        if isRoutingPaused {
            return fallbackOnlyConfiguration(
                bundleIdentifier:
                    routingConfiguration.defaultBrowserBundleIdentifier,
                name: routingConfiguration.defaultBrowserName
            )
        }

        return routingConfiguration
    }

    private func fallbackOnlyConfiguration(
        browser: Browser
    ) -> RoutingConfiguration {
        fallbackOnlyConfiguration(
            bundleIdentifier: browser.bundleIdentifier,
            name: browser.name
        )
    }

    private func fallbackOnlyConfiguration(
        bundleIdentifier: String,
        name: String
    ) -> RoutingConfiguration {
        RoutingConfiguration(
            schemaVersion: routingConfiguration.schemaVersion,
            defaultBrowserBundleIdentifier: bundleIdentifier,
            defaultBrowserName: name,
            rules: []
        )
    }
}
