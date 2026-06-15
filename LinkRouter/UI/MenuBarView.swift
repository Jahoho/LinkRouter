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

            Divider()

            SettingsLink {
                Label("Settings", systemImage: "gear")
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
