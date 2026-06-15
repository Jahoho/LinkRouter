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
}
