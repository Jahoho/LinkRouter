import AppKit

private enum BrowserDiscoveryConstants {
    static let probeURL = URL(string: "https://example.com")!
    static let linkRouterBundleIdentifier = "com.james.LinkRouter"
    static let preferredOrder = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser"
    ]
}

@MainActor
final class BrowserDiscovery {
    static let shared = BrowserDiscovery()

    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func discoverInstalledBrowsers() -> [Browser] {
        let applicationURLs = workspace.urlsForApplications(
            toOpen: BrowserDiscoveryConstants.probeURL
        )

        var browsersByIdentifier: [String: Browser] = [:]

        for applicationURL in applicationURLs {
            guard
                let browser = Browser(applicationURL: applicationURL),
                Self.isAllowedDestination(
                    bundleIdentifier: browser.bundleIdentifier
                )
            else {
                continue
            }

            browsersByIdentifier[browser.bundleIdentifier] = browser
        }

        return browsersByIdentifier.values.sorted(by: Self.sortBrowsers)
    }

    nonisolated static func isAllowedDestination(
        bundleIdentifier: String
    ) -> Bool {
        bundleIdentifier
            != BrowserDiscoveryConstants.linkRouterBundleIdentifier
    }

    nonisolated private static func sortBrowsers(
        _ first: Browser,
        _ second: Browser
    ) -> Bool {
        let firstRank = BrowserDiscoveryConstants.preferredOrder.firstIndex(
            of: first.bundleIdentifier
        )
        let secondRank = BrowserDiscoveryConstants.preferredOrder.firstIndex(
            of: second.bundleIdentifier
        )

        switch (firstRank, secondRank) {
        case let (firstRank?, secondRank?):
            return firstRank < secondRank
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return first.name.localizedCaseInsensitiveCompare(second.name)
                == .orderedAscending
        }
    }
}
