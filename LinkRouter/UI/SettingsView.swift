import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("URL listener", value: "Active")
                LabeledContent(
                    "Links received",
                    value: String(appState.receivedRequestCount)
                )
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
                } else {
                    Text("Open a web link after selecting LinkRouter as the default browser.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Text("LinkRouter currently logs only the URL scheme and host. Paths, queries, fragments, and credentials are removed.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 360)
        .navigationTitle("LinkRouter Settings")
    }
}
