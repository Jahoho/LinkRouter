import Foundation

enum RoutingAction: String, Codable, Equatable {
    case open
}

struct RoutingRule: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let enabled: Bool
    let priority: Int
    let sourceAppBundleIdentifier: String?
    let sourceAppName: String?
    let hostPattern: String?
    let urlScheme: String?
    let browserBundleIdentifier: String
    let browserName: String
    let browserProfileName: String?
    let browserProfileDirectory: String?
    let action: RoutingAction
    let openInBackground: Bool

    init(
        id: String,
        name: String,
        enabled: Bool,
        priority: Int,
        sourceAppBundleIdentifier: String?,
        sourceAppName: String?,
        hostPattern: String?,
        urlScheme: String?,
        browserBundleIdentifier: String,
        browserName: String,
        browserProfileName: String? = nil,
        browserProfileDirectory: String? = nil,
        action: RoutingAction,
        openInBackground: Bool
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.priority = priority
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
        self.sourceAppName = sourceAppName
        self.hostPattern = hostPattern
        self.urlScheme = urlScheme
        self.browserBundleIdentifier = browserBundleIdentifier
        self.browserName = browserName
        self.browserProfileName = browserProfileName
        self.browserProfileDirectory = browserProfileDirectory
        self.action = action
        self.openInBackground = openInBackground
    }
}

struct RoutingDecision: Equatable {
    let matchedRule: RoutingRule?
    let skippedRuleNames: [String]
    let browserBundleIdentifier: String
    let browserName: String
    let browserProfileName: String?
    let browserProfileDirectory: String?
    let openInBackground: Bool
    let reason: String

    init(
        matchedRule: RoutingRule?,
        skippedRuleNames: [String],
        browserBundleIdentifier: String,
        browserName: String,
        browserProfileName: String? = nil,
        browserProfileDirectory: String? = nil,
        openInBackground: Bool,
        reason: String
    ) {
        self.matchedRule = matchedRule
        self.skippedRuleNames = skippedRuleNames
        self.browserBundleIdentifier = browserBundleIdentifier
        self.browserName = browserName
        self.browserProfileName = browserProfileName
        self.browserProfileDirectory = browserProfileDirectory
        self.openInBackground = openInBackground
        self.reason = reason
    }

    var usedConfiguredFallback: Bool {
        matchedRule == nil
    }

    var browserDisplayName: String {
        if let browserProfileName {
            return "\(browserName) (\(browserProfileName))"
        }

        return browserName
    }
}
