import Foundation

struct RoutingConfiguration: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let defaultBrowserBundleIdentifier: String
    let defaultBrowserName: String
    let rules: [RoutingRule]

    static let seed = RoutingConfiguration(
        schemaVersion: currentSchemaVersion,
        defaultBrowserBundleIdentifier: "com.apple.Safari",
        defaultBrowserName: "Safari",
        rules: [
            RoutingRule(
                id: "codex-to-chrome",
                name: "Codex to Chrome",
                enabled: true,
                priority: 100,
                sourceAppBundleIdentifier: "com.openai.codex",
                sourceAppName: "Codex",
                hostPattern: nil,
                urlScheme: nil,
                browserBundleIdentifier: "com.google.Chrome",
                browserName: "Google Chrome",
                action: .open,
                openInBackground: false
            ),
            RoutingRule(
                id: "wechat-to-safari",
                name: "WeChat to Safari",
                enabled: true,
                priority: 90,
                sourceAppBundleIdentifier: "com.tencent.xinWeChat",
                sourceAppName: "WeChat",
                hostPattern: nil,
                urlScheme: nil,
                browserBundleIdentifier: "com.apple.Safari",
                browserName: "Safari",
                action: .open,
                openInBackground: false
            )
        ]
    )
}
