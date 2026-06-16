import Foundation

enum RoutingRuleValidationError: LocalizedError, Equatable {
    case missingName
    case invalidSourceBundleIdentifier
    case browserUnavailable

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Enter a rule name."
        case .invalidSourceBundleIdentifier:
            return "Enter a valid source app bundle identifier, such as com.example.App."
        case .browserUnavailable:
            return "Select an installed destination browser."
        }
    }
}

struct RoutingRuleDraft: Equatable {
    let id: String
    var name: String
    var enabled: Bool
    var priority: Int
    var sourceAppBundleIdentifier: String
    var sourceAppName: String
    var browserBundleIdentifier: String
    var openInBackground: Bool
    private let hostPattern: String?
    private let urlScheme: String?
    private let action: RoutingAction

    init(rule: RoutingRule) {
        id = rule.id
        name = rule.name
        enabled = rule.enabled
        priority = rule.priority
        sourceAppBundleIdentifier =
            rule.sourceAppBundleIdentifier ?? ""
        sourceAppName = rule.sourceAppName ?? ""
        browserBundleIdentifier = rule.browserBundleIdentifier
        openInBackground = rule.openInBackground
        hostPattern = rule.hostPattern
        urlScheme = rule.urlScheme
        action = rule.action
    }

    init(
        sourceApplication: SourceApplication,
        browser: Browser,
        priority: Int = 50
    ) {
        self.init(
            name: "\(sourceApplication.name) to \(browser.name)",
            priority: priority,
            sourceAppBundleIdentifier:
                sourceApplication.bundleIdentifier,
            sourceAppName: sourceApplication.name,
            browserBundleIdentifier: browser.bundleIdentifier
        )
    }

    init(
        id: String = "user-\(UUID().uuidString.lowercased())",
        name: String = "New Rule",
        enabled: Bool = true,
        priority: Int = 50,
        sourceAppBundleIdentifier: String = "",
        sourceAppName: String = "",
        browserBundleIdentifier: String,
        openInBackground: Bool = false,
        hostPattern: String? = nil,
        urlScheme: String? = nil,
        action: RoutingAction = .open
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.priority = priority
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
        self.sourceAppName = sourceAppName
        self.browserBundleIdentifier = browserBundleIdentifier
        self.openInBackground = openInBackground
        self.hostPattern = hostPattern
        self.urlScheme = urlScheme
        self.action = action
    }

    func makeRule(
        availableBrowsers: [Browser]
    ) throws -> RoutingRule {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedName.isEmpty else {
            throw RoutingRuleValidationError.missingName
        }

        let trimmedBundleIdentifier =
            sourceAppBundleIdentifier.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        guard Self.isValidBundleIdentifier(trimmedBundleIdentifier) else {
            throw RoutingRuleValidationError
                .invalidSourceBundleIdentifier
        }

        guard
            let browser = availableBrowsers.first(where: {
                $0.bundleIdentifier.caseInsensitiveCompare(
                    browserBundleIdentifier
                ) == .orderedSame
            })
        else {
            throw RoutingRuleValidationError.browserUnavailable
        }

        let trimmedSourceName = sourceAppName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return RoutingRule(
            id: id,
            name: trimmedName,
            enabled: enabled,
            priority: priority,
            sourceAppBundleIdentifier: trimmedBundleIdentifier,
            sourceAppName:
                trimmedSourceName.isEmpty ? nil : trimmedSourceName,
            hostPattern: hostPattern,
            urlScheme: urlScheme,
            browserBundleIdentifier: browser.bundleIdentifier,
            browserName: browser.name,
            action: action,
            openInBackground: openInBackground
        )
    }

    static func isValidBundleIdentifier(_ value: String) -> Bool {
        let components = value.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard components.count >= 2 else {
            return false
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-")
        )

        return components.allSatisfy { component in
            !component.isEmpty
                && component.unicodeScalars.allSatisfy {
                    allowedCharacters.contains($0)
                }
        }
    }
}
