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
    @State private var showsRoutingHistory = false

    var body: some View {
        Group {
            HStack {
                Button("View Recent Routing History") {
                    showsRoutingHistory = true
                }
                .disabled(appState.recentRoutingHistory.isEmpty)

                Text("\(appState.recentRoutingHistory.count) recent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appState.recentSourceApplications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent source apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(appState.recentSourceApplications) { recentSource in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(recentSource.application.name)
                                Text(recentSource.application.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(
                                    "\(recentSource.confidence.rawValue) confidence via \(recentSource.method.rawValue)"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    recentSource.confidence == .high
                                        ? Color.secondary
                                        : Color.orange
                                )
                            }

                            Spacer()

                            Button(
                                actionTitle(
                                    for: recentSource.application
                                )
                            ) {
                                openEditor(
                                    for: recentSource.application
                                )
                            }
                            .disabled(
                                !appState.canEditConfiguration
                                    || defaultBrowserForNewRule == nil
                            )
                        }
                    }
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
        .sheet(isPresented: $showsRoutingHistory) {
            RoutingHistoryView(
                history: appState.recentRoutingHistory,
                canEditConfiguration: appState.canEditConfiguration,
                canCreateRule: defaultBrowserForNewRule != nil
            ) { sourceApplication in
                showsRoutingHistory = false
                openEditor(for: sourceApplication)
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

    private func existingRule(
        for sourceApplication: SourceApplication
    ) -> RoutingRule? {
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

    private func actionTitle(
        for sourceApplication: SourceApplication
    ) -> String {
        existingRule(for: sourceApplication) == nil
            ? "Create Rule from This App"
            : "Edit Rule for This App"
    }

    private func openEditor(for sourceApplication: SourceApplication) {
        if let existingRule = existingRule(for: sourceApplication) {
            editorContext = RuleEditorContext(
                mode: .edit,
                draft: RoutingRuleDraft(rule: existingRule)
            )
            return
        }

        guard let browser = defaultBrowserForNewRule else {
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

private struct RoutingHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let history: [RoutingHistoryItem]
    let canEditConfiguration: Bool
    let canCreateRule: Bool
    let onOpenRule: (SourceApplication) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if history.isEmpty {
                    Text("No routing history yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(itemTitle(item))
                                    .font(.headline)
                                Text(item.sanitizedURLDescription)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                Text(item.routedAt, format: .dateTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(
                                    "\(item.confidence.rawValue) confidence via \(item.detectionMethod.rawValue)"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    item.confidence == .high
                                        ? Color.secondary
                                        : Color.orange
                                )
                                Text(item.statusDescription)
                                    .font(.caption)
                                    .foregroundStyle(
                                        item.errorDescription == nil
                                            ? Color.secondary
                                            : Color.red
                                    )
                            }

                            Spacer()

                            if let sourceApplication = item.sourceApplication {
                                Button("Create or Edit Rule") {
                                    onOpenRule(sourceApplication)
                                }
                                .disabled(
                                    !canEditConfiguration
                                        || !canCreateRule
                                )
                            } else {
                                Text("No source app detected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
        .frame(width: 760, height: 560)
    }

    private func itemTitle(_ item: RoutingHistoryItem) -> String {
        let sourceName = item.sourceApplication?.name ?? "Unknown source"
        let finalBrowserName = item.finalBrowserName ?? "No browser"
        return "\(sourceName) -> \(finalBrowserName)"
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
