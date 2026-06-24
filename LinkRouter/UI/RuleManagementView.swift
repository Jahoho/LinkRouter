import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
                VStack(alignment: .leading, spacing: 6) {
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
                                    "\(ruleConditionSummary(rule)) -> \(rule.browserName)"
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

                    let warnings = RuleHealthChecker.warnings(
                        for: rule,
                        availableBrowsers: appState.availableBrowsers
                    )

                    ForEach(warnings) { warning in
                        RuleHealthWarningView(warning: warning)
                    }
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

            ForEach(fallbackWarnings) { warning in
                RuleHealthWarningView(warning: warning)
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
                availableBrowsers: appState.availableBrowsers,
                recentSourceApplications:
                    appState.recentSourceApplications
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

    private var fallbackWarnings: [RuleHealthWarning] {
        RuleHealthChecker.fallbackWarnings(
            configuration: appState.routingConfiguration,
            availableBrowsers: appState.availableBrowsers
        )
    }

    private func ruleConditionSummary(_ rule: RoutingRule) -> String {
        var conditions: [String] = []

        if let source = rule.sourceAppName
            ?? rule.sourceAppBundleIdentifier {
            conditions.append(source)
        }

        if let hostPattern = rule.hostPattern {
            conditions.append(hostPattern)
        }

        if let urlScheme = rule.urlScheme {
            conditions.append(urlScheme)
        }

        return conditions.isEmpty
            ? "No conditions"
            : conditions.joined(separator: " + ")
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

private struct RuleHealthWarningView: View {
    let warning: RuleHealthWarning

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(warning.title)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(warning.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

                                ForEach(item.explanationLines, id: \.self) {
                                    line in
                                    Text("• \(line)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
    let recentSourceApplications: [RecentSourceApplication]
    let onSave:
        (RoutingRule) -> Result<Void, ConfigurationEditingError>

    @State private var draft: RoutingRuleDraft
    @State private var errorMessage: String?
    @State private var installedApplications: [SourceAppChoice] = []
    @State private var showsSourcePicker = false
    @State private var isDropTargeted = false

    init(
        title: String,
        draft: RoutingRuleDraft,
        availableBrowsers: [Browser],
        recentSourceApplications: [RecentSourceApplication],
        onSave: @escaping
            (RoutingRule) -> Result<Void, ConfigurationEditingError>
    ) {
        self.title = title
        self.availableBrowsers = availableBrowsers
        self.recentSourceApplications = recentSourceApplications
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Rule name", text: $draft.name)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(sourceSummary)
                            Text(sourceDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Choose Source App") {
                            showsSourcePicker = true
                        }
                    }

                    Text("Drop a .app here to fill the source automatically.")
                        .font(.caption)
                        .foregroundStyle(
                            isDropTargeted ? Color.accentColor : Color.secondary
                        )
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isDropTargeted
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.35),
                                    style: StrokeStyle(
                                        lineWidth: 1,
                                        dash: [4, 4]
                                    )
                                )
                        )
                        .onDrop(
                            of: [UTType.fileURL.identifier],
                            isTargeted: $isDropTargeted,
                            perform: handleDrop
                        )
                }

                DisclosureGroup("Advanced source fields") {
                    TextField(
                        "Source app name",
                        text: $draft.sourceAppName
                    )
                    TextField(
                        "Source bundle identifier",
                        text: $draft.sourceAppBundleIdentifier
                    )
                }

                TextField("Domain pattern", text: $draft.hostPattern)
                TextField("URL scheme", text: $draft.urlScheme)

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

                Menu("Quick Templates") {
                    ForEach(availableBrowsers) { browser in
                        Button("Always open in \(browser.name)") {
                            applyBrowserTemplate(browser)
                        }
                    }
                }
                .disabled(availableBrowsers.isEmpty)

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
        .frame(width: 580, height: 620)
        .navigationTitle(title)
        .sheet(isPresented: $showsSourcePicker) {
            SourceAppPickerView(
                recentApplications: recentSourceApplications.map {
                    SourceAppChoice(
                        application: $0.application,
                        subtitle: "\($0.confidence.rawValue) confidence, \($0.method.rawValue)",
                        applicationURL: NSWorkspace.shared.urlForApplication(
                            withBundleIdentifier:
                                $0.application.bundleIdentifier
                        )
                    )
                },
                installedApplications: installedApplications
            ) { application in
                applySourceApplication(application)
                showsSourcePicker = false
            }
        }
        .onAppear {
            if installedApplications.isEmpty {
                installedApplications =
                    InstalledApplicationScanner.scanApplications()
            }
        }
    }

    private var sourceSummary: String {
        if !draft.sourceAppName.isEmpty {
            return draft.sourceAppName
        }

        if !draft.sourceAppBundleIdentifier.isEmpty {
            return draft.sourceAppBundleIdentifier
        }

        return "No source app selected"
    }

    private var sourceDetail: String {
        if draft.sourceAppBundleIdentifier.isEmpty {
            return "Use the picker, recent history, or drag a .app bundle."
        }

        return draft.sourceAppBundleIdentifier
    }

    private func applySourceApplication(
        _ application: SourceApplication
    ) {
        draft.sourceAppName = application.name
        draft.sourceAppBundleIdentifier = application.bundleIdentifier

        if draft.name == "New Rule" || draft.name.isEmpty {
            draft.name = "\(application.name) to \(selectedBrowserName)"
        }
    }

    private func applyBrowserTemplate(_ browser: Browser) {
        draft.browserBundleIdentifier = browser.bundleIdentifier

        if !draft.sourceAppName.isEmpty {
            draft.name = "\(draft.sourceAppName) to \(browser.name)"
        } else if !draft.hostPattern.isEmpty {
            draft.name = "\(draft.hostPattern) to \(browser.name)"
        }
    }

    private var selectedBrowserName: String {
        availableBrowsers.first {
            $0.bundleIdentifier == draft.browserBundleIdentifier
        }?.name ?? "selected browser"
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        provider.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier,
            options: nil
        ) { item, _ in
            let url = droppedURL(from: item)

            Task { @MainActor in
                guard
                    let url,
                    url.pathExtension == "app",
                    let bundle = Bundle(url: url),
                    let bundleIdentifier = bundle.bundleIdentifier
                else {
                    errorMessage = "Drop a valid .app bundle."
                    return
                }

                let name = bundle.object(
                    forInfoDictionaryKey: "CFBundleDisplayName"
                ) as? String
                    ?? bundle.object(
                        forInfoDictionaryKey: "CFBundleName"
                    ) as? String
                    ?? url.deletingPathExtension().lastPathComponent

                applySourceApplication(
                    SourceApplication(
                        bundleIdentifier: bundleIdentifier,
                        name: name,
                        processIdentifier: 0
                    )
                )
                errorMessage = nil
            }
        }

        return true
    }

    private func droppedURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string)
        }

        return nil
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

private struct SourceAppChoice: Identifiable, Equatable {
    let application: SourceApplication
    let subtitle: String
    let applicationURL: URL?

    var id: String {
        application.bundleIdentifier
    }
}

private struct SourceAppPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let recentApplications: [SourceAppChoice]
    let installedApplications: [SourceAppChoice]
    let onSelect: (SourceApplication) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Search apps", text: $searchText)

                if !filteredRecentApplications.isEmpty {
                    Section("Recently Detected") {
                        ForEach(filteredRecentApplications) { choice in
                            sourceButton(choice)
                        }
                    }
                }

                Section("Installed Apps") {
                    ForEach(filteredInstalledApplications) { choice in
                        sourceButton(choice)
                    }
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
            }
            .padding()
        }
        .frame(width: 620, height: 620)
    }

    private var filteredRecentApplications: [SourceAppChoice] {
        filtered(recentApplications)
    }

    private var filteredInstalledApplications: [SourceAppChoice] {
        filtered(installedApplications)
    }

    private func filtered(_ choices: [SourceAppChoice]) -> [SourceAppChoice] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            return choices
        }

        return choices.filter {
            $0.application.name.localizedCaseInsensitiveContains(query)
                || $0.application.bundleIdentifier
                    .localizedCaseInsensitiveContains(query)
        }
    }

    private func sourceButton(_ choice: SourceAppChoice) -> some View {
        Button {
            onSelect(choice.application)
        } label: {
            HStack(spacing: 10) {
                AppIconView(applicationURL: choice.applicationURL)

                VStack(alignment: .leading) {
                    Text(choice.application.name)
                    Text(choice.application.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(choice.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AppIconView: View {
    let applicationURL: URL?

    var body: some View {
        if let applicationURL {
            Image(
                nsImage: NSWorkspace.shared.icon(
                    forFile: applicationURL.path
                )
            )
            .resizable()
            .frame(width: 28, height: 28)
        } else {
            Image(systemName: "app.dashed")
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }
}

private struct InstalledApplicationScanner {
    static func scanApplications() -> [SourceAppChoice] {
        let fileManager = FileManager.default
        let directories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]

        var choicesByBundleIdentifier: [String: SourceAppChoice] = [:]

        for directory in directories {
            guard
                let urls = try? fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil
                )
            else {
                continue
            }

            for url in urls where url.pathExtension == "app" {
                guard
                    let bundle = Bundle(url: url),
                    let bundleIdentifier = bundle.bundleIdentifier
                else {
                    continue
                }

                let name = bundle.object(
                    forInfoDictionaryKey: "CFBundleDisplayName"
                ) as? String
                    ?? bundle.object(
                        forInfoDictionaryKey: "CFBundleName"
                    ) as? String
                    ?? url.deletingPathExtension().lastPathComponent

                choicesByBundleIdentifier[bundleIdentifier] =
                    SourceAppChoice(
                        application: SourceApplication(
                            bundleIdentifier: bundleIdentifier,
                            name: name,
                            processIdentifier: 0
                        ),
                        subtitle: url.path,
                        applicationURL: url
                    )
            }
        }

        return choicesByBundleIdentifier.values.sorted {
            $0.application.name.localizedCaseInsensitiveCompare(
                $1.application.name
            ) == .orderedAscending
        }
    }
}
