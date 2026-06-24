import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showsSetupHealth = false
    @State private var showsResetConfirmation = false
    @State private var showsOnboarding = false

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

                HStack {
                    Button("View Setup Guide") {
                        showsOnboarding = true
                    }

                    Button("View Setup Health") {
                        appState.refreshDefaultBrowserStatus()
                        appState.refreshLaunchAtLoginStatus()
                        showsSetupHealth = true
                    }

                    Text(appState.setupHealthSummary)
                        .font(.caption)
                        .foregroundStyle(
                            appState.setupHealthItems.allSatisfy {
                                $0.level == .ok
                            }
                                ? Color.secondary
                                : Color.orange
                        )
                }

                if !appState.hasCompletedOnboarding {
                    Text("Setup guide has not been completed yet.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("Refresh Default Browser Status") {
                        appState.refreshDefaultBrowserStatus()
                    }

                    Button("Refresh Launch at Login Status") {
                        appState.refreshLaunchAtLoginStatus()
                    }
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

                HStack {
                    Button("Export Configuration") {
                        exportConfiguration()
                    }
                    .disabled(!appState.canEditConfiguration)

                    Button("Import Configuration") {
                        importConfiguration()
                    }
                    .disabled(!appState.canEditConfiguration)

                    Button("Reset to Defaults", role: .destructive) {
                        showsResetConfirmation = true
                    }
                    .disabled(!appState.canEditConfiguration)
                }
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why this happened")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(
                            result.explanationLines(
                                source: appState.lastRequest?.source
                            ),
                            id: \.self
                        ) { line in
                            Text("• \(line)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        .sheet(isPresented: $showsSetupHealth) {
            SetupHealthView(items: appState.setupHealthItems)
        }
        .sheet(isPresented: $showsOnboarding) {
            OnboardingView(
                defaultBrowserStatus: appState.defaultBrowserStatus,
                fallbackBrowserName:
                    appState.routingConfiguration.defaultBrowserName,
                configurationPath: appState.configurationFileURL.path,
                onRefreshDefaultBrowser: {
                    appState.refreshDefaultBrowserStatus()
                },
                onOpenSetupHealth: {
                    showsOnboarding = false
                    appState.refreshDefaultBrowserStatus()
                    appState.refreshLaunchAtLoginStatus()
                    showsSetupHealth = true
                },
                onComplete: {
                    appState.completeOnboarding()
                    showsOnboarding = false
                }
            )
        }
        .confirmationDialog(
            "Reset routing configuration?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) {
                _ = appState.resetConfiguration()
            }
        } message: {
            Text(
                "This replaces the current rules with the seed rules. Export first if you want a backup."
            )
        }
        .formStyle(.grouped)
        .frame(width: 820, height: 880)
        .navigationTitle("LinkRouter Settings")
        .onAppear {
            if appState.shouldShowOnboarding {
                showsOnboarding = true
            }
        }
    }

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "linkrouter-routing-config.json"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        _ = appState.exportConfiguration(to: url)
    }

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        _ = appState.importConfiguration(from: url)
    }
}

private struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    let defaultBrowserStatus: DefaultBrowserStatus
    let fallbackBrowserName: String
    let configurationPath: String
    let onRefreshDefaultBrowser: () -> Void
    let onOpenSetupHealth: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Up LinkRouter")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("LinkRouter stays small by doing one job locally: receive web links, apply your rules, and forward them to the right browser.")
                            .foregroundStyle(.secondary)
                    }
                }

                onboardingStep(
                    title: "1. Keep LinkRouter running",
                    detail: "It lives in the menu bar. If the app quits, macOS will no longer deliver links to it."
                )

                onboardingStep(
                    title: "2. Make it the default browser",
                    detail:
                        defaultBrowserStatus.isLinkRouterDefault
                            ? "Done. New web links should reach LinkRouter first."
                            : "Open System Settings and set Default web browser to LinkRouter, then refresh this status."
                ) {
                    HStack {
                        Text(defaultBrowserStatus.title)
                            .font(.caption)
                            .foregroundStyle(
                                defaultBrowserStatus.isLinkRouterDefault
                                    ? Color.secondary
                                    : Color.orange
                            )

                        Button("Refresh Status") {
                            onRefreshDefaultBrowser()
                        }
                    }
                }

                onboardingStep(
                    title: "3. Verify browsers and fallback",
                    detail:
                        "Settings lists installed browsers and can open a test page. If no rule matches, LinkRouter uses \(fallbackBrowserName)."
                )

                onboardingStep(
                    title: "4. Create rules from real app clicks",
                    detail:
                        "Open a test link from Mail, Codex, WeChat, or another app, then create a rule from Recent source apps or Recent routing history."
                )

                onboardingStep(
                    title: "5. Privacy and backups",
                    detail:
                        "Diagnostics show sanitized hosts by default. Rules are stored as local JSON at \(configurationPath). Export before major changes."
                )

                Button("Open Setup Health") {
                    onOpenSetupHealth()
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Show Later") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Mark Setup Complete") {
                    onComplete()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 680, height: 620)
    }

    private func onboardingStep<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func onboardingStep(
        title: String,
        detail: String
    ) -> some View {
        onboardingStep(title: title, detail: detail) {
            EmptyView()
        }
    }
}

private struct SetupHealthView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [SetupHealthItem]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                ForEach(items) { item in
                    HStack(alignment: .top) {
                        Image(systemName: iconName(for: item.level))
                            .foregroundStyle(color(for: item.level))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.level.title)
                                .font(.caption)
                                .foregroundStyle(color(for: item.level))
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 620, height: 520)
    }

    private func iconName(for level: SetupHealthLevel) -> String {
        switch level {
        case .ok:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private func color(for level: SetupHealthLevel) -> Color {
        switch level {
        case .ok:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
