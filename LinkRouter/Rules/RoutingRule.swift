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
    let action: RoutingAction
    let openInBackground: Bool
}

struct RoutingDecision: Equatable {
    let matchedRule: RoutingRule?
    let browserBundleIdentifier: String
    let browserName: String
    let openInBackground: Bool
    let reason: String

    var usedConfiguredFallback: Bool {
        matchedRule == nil
    }
}
