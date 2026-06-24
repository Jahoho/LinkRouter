import XCTest
@testable import LinkRouter

final class RuleEngineTests: XCTestCase {
    private let ruleEngine = RuleEngine()

    func testCodexRoutesToChrome() throws {
        let decision = ruleEngine.evaluate(
            request: try request(
                sourceBundleIdentifier: "com.openai.codex"
            ),
            configuration: .seed
        )

        XCTAssertEqual(decision.matchedRule?.id, "codex-to-chrome")
        XCTAssertEqual(
            decision.browserBundleIdentifier,
            "com.google.Chrome"
        )
        XCTAssertFalse(decision.usedConfiguredFallback)
    }

    func testWeChatRoutesToSafariThroughRule() throws {
        let decision = ruleEngine.evaluate(
            request: try request(
                sourceBundleIdentifier: "com.tencent.xinWeChat"
            ),
            configuration: .seed
        )

        XCTAssertEqual(decision.matchedRule?.id, "wechat-to-safari")
        XCTAssertEqual(
            decision.browserBundleIdentifier,
            "com.apple.Safari"
        )
        XCTAssertFalse(decision.usedConfiguredFallback)
    }

    func testMailRoutesToSafariThroughRule() throws {
        let decision = ruleEngine.evaluate(
            request: try request(
                sourceBundleIdentifier: "com.apple.mail"
            ),
            configuration: .seed
        )

        XCTAssertEqual(decision.matchedRule?.id, "mail-to-safari")
        XCTAssertEqual(
            decision.browserBundleIdentifier,
            "com.apple.Safari"
        )
        XCTAssertFalse(decision.usedConfiguredFallback)
    }

    func testUnknownSourceUsesSafariFallback() throws {
        let decision = ruleEngine.evaluate(
            request: try request(sourceBundleIdentifier: nil),
            configuration: .seed
        )

        XCTAssertNil(decision.matchedRule)
        XCTAssertEqual(
            decision.browserBundleIdentifier,
            "com.apple.Safari"
        )
        XCTAssertTrue(decision.usedConfiguredFallback)
    }

    func testHigherPriorityRuleWins() throws {
        let configuration = configuration(
            rules: [
                rule(id: "low", priority: 10, browser: "browser.low"),
                rule(id: "high", priority: 100, browser: "browser.high")
            ]
        )

        let decision = ruleEngine.evaluate(
            request: try request(sourceBundleIdentifier: "test.source"),
            configuration: configuration
        )

        XCTAssertEqual(decision.matchedRule?.id, "high")
        XCTAssertEqual(decision.browserBundleIdentifier, "browser.high")
    }

    func testEqualPriorityKeepsConfigurationOrder() throws {
        let configuration = configuration(
            rules: [
                rule(id: "first", priority: 50, browser: "browser.first"),
                rule(id: "second", priority: 50, browser: "browser.second")
            ]
        )

        let decision = ruleEngine.evaluate(
            request: try request(sourceBundleIdentifier: "test.source"),
            configuration: configuration
        )

        XCTAssertEqual(decision.matchedRule?.id, "first")
    }

    func testDisabledRuleDoesNotMatch() throws {
        let configuration = configuration(
            rules: [
                rule(
                    id: "disabled",
                    enabled: false,
                    priority: 100,
                    browser: "browser.disabled"
                )
            ]
        )

        let decision = ruleEngine.evaluate(
            request: try request(sourceBundleIdentifier: "test.source"),
            configuration: configuration
        )

        XCTAssertNil(decision.matchedRule)
        XCTAssertEqual(decision.browserBundleIdentifier, "browser.fallback")
    }

    func testDomainRuleMatchesHostWithoutSourceApp() throws {
        let configuration = configuration(
            rules: [
                rule(
                    id: "github",
                    priority: 100,
                    browser: "browser.github",
                    sourceAppBundleIdentifier: nil,
                    hostPattern: "*.github.com"
                )
            ]
        )

        let decision = ruleEngine.evaluate(
            request: try request(
                sourceBundleIdentifier: nil,
                urlString: "https://docs.github.com/path"
            ),
            configuration: configuration
        )

        XCTAssertEqual(decision.matchedRule?.id, "github")
        XCTAssertEqual(decision.browserBundleIdentifier, "browser.github")
    }

    func testConflictExplanationKeepsSkippedMatchingRules() throws {
        let configuration = configuration(
            rules: [
                rule(
                    id: "specific",
                    priority: 100,
                    browser: "browser.specific",
                    hostPattern: "*.example.com"
                ),
                rule(
                    id: "general",
                    priority: 50,
                    browser: "browser.general"
                )
            ]
        )

        let decision = ruleEngine.evaluate(
            request: try request(
                sourceBundleIdentifier: "test.source",
                urlString: "https://docs.example.com/path"
            ),
            configuration: configuration
        )

        XCTAssertEqual(decision.matchedRule?.id, "specific")
        XCTAssertEqual(decision.skippedRuleNames, ["general"])
    }

    func testCombinedConditionsMustAllMatch() throws {
        let combinedRule = RoutingRule(
            id: "combined",
            name: "Combined",
            enabled: true,
            priority: 100,
            sourceAppBundleIdentifier: "test.source",
            sourceAppName: "Test Source",
            hostPattern: "*.example.com",
            urlScheme: "https",
            browserBundleIdentifier: "browser.combined",
            browserName: "Combined Browser",
            action: .open,
            openInBackground: false
        )
        let configuration = configuration(rules: [combinedRule])

        let matchingDecision = ruleEngine.evaluate(
            request: try request(
                sourceBundleIdentifier: "test.source",
                urlString: "https://docs.example.com/path"
            ),
            configuration: configuration
        )
        let wrongSchemeDecision = ruleEngine.evaluate(
            request: try request(
                sourceBundleIdentifier: "test.source",
                urlString: "http://docs.example.com/path"
            ),
            configuration: configuration
        )

        XCTAssertEqual(matchingDecision.matchedRule?.id, "combined")
        XCTAssertNil(wrongSchemeDecision.matchedRule)
    }

    func testSeedConfigurationRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(RoutingConfiguration.seed)
        let decodedConfiguration = try JSONDecoder().decode(
            RoutingConfiguration.self,
            from: data
        )

        XCTAssertEqual(decodedConfiguration, .seed)
        XCTAssertEqual(decodedConfiguration.schemaVersion, 1)
    }

    private func request(
        sourceBundleIdentifier: String?,
        urlString: String = "https://example.com/path?token=secret"
    ) throws -> IncomingURLRequest {
        let source: SourceDetectionResult

        if let sourceBundleIdentifier {
            source = SourceDetectionResult(
                application: SourceApplication(
                    bundleIdentifier: sourceBundleIdentifier,
                    name: "Test Source",
                    processIdentifier: 123
                ),
                method: .appleEventSender,
                confidence: .high,
                reason: "Rule engine test"
            )
        } else {
            source = .unknown(reason: "Rule engine test")
        }

        return try IncomingURLRequest(
            urlString: urlString,
            source: source
        )
    }

    private func configuration(
        rules: [RoutingRule]
    ) -> RoutingConfiguration {
        RoutingConfiguration(
            schemaVersion: 1,
            defaultBrowserBundleIdentifier: "browser.fallback",
            defaultBrowserName: "Fallback",
            rules: rules
        )
    }

    private func rule(
        id: String,
        enabled: Bool = true,
        priority: Int,
        browser: String,
        sourceAppBundleIdentifier: String? = "test.source",
        hostPattern: String? = nil
    ) -> RoutingRule {
        RoutingRule(
            id: id,
            name: id,
            enabled: enabled,
            priority: priority,
            sourceAppBundleIdentifier: sourceAppBundleIdentifier,
            sourceAppName: "Test Source",
            hostPattern: hostPattern,
            urlScheme: nil,
            browserBundleIdentifier: browser,
            browserName: browser,
            action: .open,
            openInBackground: false
        )
    }
}
