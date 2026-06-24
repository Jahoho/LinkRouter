import Foundation

struct RoutingResult: Equatable {
    let requestID: UUID
    let decision: RoutingDecision
    let finalBrowserBundleIdentifier: String?
    let finalBrowserName: String?
    let usedRecoveryFallback: Bool
    let notice: String?
    let errorDescription: String?

    var succeeded: Bool {
        errorDescription == nil
    }

    var statusDescription: String {
        if let errorDescription {
            return errorDescription
        }

        guard let finalBrowserName else {
            return "Routing finished without a browser result."
        }

        if usedRecoveryFallback {
            return "Opened in fallback browser \(finalBrowserName)."
        }

        if let matchedRule = decision.matchedRule {
            return "Matched \(matchedRule.name) and opened \(finalBrowserName)."
        }

        return "No rule matched; opened fallback browser \(finalBrowserName)."
    }
}

struct RoutingHistoryItem: Identifiable, Equatable {
    let id: UUID
    let routedAt: Date
    let sanitizedURLDescription: String
    let sourceApplication: SourceApplication?
    let detectionMethod: SourceDetectionMethod
    let confidence: SourceDetectionConfidence
    let matchedRuleName: String?
    let selectedBrowserName: String
    let finalBrowserName: String?
    let statusDescription: String
    let errorDescription: String?

    init(
        request: IncomingURLRequest,
        result: RoutingResult,
        routedAt: Date = Date()
    ) {
        id = UUID()
        self.routedAt = routedAt
        sanitizedURLDescription = request.sanitizedDescription
        sourceApplication = request.source.application
        detectionMethod = request.source.method
        confidence = request.source.confidence
        matchedRuleName = result.decision.matchedRule?.name
        selectedBrowserName = result.decision.browserName
        finalBrowserName = result.finalBrowserName
        statusDescription = result.statusDescription
        errorDescription = result.errorDescription
    }
}

@MainActor
final class RoutingCoordinator {
    static let shared = RoutingCoordinator()

    private struct RoutingJob {
        let request: IncomingURLRequest
        let configuration: RoutingConfiguration
        let completion: (RoutingResult) -> Void
    }

    private let ruleEngine: RuleEngine
    private let browserDiscovery: BrowserDiscovery
    private let browserLauncher: BrowserLauncher
    private var pendingJobs: [RoutingJob] = []
    private var isProcessing = false

    init(
        ruleEngine: RuleEngine = RuleEngine(),
        browserDiscovery: BrowserDiscovery? = nil,
        browserLauncher: BrowserLauncher? = nil
    ) {
        self.ruleEngine = ruleEngine
        self.browserDiscovery = browserDiscovery ?? .shared
        self.browserLauncher = browserLauncher ?? .shared
    }

    func route(
        _ request: IncomingURLRequest,
        configuration: RoutingConfiguration,
        completion: @escaping (RoutingResult) -> Void
    ) {
        pendingJobs.append(
            RoutingJob(
                request: request,
                configuration: configuration,
                completion: completion
            )
        )
        processNextJobIfNeeded()
    }

    private func processNextJobIfNeeded() {
        guard !isProcessing, !pendingJobs.isEmpty else {
            return
        }

        isProcessing = true
        let job = pendingJobs.removeFirst()
        let decision = ruleEngine.evaluate(
            request: job.request,
            configuration: job.configuration
        )
        let browsers = browserDiscovery.discoverInstalledBrowsers()

        RoutingLogger.shared.logRoutingDecision(
            request: job.request,
            decision: decision
        )

        attemptSelectedBrowser(
            for: job,
            decision: decision,
            browsers: browsers
        )
    }

    private func attemptSelectedBrowser(
        for job: RoutingJob,
        decision: RoutingDecision,
        browsers: [Browser]
    ) {
        guard
            let browser = browser(
                withBundleIdentifier: decision.browserBundleIdentifier,
                in: browsers
            )
        else {
            attemptRecoveryFallback(
                for: job,
                decision: decision,
                browsers: browsers,
                initialError:
                    "\(decision.browserName) is not installed or cannot be located."
            )
            return
        }

        browserLauncher.open(
            job.request.url,
            in: browser,
            activate: !decision.openInBackground
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success:
                self.finish(
                    job,
                    result: RoutingResult(
                        requestID: job.request.id,
                        decision: decision,
                        finalBrowserBundleIdentifier:
                            browser.bundleIdentifier,
                        finalBrowserName: browser.name,
                        usedRecoveryFallback: false,
                        notice: nil,
                        errorDescription: nil
                    )
                )
            case let .failure(error):
                self.attemptRecoveryFallback(
                    for: job,
                    decision: decision,
                    browsers: browsers,
                    initialError: error.localizedDescription
                )
            }
        }
    }

    private func attemptRecoveryFallback(
        for job: RoutingJob,
        decision: RoutingDecision,
        browsers: [Browser],
        initialError: String
    ) {
        let fallbackBundleIdentifier =
            job.configuration.defaultBrowserBundleIdentifier
        let selectedFallbackAlready =
            decision.browserBundleIdentifier.caseInsensitiveCompare(
                fallbackBundleIdentifier
            ) == .orderedSame

        guard
            !selectedFallbackAlready,
            let fallbackBrowser = browser(
                withBundleIdentifier: fallbackBundleIdentifier,
                in: browsers
            )
        else {
            finish(
                job,
                result: RoutingResult(
                    requestID: job.request.id,
                    decision: decision,
                    finalBrowserBundleIdentifier: nil,
                    finalBrowserName: nil,
                    usedRecoveryFallback: false,
                    notice: nil,
                    errorDescription: initialError
                )
            )
            return
        }

        browserLauncher.open(
            job.request.url,
            in: fallbackBrowser,
            activate: true
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success:
                self.finish(
                    job,
                    result: RoutingResult(
                        requestID: job.request.id,
                        decision: decision,
                        finalBrowserBundleIdentifier:
                            fallbackBrowser.bundleIdentifier,
                        finalBrowserName: fallbackBrowser.name,
                        usedRecoveryFallback: true,
                        notice:
                            "\(initialError) Used \(fallbackBrowser.name) instead.",
                        errorDescription: nil
                    )
                )
            case let .failure(fallbackError):
                self.finish(
                    job,
                    result: RoutingResult(
                        requestID: job.request.id,
                        decision: decision,
                        finalBrowserBundleIdentifier: nil,
                        finalBrowserName: nil,
                        usedRecoveryFallback: true,
                        notice: nil,
                        errorDescription:
                            "\(initialError) Fallback also failed: \(fallbackError.localizedDescription)"
                    )
                )
            }
        }
    }

    private func browser(
        withBundleIdentifier bundleIdentifier: String,
        in browsers: [Browser]
    ) -> Browser? {
        browsers.first {
            $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier)
                == .orderedSame
        }
    }

    private func finish(_ job: RoutingJob, result: RoutingResult) {
        RoutingLogger.shared.logRoutingResult(result)
        isProcessing = false
        job.completion(result)
        processNextJobIfNeeded()
    }
}
