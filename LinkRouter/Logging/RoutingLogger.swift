import OSLog

final class RoutingLogger {
    static let shared = RoutingLogger()

    private let logger = Logger(
        subsystem: "com.james.LinkRouter",
        category: "URLHandling"
    )

    private init() {}

    func logListenerStarted() {
        logger.notice("URL listener started")
    }

    func logReceived(_ request: IncomingURLRequest) {
        let sourceName = request.source.application?.name ?? "Unknown"
        let bundleIdentifier = request.source.application?.bundleIdentifier ?? "Unknown"

        logger.notice(
            """
            Received URL: \(request.sanitizedDescription, privacy: .public); \
            source: \(sourceName, privacy: .public); \
            bundle: \(bundleIdentifier, privacy: .public); \
            method: \(request.source.method.rawValue, privacy: .public); \
            confidence: \(request.source.confidence.rawValue, privacy: .public); \
            reason: \(request.source.reason, privacy: .public)
            """
        )
    }

    func logRejected(_ error: IncomingURLRequestError) {
        logger.error(
            "Rejected incoming URL: \(error.localizedDescription, privacy: .public)"
        )
    }

    func logUnexpectedError(_ error: Error) {
        logger.fault(
            "Unexpected URL handling error: \(error.localizedDescription, privacy: .private)"
        )
    }

    func logBrowserDiscovery(_ browsers: [Browser]) {
        let browserIdentifiers = browsers
            .map(\.bundleIdentifier)
            .joined(separator: ", ")

        logger.notice(
            "Discovered browser handlers: \(browserIdentifiers, privacy: .public)"
        )
    }

    func logBrowserLaunchSucceeded(browser: Browser, url: URL) {
        logger.notice(
            "Opened \(url.host ?? "unknown host", privacy: .public) in \(browser.bundleIdentifier, privacy: .public)"
        )
    }

    func logBrowserLaunchFailed(
        browser: Browser,
        error: BrowserLaunchError
    ) {
        logger.error(
            "Failed to open browser \(browser.bundleIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
    }

    func logRoutingDecision(
        request: IncomingURLRequest,
        decision: RoutingDecision
    ) {
        let ruleIdentifier = decision.matchedRule?.id ?? "fallback"

        logger.notice(
            """
            Routing decision for \(request.sanitizedDescription, privacy: .public); \
            rule: \(ruleIdentifier, privacy: .public); \
            selected browser: \(decision.browserBundleIdentifier, privacy: .public); \
            reason: \(decision.reason, privacy: .public)
            """
        )
    }

    func logRoutingResult(_ result: RoutingResult) {
        if result.succeeded {
            logger.notice(
                """
                Routing completed; \
                final browser: \(result.finalBrowserBundleIdentifier ?? "Unknown", privacy: .public); \
                recovery fallback: \(result.usedRecoveryFallback, privacy: .public); \
                notice: \(result.notice ?? "None", privacy: .public)
                """
            )
        } else {
            logger.error(
                "Routing failed: \(result.errorDescription ?? "Unknown error", privacy: .public)"
            )
        }
    }

    func logConfigurationStatus(_ status: ConfigurationLoadStatus) {
        if status.isUsingInMemoryFallback {
            logger.error(
                "Configuration fallback active: \(status.detail, privacy: .public)"
            )
        } else {
            logger.notice(
                "Configuration status: \(status.title, privacy: .public)"
            )
        }
    }

    func logConfigurationChange(_ action: String) {
        logger.notice(
            "Configuration changed: \(action, privacy: .public)"
        )
    }
}
