import XCTest
@testable import LinkRouter

final class BrowserTests: XCTestCase {
    func testRejectsLinkRouterAsBrowserDestination() {
        XCTAssertFalse(
            BrowserDiscovery.isAllowedDestination(
                bundleIdentifier: "com.james.LinkRouter"
            )
        )
    }

    func testAllowsSafariAndChromeAsBrowserDestinations() {
        XCTAssertTrue(
            BrowserDiscovery.isAllowedDestination(
                bundleIdentifier: "com.apple.Safari"
            )
        )
        XCTAssertTrue(
            BrowserDiscovery.isAllowedDestination(
                bundleIdentifier: "com.google.Chrome"
            )
        )
    }

    func testBrowserLaunchErrorsHaveReadableDescriptions() {
        XCTAssertNotNil(BrowserLaunchError.invalidWebURL.errorDescription)
        XCTAssertNotNil(
            BrowserLaunchError.routingLoopPrevented.errorDescription
        )
        XCTAssertNotNil(
            BrowserLaunchError.browserNotInstalled("Arc").errorDescription
        )
    }

    @MainActor
    func testDiscoveryFindsSafariAndExcludesLinkRouter() {
        let browsers = BrowserDiscovery.shared.discoverInstalledBrowsers()
        let bundleIdentifiers = Set(
            browsers.map(\.bundleIdentifier)
        )

        XCTAssertTrue(bundleIdentifiers.contains("com.apple.Safari"))
        XCTAssertFalse(bundleIdentifiers.contains("com.james.LinkRouter"))
    }

    @MainActor
    func testExplicitSafariLaunchWhenEnabled() throws {
        guard
            ProcessInfo.processInfo.environment[
                "LINKROUTER_RUN_BROWSER_LAUNCH_TESTS"
            ] == "1"
        else {
            throw XCTSkip(
                "Set LINKROUTER_RUN_BROWSER_LAUNCH_TESTS=1 to run browser launch integration tests."
            )
        }

        guard
            let safari = BrowserDiscovery.shared
                .discoverInstalledBrowsers()
                .first(where: {
                    $0.bundleIdentifier == "com.apple.Safari"
                }),
            let url = URL(string: "https://example.com")
        else {
            XCTFail("Safari or the test URL is unavailable.")
            return
        }

        let expectation = expectation(
            description: "Safari opens the test URL"
        )

        BrowserLauncher.shared.open(url, in: safari) { result in
            switch result {
            case let .success(application):
                XCTAssertEqual(
                    application.bundleIdentifier,
                    "com.apple.Safari"
                )
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }
}
