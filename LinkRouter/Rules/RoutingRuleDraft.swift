import Foundation

enum RoutingRuleValidationError: LocalizedError, Equatable {
    case missingName
    case missingConditions
    case invalidSourceBundleIdentifier
    case invalidHostPattern
    case invalidURLScheme
    case browserUnavailable
    case browserProfileUnavailable

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Enter a rule name."
        case .missingConditions:
            return "Choose a source app, domain, or URL scheme for this rule."
        case .invalidSourceBundleIdentifier:
            return "Enter a valid source app bundle identifier, such as com.example.App."
        case .invalidHostPattern:
            return "Enter a valid domain, such as github.com or *.github.com."
        case .invalidURLScheme:
            return "Use http, https, or leave the URL scheme blank."
        case .browserUnavailable:
            return "Select an installed destination browser."
        case .browserProfileUnavailable:
            return "Select a profile that belongs to the destination browser."
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
    var browserProfileName: String
    var browserProfileDirectory: String
    var openInBackground: Bool
    var hostPattern: String
    var urlScheme: String
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
        browserProfileName = rule.browserProfileName ?? ""
        browserProfileDirectory = rule.browserProfileDirectory ?? ""
        openInBackground = rule.openInBackground
        hostPattern = rule.hostPattern ?? ""
        urlScheme = rule.urlScheme ?? ""
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
        browserProfileName: String = "",
        browserProfileDirectory: String = "",
        openInBackground: Bool = false,
        hostPattern: String = "",
        urlScheme: String = "",
        action: RoutingAction = .open
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.priority = priority
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
        self.sourceAppName = sourceAppName
        self.browserBundleIdentifier = browserBundleIdentifier
        self.browserProfileName = browserProfileName
        self.browserProfileDirectory = browserProfileDirectory
        self.openInBackground = openInBackground
        self.hostPattern = hostPattern
        self.urlScheme = urlScheme
        self.action = action
    }

    func makeRule(
        availableBrowsers: [Browser],
        availableBrowserProfiles: [BrowserProfile] = []
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
        if !trimmedBundleIdentifier.isEmpty,
           !Self.isValidBundleIdentifier(trimmedBundleIdentifier) {
            throw RoutingRuleValidationError
                .invalidSourceBundleIdentifier
        }

        let trimmedHostPattern = hostPattern.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedHostPattern.isEmpty,
           !Self.isValidHostPattern(trimmedHostPattern) {
            throw RoutingRuleValidationError.invalidHostPattern
        }

        let trimmedURLScheme = urlScheme.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        if !trimmedURLScheme.isEmpty,
           trimmedURLScheme != "http",
           trimmedURLScheme != "https" {
            throw RoutingRuleValidationError.invalidURLScheme
        }

        guard
            !trimmedBundleIdentifier.isEmpty
                || !trimmedHostPattern.isEmpty
                || !trimmedURLScheme.isEmpty
        else {
            throw RoutingRuleValidationError.missingConditions
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
        let trimmedProfileDirectory =
            browserProfileDirectory.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let selectedProfile: BrowserProfile?
        if trimmedProfileDirectory.isEmpty {
            selectedProfile = nil
        } else {
            guard
                let profile = availableBrowserProfiles.first(where: {
                    $0.browserBundleIdentifier.caseInsensitiveCompare(
                        browser.bundleIdentifier
                    ) == .orderedSame
                        && $0.profileDirectory == trimmedProfileDirectory
                })
            else {
                throw RoutingRuleValidationError.browserProfileUnavailable
            }

            selectedProfile = profile
        }

        return RoutingRule(
            id: id,
            name: trimmedName,
            enabled: enabled,
            priority: priority,
            sourceAppBundleIdentifier:
                trimmedBundleIdentifier.isEmpty
                    ? nil
                    : trimmedBundleIdentifier,
            sourceAppName:
                trimmedSourceName.isEmpty ? nil : trimmedSourceName,
            hostPattern:
                trimmedHostPattern.isEmpty ? nil : trimmedHostPattern,
            urlScheme:
                trimmedURLScheme.isEmpty ? nil : trimmedURLScheme,
            browserBundleIdentifier: browser.bundleIdentifier,
            browserName: browser.name,
            browserProfileName: selectedProfile?.profileName,
            browserProfileDirectory: selectedProfile?.profileDirectory,
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

    static func isValidHostPattern(_ value: String) -> Bool {
        var host = value.lowercased()

        if host.hasPrefix("*.") {
            host = String(host.dropFirst(2))
        }

        guard
            !host.isEmpty,
            host.contains("."),
            !host.contains("://"),
            !host.contains("/"),
            !host.contains(" "),
            !host.hasPrefix("."),
            !host.hasSuffix(".")
        else {
            return false
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-.")
        )

        return host.unicodeScalars.allSatisfy {
            allowedCharacters.contains($0)
        }
    }
}

struct RuleHealthWarning: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

struct RuleHealthChecker {
    static func warnings(
        for rule: RoutingRule,
        availableBrowsers: [Browser],
        availableBrowserProfiles: [BrowserProfile] = []
    ) -> [RuleHealthWarning] {
        var warnings: [RuleHealthWarning] = []

        if let sourceBundleIdentifier = rule.sourceAppBundleIdentifier,
           !RoutingRuleDraft.isValidBundleIdentifier(sourceBundleIdentifier) {
            warnings.append(
                RuleHealthWarning(
                    id: "invalid-source-\(rule.id)",
                    title: "Invalid source bundle identifier",
                    detail:
                        "\(sourceBundleIdentifier) will never match a normal macOS app bundle identifier."
                )
            )
        }

        if let hostPattern = rule.hostPattern,
           !RoutingRuleDraft.isValidHostPattern(hostPattern) {
            warnings.append(
                RuleHealthWarning(
                    id: "invalid-host-\(rule.id)",
                    title: "Invalid domain pattern",
                    detail:
                        "\(hostPattern) will never match a normal web domain."
                )
            )
        }

        warnings.append(
            contentsOf: destinationWarnings(
                idPrefix: rule.id,
                browserName: rule.browserName,
                browserBundleIdentifier: rule.browserBundleIdentifier,
                availableBrowsers: availableBrowsers
            )
        )

        if let profileDirectory = rule.browserProfileDirectory {
            let profileAvailable = availableBrowserProfiles.contains {
                $0.browserBundleIdentifier.caseInsensitiveCompare(
                    rule.browserBundleIdentifier
                ) == .orderedSame
                    && $0.profileDirectory == profileDirectory
            }

            if !profileAvailable {
                warnings.append(
                    RuleHealthWarning(
                        id: "missing-profile-\(rule.id)",
                        title: "Browser profile unavailable",
                        detail:
                            "\(rule.browserProfileName ?? profileDirectory) is not available for \(rule.browserName)."
                    )
                )
            }
        }

        return warnings
    }

    static func fallbackWarnings(
        configuration: RoutingConfiguration,
        availableBrowsers: [Browser]
    ) -> [RuleHealthWarning] {
        destinationWarnings(
            idPrefix: "fallback",
            browserName: configuration.defaultBrowserName,
            browserBundleIdentifier:
                configuration.defaultBrowserBundleIdentifier,
            availableBrowsers: availableBrowsers
        )
    }

    private static func destinationWarnings(
        idPrefix: String,
        browserName: String,
        browserBundleIdentifier: String,
        availableBrowsers: [Browser]
    ) -> [RuleHealthWarning] {
        var warnings: [RuleHealthWarning] = []

        if !BrowserDiscovery.isAllowedDestination(
            bundleIdentifier: browserBundleIdentifier
        ) {
            warnings.append(
                RuleHealthWarning(
                    id: "self-loop-\(idPrefix)",
                    title: "Destination points back to LinkRouter",
                    detail:
                        "Choose another browser to avoid routing the same link back into LinkRouter."
                )
            )
        }

        let browserAvailable = availableBrowsers.contains {
            $0.bundleIdentifier.caseInsensitiveCompare(
                browserBundleIdentifier
            ) == .orderedSame
        }

        if !browserAvailable {
            warnings.append(
                RuleHealthWarning(
                    id: "missing-browser-\(idPrefix)",
                    title: "Destination browser unavailable",
                    detail:
                        "\(browserName) is not in the installed browser list right now."
                )
            )
        }

        return warnings
    }
}
