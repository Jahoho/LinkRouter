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

struct DefaultBrowserStatus: Equatable {
    let isLinkRouterDefault: Bool
    let currentBrowserName: String?
    let currentBrowserBundleIdentifier: String?
    let detail: String

    var title: String {
        if isLinkRouterDefault {
            return "LinkRouter is default"
        }

        if let currentBrowserName {
            return "\(currentBrowserName) is default"
        }

        return "Unable to determine"
    }

    static let unknown = DefaultBrowserStatus(
        isLinkRouterDefault: false,
        currentBrowserName: nil,
        currentBrowserBundleIdentifier: nil,
        detail: "macOS did not return a default HTTPS handler."
    )

    static func evaluate(
        defaultApplicationURL: URL?,
        currentBundleIdentifier: String,
        browserInfo: (URL) -> (name: String, bundleIdentifier: String)? = {
            applicationURL in
            guard let browser = Browser(applicationURL: applicationURL) else {
                return nil
            }

            return (browser.name, browser.bundleIdentifier)
        }
    ) -> DefaultBrowserStatus {
        guard let defaultApplicationURL else {
            return .unknown
        }

        guard let info = browserInfo(defaultApplicationURL) else {
            return DefaultBrowserStatus(
                isLinkRouterDefault: false,
                currentBrowserName: nil,
                currentBrowserBundleIdentifier: nil,
                detail: "The default HTTPS handler could not be inspected."
            )
        }

        let isLinkRouterDefault =
            info.bundleIdentifier == currentBundleIdentifier

        return DefaultBrowserStatus(
            isLinkRouterDefault: isLinkRouterDefault,
            currentBrowserName: info.name,
            currentBrowserBundleIdentifier: info.bundleIdentifier,
            detail: isLinkRouterDefault
                ? "New web links should be delivered to LinkRouter first."
                : "New web links currently go directly to \(info.name)."
        )
    }
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

    func currentDefaultBrowserStatus() -> DefaultBrowserStatus {
        let applicationURL = workspace.urlForApplication(
            toOpen: BrowserDiscoveryConstants.probeURL
        )

        return DefaultBrowserStatus.evaluate(
            defaultApplicationURL: applicationURL,
            currentBundleIdentifier: BrowserDiscoveryConstants
                .linkRouterBundleIdentifier
        )
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
