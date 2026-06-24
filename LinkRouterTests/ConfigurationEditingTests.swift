import XCTest
@testable import LinkRouter

final class ConfigurationEditingTests: XCTestCase {
    private let editor = RoutingConfigurationEditor()
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LinkRouterConfigurationEditingTests-\(UUID().uuidString)",
                isDirectory: true
            )
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(
            atPath: temporaryDirectoryURL.path
        ) {
            try FileManager.default.removeItem(
                at: temporaryDirectoryURL
            )
        }

        temporaryDirectoryURL = nil
    }

    func testDraftBuildsTrimmedRuleForInstalledBrowser() throws {
        var draft = RoutingRuleDraft(
            id: "test-rule",
            name: "  Test Rule  ",
            sourceAppBundleIdentifier: " com.example.Source ",
            sourceAppName: " Source ",
            browserBundleIdentifier: "com.apple.Safari"
        )
        draft.priority = 75

        let rule = try draft.makeRule(
            availableBrowsers: [try safari()]
        )

        XCTAssertEqual(rule.name, "Test Rule")
        XCTAssertEqual(
            rule.sourceAppBundleIdentifier,
            "com.example.Source"
        )
        XCTAssertEqual(rule.sourceAppName, "Source")
        XCTAssertEqual(rule.browserName, "Safari")
        XCTAssertEqual(rule.priority, 75)
    }

    func testDraftPrefillsSourceApplicationRule() throws {
        let safari = try safari()
        let sourceApplication = SourceApplication(
            bundleIdentifier: "com.apple.mail",
            name: "Mail",
            processIdentifier: 123
        )

        let draft = RoutingRuleDraft(
            sourceApplication: sourceApplication,
            browser: safari
        )
        let rule = try draft.makeRule(availableBrowsers: [safari])

        XCTAssertEqual(rule.name, "Mail to Safari")
        XCTAssertEqual(rule.priority, 50)
        XCTAssertEqual(
            rule.sourceAppBundleIdentifier,
            "com.apple.mail"
        )
        XCTAssertEqual(rule.sourceAppName, "Mail")
        XCTAssertEqual(
            rule.browserBundleIdentifier,
            "com.apple.Safari"
        )
    }

    func testDraftRejectsInvalidSourceBundleIdentifier() throws {
        let draft = RoutingRuleDraft(
            name: "Invalid",
            sourceAppBundleIdentifier: "not a bundle id",
            browserBundleIdentifier: "com.apple.Safari"
        )

        XCTAssertThrowsError(
            try draft.makeRule(availableBrowsers: [try safari()])
        ) { error in
            XCTAssertEqual(
                error as? RoutingRuleValidationError,
                .invalidSourceBundleIdentifier
            )
        }
    }

    func testEditingPreservesHiddenFutureConditions() throws {
        let existingRule = RoutingRule(
            id: "future-rule",
            name: "Future Rule",
            enabled: true,
            priority: 100,
            sourceAppBundleIdentifier: "com.example.Source",
            sourceAppName: "Source",
            hostPattern: "*.example.com",
            urlScheme: "https",
            browserBundleIdentifier: "com.apple.Safari",
            browserName: "Safari",
            action: .open,
            openInBackground: false
        )
        var draft = RoutingRuleDraft(rule: existingRule)
        draft.name = "Renamed Rule"

        let updatedRule = try draft.makeRule(
            availableBrowsers: [try safari()]
        )

        XCTAssertEqual(updatedRule.hostPattern, "*.example.com")
        XCTAssertEqual(updatedRule.urlScheme, "https")
    }

    func testAddsUpdatesAndDeletesRule() throws {
        let newRule = try makeRule(id: "new-rule")
        let added = try editor.adding(newRule, to: .seed)

        XCTAssertEqual(added.rules.last, newRule)

        let updatedRule = try makeRule(
            id: "new-rule",
            name: "Updated Rule"
        )
        let updated = try editor.updating(updatedRule, in: added)

        XCTAssertEqual(updated.rules.last?.name, "Updated Rule")

        let deleted = try editor.deleting(
            ruleID: "new-rule",
            from: updated
        )

        XCTAssertFalse(deleted.rules.contains { $0.id == "new-rule" })
    }

    func testRejectsDuplicateRuleIdentifier() throws {
        let duplicateRule = RoutingConfiguration.seed.rules[0]

        XCTAssertThrowsError(
            try editor.adding(duplicateRule, to: .seed)
        ) { error in
            XCTAssertEqual(
                error as? ConfigurationEditingError,
                .duplicateRuleIdentifier
            )
        }
    }

    func testChangesRuleEnabledState() throws {
        let rule = RoutingConfiguration.seed.rules[0]

        let updated = try editor.settingEnabled(
            false,
            for: rule.id,
            in: .seed
        )

        XCTAssertEqual(
            updated.rules.first(where: { $0.id == rule.id })?.enabled,
            false
        )
    }

    func testChangesFallbackBrowser() throws {
        let chrome = try browser(
            at: "/Applications/Google Chrome.app"
        )

        let updated = editor.settingFallback(chrome, in: .seed)

        XCTAssertEqual(
            updated.defaultBrowserBundleIdentifier,
            "com.google.Chrome"
        )
        XCTAssertEqual(updated.defaultBrowserName, "Google Chrome")
    }

    @MainActor
    func testAppStateTracksRecentSourceApplications() throws {
        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            )
        )
        let firstDate = try XCTUnwrap(
            DateComponents(
                calendar: .current,
                year: 2026,
                month: 6,
                day: 16,
                hour: 10
            ).date
        )
        let secondDate = try XCTUnwrap(
            DateComponents(
                calendar: .current,
                year: 2026,
                month: 6,
                day: 16,
                hour: 11
            ).date
        )

        appState.rememberSourceApplication(
            sourceResult(
                bundleIdentifier: "com.apple.mail",
                name: "Mail"
            ),
            at: firstDate
        )
        appState.rememberSourceApplication(
            sourceResult(
                bundleIdentifier: "md.obsidian",
                name: "Obsidian"
            ),
            at: secondDate
        )

        XCTAssertEqual(appState.recentSourceApplications.count, 2)
        XCTAssertEqual(
            appState.recentSourceApplications[0]
                .application.bundleIdentifier,
            "md.obsidian"
        )
        XCTAssertEqual(
            appState.recentSourceApplications[1]
                .application.bundleIdentifier,
            "com.apple.mail"
        )

        appState.rememberSourceApplication(
            sourceResult(
                bundleIdentifier: "com.apple.mail",
                name: "Mail"
            ),
            at: secondDate
        )

        XCTAssertEqual(appState.recentSourceApplications.count, 2)
        XCTAssertEqual(
            appState.recentSourceApplications[0]
                .application.bundleIdentifier,
            "com.apple.mail"
        )
        XCTAssertEqual(
            appState.recentSourceApplications[0].lastSeenAt,
            secondDate
        )
    }

    @MainActor
    func testAppStateIgnoresUnknownAndNonCredibleRecentSources() throws {
        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            )
        )

        appState.rememberSourceApplication(
            .unknown(reason: "No source"),
            at: Date()
        )
        appState.rememberSourceApplication(
            sourceResult(
                bundleIdentifier: "com.james.LinkRouter",
                name: "LinkRouter"
            ),
            at: Date()
        )

        XCTAssertTrue(appState.recentSourceApplications.isEmpty)
    }

    @MainActor
    func testAppStateKeepsRecentRoutingHistoryLimitedAndSanitized() throws {
        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            )
        )

        for index in 0..<25 {
            let request = try IncomingURLRequest(
                urlString:
                    "https://example\(index).com/private?token=secret",
                source: sourceResult(
                    bundleIdentifier: "com.example.Source\(index)",
                    name: "Source \(index)"
                )
            )
            appState.recordRoutingHistory(
                request: request,
                result: routingResult(
                    requestID: request.id,
                    finalBrowserName: "Safari"
                )
            )
        }

        XCTAssertEqual(appState.recentRoutingHistory.count, 20)
        XCTAssertEqual(
            appState.recentRoutingHistory.first?
                .sanitizedURLDescription,
            "https://example24.com"
        )
        XCTAssertEqual(
            appState.recentRoutingHistory.first?
                .sourceApplication?.bundleIdentifier,
            "com.example.Source24"
        )
        XCTAssertFalse(
            appState.recentRoutingHistory.contains {
                $0.sanitizedURLDescription.contains("token")
            }
        )
    }

    @MainActor
    func testAppStatePersistsAddedRule() throws {
        let store = ConfigurationStore(
            directoryURL: temporaryDirectoryURL
        )
        let appState = AppState(configurationStore: store)
        let rule = try makeRule(id: "persisted-rule")

        let result = appState.addRule(rule)

        XCTAssertNoThrow(try result.get())
        let savedConfiguration = try JSONDecoder().decode(
            RoutingConfiguration.self,
            from: Data(contentsOf: store.configurationURL)
        )
        XCTAssertTrue(
            savedConfiguration.rules.contains {
                $0.id == "persisted-rule"
            }
        )
    }

    @MainActor
    func testAppStateBlocksEditingForCorruptedConfiguration() throws {
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
        let store = ConfigurationStore(
            directoryURL: temporaryDirectoryURL
        )
        let corruptedData = Data("{invalid-json".utf8)
        try corruptedData.write(to: store.configurationURL)
        let appState = AppState(configurationStore: store)

        let result = appState.addRule(
            try makeRule(id: "blocked-rule")
        )

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(
                error as? ConfigurationEditingError,
                .editingDisabled
            )
        }
        XCTAssertEqual(
            try Data(contentsOf: store.configurationURL),
            corruptedData
        )
    }

    private func makeRule(
        id: String,
        name: String = "New Rule"
    ) throws -> RoutingRule {
        let draft = RoutingRuleDraft(
            id: id,
            name: name,
            sourceAppBundleIdentifier: "com.example.Source",
            sourceAppName: "Source",
            browserBundleIdentifier: "com.apple.Safari"
        )

        return try draft.makeRule(
            availableBrowsers: [try safari()]
        )
    }

    private func safari() throws -> Browser {
        try browser(at: "/Applications/Safari.app")
    }

    private func browser(at path: String) throws -> Browser {
        let browser = try XCTUnwrap(
            Browser(applicationURL: URL(fileURLWithPath: path))
        )
        return browser
    }

    private func sourceResult(
        bundleIdentifier: String,
        name: String
    ) -> SourceDetectionResult {
        SourceDetectionResult(
            application: SourceApplication(
                bundleIdentifier: bundleIdentifier,
                name: name,
                processIdentifier: 123
            ),
            method: .appleEventSender,
            confidence: .high,
            reason: "Configuration editing test"
        )
    }

    private func routingResult(
        requestID: UUID,
        finalBrowserName: String?
    ) -> RoutingResult {
        RoutingResult(
            requestID: requestID,
            decision: RoutingDecision(
                matchedRule: nil,
                browserBundleIdentifier: "com.apple.Safari",
                browserName: "Safari",
                openInBackground: false,
                reason: "Configuration editing test"
            ),
            finalBrowserBundleIdentifier: finalBrowserName == nil
                ? nil
                : "com.apple.Safari",
            finalBrowserName: finalBrowserName,
            usedRecoveryFallback: false,
            notice: nil,
            errorDescription: nil
        )
    }
}
