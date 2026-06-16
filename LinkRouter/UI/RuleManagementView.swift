import SwiftUI

private struct RuleEditorContext: Identifiable {
    enum Mode {
        case add
        case edit
    }

    let id = UUID()
    let mode: Mode
    let draft: RoutingRuleDraft

    var title: String {
        switch mode {
        case .add:
            return "Add Rule"
        case .edit:
            return "Edit Rule"
        }
    }
}

struct RuleManagementView: View {
    @EnvironmentObject private var appState: AppState

    @State private var editorContext: RuleEditorContext?
    @State private var rulePendingDeletion: RoutingRule?

    var body: some View {
        Group {
            if let sourceApplication = actionableLastSourceApplication {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Last detected app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(sourceApplication.name)
                        Text(sourceApplication.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(lastSourceActionTitle) {
                        openEditorForLastSource()
                    }
                    .disabled(
                        !appState.canEditConfiguration
                            || defaultBrowserForNewRule == nil
                    )
                }

                if appState.lastRequest?.source.confidence != .high {
                    Text(
                        "This source was detected with \(appState.lastRequest?.source.confidence.rawValue ?? "Unknown") confidence. Review it before saving a rule."
                    )
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Divider()
            }

            ForEach(appState.routingConfiguration.rules) { rule in
                HStack {
                    Toggle(
                        isOn: Binding(
                            get: { rule.enabled },
                            set: { enabled in
                                _ = appState.setRuleEnabled(
                                    id: rule.id,
                                    enabled: enabled
                                )
                            }
                        )
                    ) {
                        VStack(alignment: .leading) {
                            Text(rule.name)
                            Text(
                                "\(rule.sourceAppName ?? rule.sourceAppBundleIdentifier ?? "Unknown source") -> \(rule.browserName)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!appState.canEditConfiguration)

                    Spacer()

                    Text("Priority \(rule.priority)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Edit") {
                        editorContext = RuleEditorContext(
                            mode: .edit,
                            draft: RoutingRuleDraft(rule: rule)
                        )
                    }
                    .disabled(!appState.canEditConfiguration)

                    Button("Delete", role: .destructive) {
                        rulePendingDeletion = rule
                    }
                    .disabled(!appState.canEditConfiguration)
                }
            }

            if appState.routingConfiguration.rules.isEmpty {
                Text("No source-app rules are configured.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Picker(
                    "Fallback browser",
                    selection: Binding(
                        get: {
                            appState.routingConfiguration
                                .defaultBrowserBundleIdentifier
                        },
                        set: { bundleIdentifier in
                            _ = appState.setFallbackBrowser(
                                bundleIdentifier: bundleIdentifier
                            )
                        }
                    )
                ) {
                    if !appState.availableBrowsers.contains(where: {
                        $0.bundleIdentifier
                            == appState.routingConfiguration
                                .defaultBrowserBundleIdentifier
                    }) {
                        Text(
                            "\(appState.routingConfiguration.defaultBrowserName) (Unavailable)"
                        )
                        .tag(
                            appState.routingConfiguration
                                .defaultBrowserBundleIdentifier
                        )
                    }

                    ForEach(appState.availableBrowsers) { browser in
                        Text(browser.name)
                            .tag(browser.bundleIdentifier)
                    }
                }
                .disabled(
                    !appState.canEditConfiguration
                        || appState.availableBrowsers.isEmpty
                )

                Spacer()

                Button("Add Rule") {
                    let defaultBrowserIdentifier =
                        appState.availableBrowsers.first?.bundleIdentifier
                        ?? appState.routingConfiguration
                            .defaultBrowserBundleIdentifier

                    editorContext = RuleEditorContext(
                        mode: .add,
                        draft: RoutingRuleDraft(
                            browserBundleIdentifier:
                                defaultBrowserIdentifier
                        )
                    )
                }
                .disabled(
                    !appState.canEditConfiguration
                        || appState.availableBrowsers.isEmpty
                )
            }

            if let message = appState.configurationEditMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(
                        appState.configurationEditFailed
                            ? Color.red
                            : Color.secondary
                    )
            }
        }
        .sheet(item: $editorContext) { context in
            RuleEditorView(
                title: context.title,
                draft: context.draft,
                availableBrowsers: appState.availableBrowsers
            ) { rule in
                switch context.mode {
                case .add:
                    return appState.addRule(rule)
                case .edit:
                    return appState.updateRule(rule)
                }
            }
        }
        .confirmationDialog(
            "Delete this rule?",
            isPresented: Binding(
                get: { rulePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        rulePendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: rulePendingDeletion
        ) { rule in
            Button("Delete \(rule.name)", role: .destructive) {
                _ = appState.deleteRule(id: rule.id)
                rulePendingDeletion = nil
            }
        } message: { rule in
            Text(
                "Links from this source will use another matching rule or the fallback browser."
            )
        }
    }

    private var actionableLastSourceApplication: SourceApplication? {
        guard
            let application = appState.lastRequest?.source.application,
            AppSourceDetector.isCredibleSource(application)
        else {
            return nil
        }

        return application
    }

    private var existingRuleForLastSource: RoutingRule? {
        guard let sourceApplication = actionableLastSourceApplication else {
            return nil
        }

        return appState.routingConfiguration.rules.first { rule in
            rule.sourceAppBundleIdentifier?.caseInsensitiveCompare(
                sourceApplication.bundleIdentifier
            ) == .orderedSame
        }
    }

    private var defaultBrowserForNewRule: Browser? {
        appState.availableBrowsers.first { browser in
            browser.bundleIdentifier
                == appState.routingConfiguration
                    .defaultBrowserBundleIdentifier
        } ?? appState.availableBrowsers.first
    }

    private var lastSourceActionTitle: String {
        existingRuleForLastSource == nil
            ? "Create Rule from This App"
            : "Edit Rule for This App"
    }

    private func openEditorForLastSource() {
        if let existingRuleForLastSource {
            editorContext = RuleEditorContext(
                mode: .edit,
                draft: RoutingRuleDraft(rule: existingRuleForLastSource)
            )
            return
        }

        guard
            let sourceApplication = actionableLastSourceApplication,
            let browser = defaultBrowserForNewRule
        else {
            return
        }

        editorContext = RuleEditorContext(
            mode: .add,
            draft: RoutingRuleDraft(
                sourceApplication: sourceApplication,
                browser: browser
            )
        )
    }
}

private struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let availableBrowsers: [Browser]
    let onSave:
        (RoutingRule) -> Result<Void, ConfigurationEditingError>

    @State private var draft: RoutingRuleDraft
    @State private var errorMessage: String?

    init(
        title: String,
        draft: RoutingRuleDraft,
        availableBrowsers: [Browser],
        onSave: @escaping
            (RoutingRule) -> Result<Void, ConfigurationEditingError>
    ) {
        self.title = title
        self.availableBrowsers = availableBrowsers
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Rule name", text: $draft.name)
                TextField(
                    "Source app name",
                    text: $draft.sourceAppName
                )
                TextField(
                    "Source bundle identifier",
                    text: $draft.sourceAppBundleIdentifier
                )

                Picker(
                    "Destination browser",
                    selection: $draft.browserBundleIdentifier
                ) {
                    if !availableBrowsers.contains(where: {
                        $0.bundleIdentifier
                            == draft.browserBundleIdentifier
                    }) {
                        Text("Current browser (Unavailable)")
                            .tag(draft.browserBundleIdentifier)
                    }

                    ForEach(availableBrowsers) { browser in
                        Text(browser.name)
                            .tag(browser.bundleIdentifier)
                    }
                }

                Stepper(
                    "Priority: \(draft.priority)",
                    value: $draft.priority,
                    in: 0...1000
                )

                Toggle("Enabled", isOn: $draft.enabled)
                Toggle(
                    "Open without activating browser",
                    isOn: $draft.openInBackground
                )

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 520, height: 440)
        .navigationTitle(title)
    }

    private func save() {
        do {
            let rule = try draft.makeRule(
                availableBrowsers: availableBrowsers
            )

            switch onSave(rule) {
            case .success:
                dismiss()
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
