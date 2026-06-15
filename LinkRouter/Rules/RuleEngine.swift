import Foundation

struct RuleEngine {
    func evaluate(
        request: IncomingURLRequest,
        configuration: RoutingConfiguration
    ) -> RoutingDecision {
        let orderedRules = configuration.rules
            .enumerated()
            .filter { $0.element.enabled }
            .sorted { first, second in
                if first.element.priority != second.element.priority {
                    return first.element.priority > second.element.priority
                }

                return first.offset < second.offset
            }
            .map(\.element)

        if let matchedRule = orderedRules.first(where: {
            matches($0, request: request)
        }) {
            return RoutingDecision(
                matchedRule: matchedRule,
                browserBundleIdentifier: matchedRule.browserBundleIdentifier,
                browserName: matchedRule.browserName,
                openInBackground: matchedRule.openInBackground,
                reason: "Matched enabled rule \(matchedRule.name)."
            )
        }

        return RoutingDecision(
            matchedRule: nil,
            browserBundleIdentifier:
                configuration.defaultBrowserBundleIdentifier,
            browserName: configuration.defaultBrowserName,
            openInBackground: false,
            reason: "No enabled rule matched, so the configured fallback was selected."
        )
    }

    private func matches(
        _ rule: RoutingRule,
        request: IncomingURLRequest
    ) -> Bool {
        let hasCondition = rule.sourceAppBundleIdentifier != nil
            || rule.hostPattern != nil
            || rule.urlScheme != nil

        guard hasCondition, rule.action == .open else {
            return false
        }

        if let sourceBundleIdentifier = rule.sourceAppBundleIdentifier {
            guard
                let detectedBundleIdentifier =
                    request.source.application?.bundleIdentifier,
                detectedBundleIdentifier.caseInsensitiveCompare(
                    sourceBundleIdentifier
                ) == .orderedSame
            else {
                return false
            }
        }

        if let hostPattern = rule.hostPattern {
            guard hostMatches(request.url.host, pattern: hostPattern) else {
                return false
            }
        }

        if let urlScheme = rule.urlScheme {
            guard
                request.url.scheme?.caseInsensitiveCompare(urlScheme)
                    == .orderedSame
            else {
                return false
            }
        }

        return true
    }

    private func hostMatches(_ host: String?, pattern: String) -> Bool {
        guard let normalizedHost = host?.lowercased() else {
            return false
        }

        let normalizedPattern = pattern.lowercased()

        if normalizedPattern.hasPrefix("*.") {
            let baseHost = String(normalizedPattern.dropFirst(2))
            return normalizedHost == baseHost
                || normalizedHost.hasSuffix(".\(baseHost)")
        }

        return normalizedHost == normalizedPattern
    }
}
