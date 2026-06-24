import Foundation

enum ConfigurationEditingError: LocalizedError, Equatable {
    case duplicateRuleIdentifier
    case ruleNotFound
    case editingDisabled
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .duplicateRuleIdentifier:
            return "A rule with the same identifier already exists."
        case .ruleNotFound:
            return "The rule no longer exists."
        case .editingDisabled:
            return "Editing is disabled while LinkRouter is protecting an unreadable configuration file."
        case let .saveFailed(message):
            return "The configuration could not be saved: \(message)"
        }
    }
}

struct RoutingConfigurationEditor {
    func adding(
        _ rule: RoutingRule,
        to configuration: RoutingConfiguration
    ) throws -> RoutingConfiguration {
        guard !configuration.rules.contains(where: { $0.id == rule.id }) else {
            throw ConfigurationEditingError.duplicateRuleIdentifier
        }

        return replacingRules(
            configuration.rules + [rule],
            in: configuration
        )
    }

    func updating(
        _ rule: RoutingRule,
        in configuration: RoutingConfiguration
    ) throws -> RoutingConfiguration {
        guard
            let index = configuration.rules.firstIndex(where: {
                $0.id == rule.id
            })
        else {
            throw ConfigurationEditingError.ruleNotFound
        }

        var rules = configuration.rules
        rules[index] = rule
        return replacingRules(rules, in: configuration)
    }

    func deleting(
        ruleID: String,
        from configuration: RoutingConfiguration
    ) throws -> RoutingConfiguration {
        guard configuration.rules.contains(where: { $0.id == ruleID }) else {
            throw ConfigurationEditingError.ruleNotFound
        }

        return replacingRules(
            configuration.rules.filter { $0.id != ruleID },
            in: configuration
        )
    }

    func settingEnabled(
        _ enabled: Bool,
        for ruleID: String,
        in configuration: RoutingConfiguration
    ) throws -> RoutingConfiguration {
        guard
            let rule = configuration.rules.first(where: {
                $0.id == ruleID
            })
        else {
            throw ConfigurationEditingError.ruleNotFound
        }

        let updatedRule = RoutingRule(
            id: rule.id,
            name: rule.name,
            enabled: enabled,
            priority: rule.priority,
            sourceAppBundleIdentifier:
                rule.sourceAppBundleIdentifier,
            sourceAppName: rule.sourceAppName,
            hostPattern: rule.hostPattern,
            urlScheme: rule.urlScheme,
            browserBundleIdentifier:
                rule.browserBundleIdentifier,
            browserName: rule.browserName,
            browserProfileName: rule.browserProfileName,
            browserProfileDirectory: rule.browserProfileDirectory,
            action: rule.action,
            openInBackground: rule.openInBackground
        )

        return try updating(updatedRule, in: configuration)
    }

    func settingFallback(
        _ browser: Browser,
        in configuration: RoutingConfiguration
    ) -> RoutingConfiguration {
        RoutingConfiguration(
            schemaVersion: configuration.schemaVersion,
            defaultBrowserBundleIdentifier: browser.bundleIdentifier,
            defaultBrowserName: browser.name,
            rules: configuration.rules
        )
    }

    private func replacingRules(
        _ rules: [RoutingRule],
        in configuration: RoutingConfiguration
    ) -> RoutingConfiguration {
        RoutingConfiguration(
            schemaVersion: configuration.schemaVersion,
            defaultBrowserBundleIdentifier:
                configuration.defaultBrowserBundleIdentifier,
            defaultBrowserName: configuration.defaultBrowserName,
            rules: rules
        )
    }
}
