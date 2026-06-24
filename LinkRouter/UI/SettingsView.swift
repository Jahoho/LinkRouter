import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("URL listener", value: "Active")
                LabeledContent(
                    "Default web browser",
                    value: appState.defaultBrowserStatus.title
                )
                Text(appState.defaultBrowserStatus.detail)
                    .font(.caption)
                    .foregroundStyle(
                        appState.defaultBrowserStatus.isLinkRouterDefault
                            ? Color.secondary
                            : Color.orange
                    )
                LabeledContent(
                    "Links received",
                    value: String(appState.receivedRequestCount)
                )

                Button("Refresh Default Browser Status") {
                    appState.refreshDefaultBrowserStatus()
                }
            }

            Section("Startup") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { appState.launchAtLoginStatus.isEnabled },
                        set: { isEnabled in
                            appState.setLaunchAtLoginEnabled(isEnabled)
                        }
                    )
                )

                LabeledContent(
                    "Status",
                    value: appState.launchAtLoginStatus.title
                )

                Text(appState.launchAtLoginStatus.detail)
                    .font(.caption)
                    .foregroundStyle(
                        appState.launchAtLoginStatus == .requiresApproval
                            ? Color.orange
                            : Color.secondary
                    )

                if let launchAtLoginMessage =
                    appState.launchAtLoginMessage
                {
                    Text(launchAtLoginMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Launch at Login Status") {
                    appState.refreshLaunchAtLoginStatus()
                }
            }

            Section("Last received link") {
                if let lastRequest = appState.lastRequest {
                    LabeledContent("Sanitized URL") {
                        Text(lastRequest.sanitizedDescription)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Received at") {
                        Text(lastRequest.receivedAt, format: .dateTime)
                    }

                    LabeledContent(
                        "Source app",
                        value: lastRequest.source.application?.name ?? "Unknown"
                    )

                    LabeledContent(
                        "Bundle identifier",
                        value: lastRequest.source.application?.bundleIdentifier ?? "Unknown"
                    )

                    LabeledContent(
                        "Detection method",
                        value: lastRequest.source.method.rawValue
                    )

                    LabeledContent(
                        "Confidence",
                        value: lastRequest.source.confidence.rawValue
                    )

                    LabeledContent("Detection note") {
                        Text(lastRequest.source.reason)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Open a web link after selecting LinkRouter as the default browser.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Installed browsers") {
                if appState.availableBrowsers.isEmpty {
                    Text("No HTTPS-capable browser was found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.availableBrowsers) { browser in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(browser.name)
                                Text(browser.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Open Test Page") {
                                appState.openTestPage(in: browser)
                            }
                            .disabled(appState.isLaunchingBrowser)
                        }
                    }
                }

                HStack {
                    Button("Refresh Browser List") {
                        appState.refreshBrowsers()
                    }

                    if let browserLaunchStatus = appState.browserLaunchStatus {
                        Text(browserLaunchStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Routing rules") {
                RuleManagementView()
            }

            Section("Configuration storage") {
                LabeledContent(
                    "Status",
                    value: appState.configurationStatus.title
                )

                LabeledContent(
                    "Schema version",
                    value: String(
                        appState.routingConfiguration.schemaVersion
                    )
                )

                LabeledContent("File") {
                    Text(appState.configurationFileURL.path)
                        .textSelection(.enabled)
                }

                Text(appState.configurationStatus.detail)
                    .foregroundStyle(
                        appState.configurationStatus.isUsingInMemoryFallback
                            ? Color.red
                            : Color.secondary
                    )
            }

            Section("Last routing result") {
                if let result = appState.lastRoutingResult {
                    LabeledContent(
                        "Status",
                        value: result.succeeded ? "Succeeded" : "Failed"
                    )

                    LabeledContent(
                        "Matched rule",
                        value: result.decision.matchedRule?.name ?? "Fallback"
                    )

                    LabeledContent(
                        "Selected browser",
                        value: result.decision.browserName
                    )

                    LabeledContent(
                        "Final browser",
                        value: result.finalBrowserName ?? "None"
                    )

                    if let notice = result.notice {
                        Text(notice)
                            .foregroundStyle(.orange)
                    }

                    if let errorDescription = result.errorDescription {
                        Text(errorDescription)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("No routing decision has been completed yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Text("LinkRouter currently logs only the URL scheme and host. Paths, queries, fragments, and credentials are removed.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 820, height: 880)
        .navigationTitle("LinkRouter Settings")
    }
}
