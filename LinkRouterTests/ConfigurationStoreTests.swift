import XCTest
@testable import LinkRouter

final class ConfigurationStoreTests: XCTestCase {
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LinkRouterConfigurationStoreTests-\(UUID().uuidString)",
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

    func testCreatesSeedWhenConfigurationIsMissing() throws {
        let store = makeStore()

        let result = store.loadOrCreateSeed()

        XCTAssertEqual(result.configuration, .seed)
        XCTAssertEqual(result.status, .createdSeed)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: store.configurationURL.path
            )
        )

        let savedConfiguration = try decodeConfiguration(
            at: store.configurationURL
        )
        XCTAssertEqual(savedConfiguration, .seed)
    }

    func testLoadsExistingConfiguration() throws {
        let store = makeStore()
        let configuration = customConfiguration()
        try store.save(configuration)

        let result = store.loadOrCreateSeed()

        XCTAssertEqual(result.configuration, configuration)
        XCTAssertEqual(result.status, .loaded)
    }

    func testSaveAtomicallyReplacesExistingConfiguration() throws {
        let store = makeStore()
        try store.save(.seed)

        let replacement = customConfiguration()
        try store.save(replacement)

        XCTAssertEqual(
            try decodeConfiguration(at: store.configurationURL),
            replacement
        )
    }

    func testCorruptedConfigurationIsPreserved() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
        let corruptedData = Data("{invalid-json".utf8)
        try corruptedData.write(to: store.configurationURL)

        let result = store.loadOrCreateSeed()

        XCTAssertEqual(result.configuration, .seed)
        XCTAssertTrue(result.status.isUsingInMemoryFallback)
        XCTAssertEqual(
            try Data(contentsOf: store.configurationURL),
            corruptedData
        )
    }

    func testUnsupportedSchemaIsPreserved() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
        let unsupportedConfiguration = RoutingConfiguration(
            schemaVersion:
                RoutingConfiguration.currentSchemaVersion + 1,
            defaultBrowserBundleIdentifier: "com.apple.Safari",
            defaultBrowserName: "Safari",
            rules: []
        )
        let data = try JSONEncoder().encode(unsupportedConfiguration)
        try data.write(to: store.configurationURL)

        let result = store.loadOrCreateSeed()

        XCTAssertEqual(result.configuration, .seed)
        XCTAssertTrue(result.status.isUsingInMemoryFallback)
        XCTAssertEqual(
            try Data(contentsOf: store.configurationURL),
            data
        )
    }

    func testSaveRejectsUnsupportedSchema() {
        let store = makeStore()
        let unsupportedConfiguration = RoutingConfiguration(
            schemaVersion:
                RoutingConfiguration.currentSchemaVersion + 1,
            defaultBrowserBundleIdentifier: "com.apple.Safari",
            defaultBrowserName: "Safari",
            rules: []
        )

        XCTAssertThrowsError(
            try store.save(unsupportedConfiguration)
        ) { error in
            XCTAssertEqual(
                error as? ConfigurationStoreError,
                .unsupportedSchemaVersion(
                    RoutingConfiguration.currentSchemaVersion + 1
                )
            )
        }
    }

    func testSaveRejectsLinkRouterFallback() {
        let store = makeStore()
        let configuration = RoutingConfiguration(
            schemaVersion: RoutingConfiguration.currentSchemaVersion,
            defaultBrowserBundleIdentifier: "com.james.LinkRouter",
            defaultBrowserName: "LinkRouter",
            rules: []
        )

        XCTAssertThrowsError(
            try store.save(configuration)
        ) { error in
            XCTAssertEqual(
                error as? ConfigurationStoreError,
                .invalidFallbackBrowser
            )
        }
    }

    func testSaveRejectsMalformedRuleConditions() {
        let store = makeStore()
        let configuration = RoutingConfiguration(
            schemaVersion: RoutingConfiguration.currentSchemaVersion,
            defaultBrowserBundleIdentifier: "com.apple.Safari",
            defaultBrowserName: "Safari",
            rules: [
                RoutingRule(
                    id: "bad-rule",
                    name: "Bad Rule",
                    enabled: true,
                    priority: 50,
                    sourceAppBundleIdentifier: "not a bundle id",
                    sourceAppName: "Bad",
                    hostPattern: nil,
                    urlScheme: nil,
                    browserBundleIdentifier: "com.apple.Safari",
                    browserName: "Safari",
                    action: .open,
                    openInBackground: false
                )
            ]
        )

        XCTAssertThrowsError(
            try store.save(configuration)
        ) { error in
            XCTAssertEqual(
                error as? ConfigurationStoreError,
                .invalidRule(
                    "Bad Rule",
                    "source bundle identifier is malformed"
                )
            )
        }
    }

    func testInvalidSavedConfigurationIsPreserved() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
        let configuration = RoutingConfiguration(
            schemaVersion: RoutingConfiguration.currentSchemaVersion,
            defaultBrowserBundleIdentifier: "com.james.LinkRouter",
            defaultBrowserName: "LinkRouter",
            rules: []
        )
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: store.configurationURL)

        let result = store.loadOrCreateSeed()

        XCTAssertEqual(result.configuration, .seed)
        XCTAssertTrue(result.status.isUsingInMemoryFallback)
        XCTAssertEqual(
            try Data(contentsOf: store.configurationURL),
            data
        )
    }

    private func makeStore() -> ConfigurationStore {
        ConfigurationStore(directoryURL: temporaryDirectoryURL)
    }

    private func decodeConfiguration(
        at url: URL
    ) throws -> RoutingConfiguration {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(
            RoutingConfiguration.self,
            from: data
        )
    }

    private func customConfiguration() -> RoutingConfiguration {
        RoutingConfiguration(
            schemaVersion: RoutingConfiguration.currentSchemaVersion,
            defaultBrowserBundleIdentifier: "com.google.Chrome",
            defaultBrowserName: "Google Chrome",
            rules: []
        )
    }
}
