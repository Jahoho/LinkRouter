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

    func testDraftBuildsDomainOnlyRule() throws {
        let draft = RoutingRuleDraft(
            name: "GitHub to Safari",
            sourceAppBundleIdentifier: "",
            browserBundleIdentifier: "com.apple.Safari",
            hostPattern: "*.github.com",
            urlScheme: "https"
        )

        let rule = try draft.makeRule(
            availableBrowsers: [try safari()]
        )

        XCTAssertNil(rule.sourceAppBundleIdentifier)
        XCTAssertEqual(rule.hostPattern, "*.github.com")
        XCTAssertEqual(rule.urlScheme, "https")
    }

    func testDraftBuildsRuleWithBrowserProfile() throws {
        let safari = try safari()
        let profile = BrowserProfile(
            browserBundleIdentifier: safari.bundleIdentifier,
            browserName: safari.name,
            profileDirectory: "Profile 1",
            profileName: "Work"
        )
        let draft = RoutingRuleDraft(
            name: "Work Links",
            sourceAppBundleIdentifier: "com.example.Source",
            browserBundleIdentifier: safari.bundleIdentifier,
            browserProfileDirectory: profile.profileDirectory
        )

        let rule = try draft.makeRule(
            availableBrowsers: [safari],
            availableBrowserProfiles: [profile]
        )

        XCTAssertEqual(rule.browserProfileName, "Work")
        XCTAssertEqual(rule.browserProfileDirectory, "Profile 1")
    }

    func testBrowserProfileDiscoveryParsesChromiumLocalState() throws {
        let safari = try safari()
        let data = Data(
            """
            {
              "profile": {
                "info_cache": {
                  "Profile 1": { "name": "Work" },
                  "Default": { "name": "Personal" }
                }
              }
            }
            """.utf8
        )

        let profiles = BrowserProfileDiscovery.profiles(
            fromLocalStateData: data,
            browser: safari
        )

        XCTAssertEqual(profiles.map(\.profileDirectory), ["Default", "Profile 1"])
        XCTAssertEqual(profiles.map(\.profileName), ["Personal", "Work"])
    }

    func testFileDefaultAppManagerResolvesCommonContentTypes() throws {
        XCTAssertNotNil(
            FileDefaultAppManager.contentTypeIdentifier(for: "pdf")
        )
        XCTAssertNotNil(
            FileDefaultAppManager.contentTypeIdentifier(for: ".txt")
        )
    }

    func testFileDefaultAppManagerBuildsExpandedDefinitions() throws {
        let definitions = FileDefaultAppManager.definitions(
            customExtensions: ["plist", ".plist", "md"]
        )

        XCTAssertGreaterThan(definitions.count, 20)
        XCTAssertTrue(
            definitions.contains {
                $0.fileExtension == "png" && !$0.isCustom
            }
        )
        XCTAssertTrue(
            definitions.contains {
                $0.fileExtension == "html" && !$0.isCustom
            }
        )
        XCTAssertEqual(
            definitions.filter { $0.fileExtension == "plist" }.count,
            1
        )
        XCTAssertTrue(
            definitions.contains {
                $0.fileExtension == "plist" && $0.isCustom
            }
        )
    }

    func testDraftRejectsMissingConditions() throws {
        let draft = RoutingRuleDraft(
            name: "No Conditions",
            sourceAppBundleIdentifier: "",
            browserBundleIdentifier: "com.apple.Safari"
        )

        XCTAssertThrowsError(
            try draft.makeRule(availableBrowsers: [try safari()])
        ) { error in
            XCTAssertEqual(
                error as? RoutingRuleValidationError,
                .missingConditions
            )
        }
    }

    func testDraftRejectsInvalidHostPattern() throws {
        let draft = RoutingRuleDraft(
            name: "Invalid Host",
            sourceAppBundleIdentifier: "",
            browserBundleIdentifier: "com.apple.Safari",
            hostPattern: "https://github.com/path"
        )

        XCTAssertThrowsError(
            try draft.makeRule(availableBrowsers: [try safari()])
        ) { error in
            XCTAssertEqual(
                error as? RoutingRuleValidationError,
                .invalidHostPattern
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

    func testMovesRuleEarlierAndNormalizesMatchOrder() throws {
        let first = routingRule(
            id: "first",
            browserBundleIdentifier: "browser.first",
            browserName: "First",
            priority: 30
        )
        let second = routingRule(
            id: "second",
            browserBundleIdentifier: "browser.second",
            browserName: "Second",
            priority: 20
        )
        let third = routingRule(
            id: "third",
            browserBundleIdentifier: "browser.third",
            browserName: "Third",
            priority: 10
        )
        let configuration = RoutingConfiguration(
            schemaVersion: 1,
            defaultBrowserBundleIdentifier: "com.apple.Safari",
            defaultBrowserName: "Safari",
            rules: [first, second, third]
        )

        let updated = try editor.movingRuleEarlier(
            ruleID: "third",
            in: configuration
        )

        XCTAssertEqual(
            RoutingConfigurationEditor.effectiveRuleOrder(
                updated.rules
            ).map(\.id),
            ["first", "third", "second"]
        )
        XCTAssertEqual(updated.rules.map(\.priority), [30, 20, 10])
    }

    func testMovesRuleBeforeTargetAndNormalizesMatchOrder() throws {
        let first = routingRule(
            id: "first",
            browserBundleIdentifier: "browser.first",
            browserName: "First",
            priority: 30
        )
        let second = routingRule(
            id: "second",
            browserBundleIdentifier: "browser.second",
            browserName: "Second",
            priority: 20
        )
        let third = routingRule(
            id: "third",
            browserBundleIdentifier: "browser.third",
            browserName: "Third",
            priority: 10
        )
        let configuration = RoutingConfiguration(
            schemaVersion: 1,
            defaultBrowserBundleIdentifier: "com.apple.Safari",
            defaultBrowserName: "Safari",
            rules: [first, second, third]
        )

        let updated = try editor.movingRule(
            ruleID: "third",
            before: "first",
            in: configuration
        )

        XCTAssertEqual(
            RoutingConfigurationEditor.effectiveRuleOrder(
                updated.rules
            ).map(\.id),
            ["third", "first", "second"]
        )
        XCTAssertEqual(updated.rules.map(\.priority), [30, 20, 10])
    }

    func testMoveRuleLaterRejectsLastRule() throws {
        XCTAssertThrowsError(
            try editor.movingRuleLater(
                ruleID: "mail-to-safari",
                in: .seed
            )
        ) { error in
            XCTAssertEqual(
                error as? ConfigurationEditingError,
                .ruleAlreadyLast
            )
        }
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

    func testRuleHealthFlagsUnavailableDestinationBrowser() throws {
        let rule = routingRule(
            id: "missing-browser",
            browserBundleIdentifier: "com.example.MissingBrowser",
            browserName: "Missing Browser"
        )

        let warnings = RuleHealthChecker.warnings(
            for: rule,
            availableBrowsers: [try safari()]
        )

        XCTAssertTrue(
            warnings.contains {
                $0.id == "missing-browser-missing-browser"
            }
        )
    }

    func testRuleHealthFlagsDestinationSelfLoop() throws {
        let rule = routingRule(
            id: "self-loop",
            browserBundleIdentifier: "com.james.LinkRouter",
            browserName: "LinkRouter"
        )

        let warnings = RuleHealthChecker.warnings(
            for: rule,
            availableBrowsers: [try safari()]
        )

        XCTAssertTrue(
            warnings.contains {
                $0.id == "self-loop-self-loop"
            }
        )
    }

    func testRuleHealthFlagsInvalidSourceBundleIdentifier() throws {
        let rule = routingRule(
            id: "invalid-source",
            sourceAppBundleIdentifier: "not a bundle id"
        )

        let warnings = RuleHealthChecker.warnings(
            for: rule,
            availableBrowsers: [try safari()]
        )

        XCTAssertTrue(
            warnings.contains {
                $0.id == "invalid-source-invalid-source"
            }
        )
    }

    func testRuleHealthFlagsInvalidHostPattern() throws {
        let rule = routingRule(
            id: "invalid-host",
            sourceAppBundleIdentifier: nil,
            hostPattern: "https://example.com/path"
        )

        let warnings = RuleHealthChecker.warnings(
            for: rule,
            availableBrowsers: [try safari()]
        )

        XCTAssertTrue(
            warnings.contains {
                $0.id == "invalid-host-invalid-host"
            }
        )
    }

    func testRuleHealthFlagsUnavailableFallbackBrowser() throws {
        let configuration = RoutingConfiguration(
            schemaVersion: 1,
            defaultBrowserBundleIdentifier: "com.example.MissingBrowser",
            defaultBrowserName: "Missing Browser",
            rules: []
        )

        let warnings = RuleHealthChecker.fallbackWarnings(
            configuration: configuration,
            availableBrowsers: [try safari()]
        )

        XCTAssertTrue(
            warnings.contains {
                $0.id == "missing-browser-fallback"
            }
        )
    }

    func testRoutingResultExplainsFallbackDecision() throws {
        let request = try IncomingURLRequest(
            urlString: "https://example.com/private?token=secret",
            source: sourceResult(
                bundleIdentifier: "com.apple.mail",
                name: "Mail"
            )
        )
        let result = routingResult(
            requestID: request.id,
            finalBrowserName: "Safari"
        )

        let lines = result.explanationLines(source: request.source)

        XCTAssertTrue(
            lines.contains {
                $0.contains("Source detected as Mail")
            }
        )
        XCTAssertTrue(
            lines.contains {
                $0.contains("No enabled rule matched")
            }
        )
        XCTAssertTrue(
            lines.contains {
                $0.contains("Final browser: Safari")
            }
        )
    }

    func testRoutingHistoryStoresExplanationLines() throws {
        let request = try IncomingURLRequest(
            urlString: "https://example.com/private?token=secret",
            source: sourceResult(
                bundleIdentifier: "com.apple.mail",
                name: "Mail"
            )
        )
        let item = RoutingHistoryItem(
            request: request,
            result: routingResult(
                requestID: request.id,
                finalBrowserName: "Safari"
            )
        )

        XCTAssertTrue(
            item.explanationLines.contains {
                $0.contains("Source detected as Mail")
            }
        )
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
    func testAppStateBuildsSourceCompatibilityReports() throws {
        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            )
        )
        let mailHigh = try IncomingURLRequest(
            urlString: "https://example.com/one?token=secret",
            source: sourceResult(
                bundleIdentifier: "com.apple.mail",
                name: "Mail",
                method: .appleEventSender,
                confidence: .high
            )
        )
        let mailMedium = try IncomingURLRequest(
            urlString: "https://example.com/two",
            source: sourceResult(
                bundleIdentifier: "com.apple.mail",
                name: "Mail",
                method: .frontmostApplication,
                confidence: .medium
            )
        )
        let obsidian = try IncomingURLRequest(
            urlString: "https://example.com/three",
            source: sourceResult(
                bundleIdentifier: "md.obsidian",
                name: "Obsidian",
                method: .frontmostApplication,
                confidence: .medium
            )
        )
        let unknown = try IncomingURLRequest(
            urlString: "https://example.com/four",
            source: .unknown(reason: "No source")
        )

        for request in [mailHigh, mailMedium, obsidian, unknown] {
            appState.recordRoutingHistory(
                request: request,
                result: routingResult(
                    requestID: request.id,
                    finalBrowserName: "Safari"
                )
            )
        }

        let reports = appState.sourceCompatibilityReports

        XCTAssertEqual(reports.count, 2)
        XCTAssertEqual(appState.unknownSourceHistoryCount, 1)
        XCTAssertEqual(reports.first?.bundleIdentifier, "com.apple.mail")
        XCTAssertEqual(reports.first?.sampleCount, 2)
        XCTAssertEqual(reports.first?.highConfidenceCount, 1)
        XCTAssertEqual(reports.first?.mediumConfidenceCount, 1)
        XCTAssertEqual(reports.first?.status, .reliable)
        XCTAssertEqual(
            reports.first?.detectionMethods,
            [.frontmostApplication, .appleEventSender]
        )
        XCTAssertEqual(reports.last?.status, .needsMoreSamples)
    }

    @MainActor
    func testSetupHealthFlagsMissingRuntimeSignals() throws {
        let defaults = try isolatedDefaults()
        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )
        let healthItems = appState.setupHealthItems

        XCTAssertEqual(
            healthItems.first(where: { $0.id == "listener" })?.level,
            .ok
        )
        XCTAssertEqual(
            healthItems.first(where: { $0.id == "source-detection" })?.level,
            .warning
        )
        XCTAssertEqual(
            healthItems.first(where: { $0.id == "routing-history" })?.level,
            .warning
        )
        XCTAssertTrue(healthItems.contains { $0.level != .ok })
    }

    @MainActor
    func testSetupHealthImprovesAfterRuntimeSignals() throws {
        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            )
        )
        let request = try IncomingURLRequest(
            urlString: "https://example.com/private?token=secret",
            source: sourceResult(
                bundleIdentifier: "com.apple.mail",
                name: "Mail"
            )
        )

        appState.rememberSourceApplication(
            request.source,
            at: request.receivedAt
        )
        appState.recordRoutingHistory(
            request: request,
            result: routingResult(
                requestID: request.id,
                finalBrowserName: "Safari"
            )
        )

        XCTAssertEqual(
            appState.setupHealthItems.first {
                $0.id == "source-detection"
            }?.level,
            .ok
        )
        XCTAssertEqual(
            appState.setupHealthItems.first {
                $0.id == "routing-history"
            }?.level,
            .ok
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

    @MainActor
    func testAppStateExportsImportsAndResetsConfiguration() throws {
        let store = ConfigurationStore(
            directoryURL: temporaryDirectoryURL
        )
        let appState = AppState(configurationStore: store)
        let rule = try makeRule(id: "exported-rule")
        XCTAssertNoThrow(try appState.addRule(rule).get())

        let exportURL = temporaryDirectoryURL
            .appendingPathComponent("export.json")
        XCTAssertNoThrow(
            try appState.exportConfiguration(to: exportURL).get()
        )

        XCTAssertNoThrow(
            try appState.resetConfiguration().get()
        )
        XCTAssertFalse(
            appState.routingConfiguration.rules.contains {
                $0.id == "exported-rule"
            }
        )

        XCTAssertNoThrow(
            try appState.importConfiguration(from: exportURL).get()
        )
        XCTAssertTrue(
            appState.routingConfiguration.rules.contains {
                $0.id == "exported-rule"
            }
        )
    }

    @MainActor
    func testAppStateRoutingControlsTrackPauseAndNextLinkOverride() throws {
        let defaults = try isolatedDefaults()
        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )
        let safari = try safari()

        appState.pauseRoutingForTenMinutes()
        XCTAssertTrue(appState.isRoutingPaused)
        XCTAssertTrue(
            appState.routingControlSummary.contains("paused")
        )

        appState.openNextLink(in: safari)
        XCTAssertFalse(appState.isRoutingPaused)
        XCTAssertEqual(
            appState.nextLinkBrowserOverride?.bundleIdentifier,
            "com.apple.Safari"
        )

        appState.clearNextLinkOverride()
        XCTAssertNil(appState.nextLinkBrowserOverride)
    }

    @MainActor
    func testAppStatePersistsOnboardingCompletion() throws {
        let suiteName = "LinkRouterOnboardingTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )

        XCTAssertTrue(appState.shouldShowOnboarding)

        appState.completeOnboarding()
        XCTAssertFalse(appState.shouldShowOnboarding)

        let restoredState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )
        XCTAssertTrue(restoredState.hasCompletedOnboarding)

        restoredState.resetOnboarding()
        XCTAssertTrue(restoredState.shouldShowOnboarding)
    }

    @MainActor
    func testAppStatePersistsLanguagePreference() throws {
        let suiteName = "LinkRouterLanguageTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )

        appState.setLanguage(.chinese)
        XCTAssertEqual(appState.language, .chinese)
        XCTAssertEqual(appState.text("Settings", "设置"), "设置")

        let restoredState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )

        XCTAssertEqual(restoredState.language, .chinese)
    }

    @MainActor
    func testAppStatePersistsCustomFileDefaultExtension() throws {
        let suiteName =
            "LinkRouterFileDefaultExtensionTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )

        let result = appState.trackFileDefaultExtension("plist")

        XCTAssertNoThrow(try result.get())
        XCTAssertTrue(
            appState.trackedFileDefaultDefinitions.contains {
                $0.fileExtension == "plist" && $0.isCustom
            }
        )

        let restoredState = AppState(
            configurationStore: ConfigurationStore(
                directoryURL: temporaryDirectoryURL
            ),
            userDefaults: defaults
        )

        XCTAssertTrue(
            restoredState.trackedFileDefaultDefinitions.contains {
                $0.fileExtension == "plist" && $0.isCustom
            }
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

    private func routingRule(
        id: String,
        sourceAppBundleIdentifier: String? = "com.example.Source",
        browserBundleIdentifier: String = "com.apple.Safari",
        browserName: String = "Safari",
        hostPattern: String? = nil,
        priority: Int = 50
    ) -> RoutingRule {
        RoutingRule(
            id: id,
            name: "Test Rule",
            enabled: true,
            priority: priority,
            sourceAppBundleIdentifier: sourceAppBundleIdentifier,
            sourceAppName: "Source",
            hostPattern: hostPattern,
            urlScheme: nil,
            browserBundleIdentifier: browserBundleIdentifier,
            browserName: browserName,
            action: .open,
            openInBackground: false
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
        name: String,
        method: SourceDetectionMethod = .appleEventSender,
        confidence: SourceDetectionConfidence = .high
    ) -> SourceDetectionResult {
        SourceDetectionResult(
            application: SourceApplication(
                bundleIdentifier: bundleIdentifier,
                name: name,
                processIdentifier: 123
            ),
            method: method,
            confidence: confidence,
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
                skippedRuleNames: [],
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

    private func isolatedDefaults() throws -> UserDefaults {
        let suiteName = "LinkRouterTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
