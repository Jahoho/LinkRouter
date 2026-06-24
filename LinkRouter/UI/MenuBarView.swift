import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("URL listener is active", systemImage: "checkmark.circle")

            if let lastRequest = appState.lastRequest {
                Text("Last link: \(lastRequest.sanitizedDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    "Source: \(lastRequest.source.application?.name ?? "Unknown") (\(lastRequest.source.confidence.rawValue))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("No links received yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Browsers found: \(appState.availableBrowsers.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.defaultBrowserStatus.title)
                .font(.caption)
                .foregroundStyle(
                    appState.defaultBrowserStatus.isLinkRouterDefault
                        ? Color.secondary
                        : Color.orange
                )

            if let result = appState.lastRoutingResult {
                Text(result.statusDescription)
                    .font(.caption)
                    .foregroundStyle(
                        result.succeeded ? Color.secondary : Color.red
                    )
            }

            Divider()

            Text(appState.routingControlSummary)
                .font(.caption)
                .foregroundStyle(
                    appState.isRoutingPaused
                        || appState.nextLinkBrowserOverride != nil
                        ? Color.orange
                        : Color.secondary
                )

            if appState.isRoutingPaused {
                Button("Resume Routing") {
                    appState.resumeRouting()
                }
            } else {
                Button("Pause Routing for 10 Minutes") {
                    appState.pauseRoutingForTenMinutes()
                }
            }

            if appState.nextLinkBrowserOverride != nil {
                Button("Clear Next-Link Override") {
                    appState.clearNextLinkOverride()
                }
            }

            Menu("Open Next Link With") {
                ForEach(appState.availableBrowsers) { browser in
                    Button(browser.name) {
                        appState.openNextLink(in: browser)
                    }
                }
            }
            .disabled(appState.availableBrowsers.isEmpty)

            Divider()

            SettingsLink {
                Label("Settings", systemImage: "gear")
            }

            Button {
                appState.resetOnboarding()
                NSApp.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
            } label: {
                Label("Setup Guide", systemImage: "checklist")
            }

            Button("Quit LinkRouter") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(minWidth: 260)
    }
}
