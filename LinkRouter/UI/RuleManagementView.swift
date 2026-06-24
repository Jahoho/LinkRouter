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
                Button(t("View Recent Routing History", "查看最近路由历史")) {
                    showsRoutingHistory = true
                }
                .disabled(appState.recentRoutingHistory.isEmpty)

                Text(t("\(appState.recentRoutingHistory.count) recent", "最近 \(appState.recentRoutingHistory.count) 条"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appState.recentSourceApplications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Recent source apps", "最近来源 App"))
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
                                    "\(ruleConditionSummary(rule)) -> \(browserSummary(rule))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!appState.canEditConfiguration)

                        Spacer()

                        Text(
                            t(
                                "Match order \(rule.priority)",
                                "匹配顺序 \(rule.priority)"
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(t("Edit", "编辑")) {
                            editorContext = RuleEditorContext(
                                mode: .edit,
                                draft: RoutingRuleDraft(rule: rule)
                            )
                        }
                        .disabled(!appState.canEditConfiguration)

                        Button(t("Delete", "删除"), role: .destructive) {
                            rulePendingDeletion = rule
                        }
                        .disabled(!appState.canEditConfiguration)
                    }

                    let warnings = RuleHealthChecker.warnings(
                        for: rule,
                        availableBrowsers: appState.availableBrowsers,
                        availableBrowserProfiles:
                            appState.availableBrowserProfiles
                    )

                    ForEach(warnings) { warning in
                        RuleHealthWarningView(warning: warning)
                    }
                }
            }

            if appState.routingConfiguration.rules.isEmpty {
                Text(t("No source-app rules are configured.", "还没有配置来源 App 规则。"))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Picker(
                    t("Fallback browser", "兜底浏览器"),
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
                            t(
                                "\(appState.routingConfiguration.defaultBrowserName) (Unavailable)",
                                "\(appState.routingConfiguration.defaultBrowserName)（不可用）"
                            )
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

                Button(t("Add Rule", "添加规则")) {
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
                title: editorTitle(for: context),
                draft: context.draft,
                availableBrowsers: appState.availableBrowsers,
                availableBrowserProfiles:
                    appState.availableBrowserProfiles,
                recentSourceApplications:
                    appState.recentSourceApplications,
                language: appState.language
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
                canCreateRule: defaultBrowserForNewRule != nil,
                language: appState.language
            ) { sourceApplication in
                showsRoutingHistory = false
                openEditor(for: sourceApplication)
            }
        }
        .confirmationDialog(
            t("Delete this rule?", "删除这条规则？"),
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
            Button(t("Delete \(rule.name)", "删除 \(rule.name)"), role: .destructive) {
                _ = appState.deleteRule(id: rule.id)
                rulePendingDeletion = nil
            }
        } message: { rule in
            Text(
                t(
                    "Links from this source will use another matching rule or the fallback browser.",
                    "来自这个来源的链接会使用其他匹配规则或兜底浏览器。"
                )
            )
        }
    }

    private func editorTitle(for context: RuleEditorContext) -> String {
        switch context.mode {
        case .add:
            return t("Add Rule", "添加规则")
        case .edit:
            return t("Edit Rule", "编辑规则")
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
            ? t("No conditions", "无条件")
            : conditions.joined(separator: " + ")
    }

    private func browserSummary(_ rule: RoutingRule) -> String {
        if let browserProfileName = rule.browserProfileName {
            return "\(rule.browserName) (\(browserProfileName))"
        }

        return rule.browserName
    }

    private func actionTitle(
        for sourceApplication: SourceApplication
    ) -> String {
        existingRule(for: sourceApplication) == nil
            ? t("Create Rule from This App", "从此 App 创建规则")
            : t("Edit Rule for This App", "编辑此 App 的规则")
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

    private func t(_ english: String, _ chinese: String) -> String {
        appState.text(english, chinese)
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
    let language: AppLanguage
    let onOpenRule: (SourceApplication) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if history.isEmpty {
                    Text(t("No routing history yet.", "还没有路由历史。"))
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
                                Button(t("Create or Edit Rule", "创建或编辑规则")) {
                                    onOpenRule(sourceApplication)
                                }
                                .disabled(
                                    !canEditConfiguration
                                        || !canCreateRule
                                )
                            } else {
                                Text(t("No source app detected", "未检测到来源 App"))
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

                Button(t("Close", "关闭")) {
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

    private func t(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }
}

private struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let availableBrowsers: [Browser]
    let availableBrowserProfiles: [BrowserProfile]
    let recentSourceApplications: [RecentSourceApplication]
    let language: AppLanguage
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
        availableBrowserProfiles: [BrowserProfile],
        recentSourceApplications: [RecentSourceApplication],
        language: AppLanguage,
        onSave: @escaping
            (RoutingRule) -> Result<Void, ConfigurationEditingError>
    ) {
        self.title = title
        self.availableBrowsers = availableBrowsers
        self.availableBrowserProfiles = availableBrowserProfiles
        self.recentSourceApplications = recentSourceApplications
        self.language = language
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField(t("Rule name", "规则名称"), text: $draft.name)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(sourceSummary)
                            Text(sourceDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(t("Choose Source App", "选择来源 App")) {
                            showsSourcePicker = true
                        }
                    }

                    Text(t("Drop a .app here to fill the source automatically.", "把 .app 拖到这里可自动填充来源。"))
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

                DisclosureGroup(t("Advanced source fields", "高级来源字段")) {
                    TextField(
                        t("Source app name", "来源 App 名称"),
                        text: $draft.sourceAppName
                    )
                    TextField(
                        t("Source bundle identifier", "来源 Bundle identifier"),
                        text: $draft.sourceAppBundleIdentifier
                    )
                }

                TextField(t("Domain pattern", "域名规则"), text: $draft.hostPattern)
                TextField(t("URL scheme", "URL scheme"), text: $draft.urlScheme)

                Picker(
                    t("Destination browser", "目标浏览器"),
                    selection: Binding(
                        get: { draft.browserBundleIdentifier },
                        set: { bundleIdentifier in
                            draft.browserBundleIdentifier = bundleIdentifier
                            clearProfileIfNeeded()
                        }
                    )
                ) {
                    if !availableBrowsers.contains(where: {
                        $0.bundleIdentifier
                            == draft.browserBundleIdentifier
                    }) {
                        Text(t("Current browser (Unavailable)", "当前浏览器（不可用）"))
                            .tag(draft.browserBundleIdentifier)
                    }

                    ForEach(availableBrowsers) { browser in
                        Text(browser.name)
                            .tag(browser.bundleIdentifier)
                    }
                }

                if !profilesForSelectedBrowser.isEmpty {
                    Picker(
                        t("Browser profile", "浏览器 Profile"),
                        selection: Binding(
                            get: { draft.browserProfileDirectory },
                            set: { profileDirectory in
                                draft.browserProfileDirectory =
                                    profileDirectory
                                draft.browserProfileName =
                                    profilesForSelectedBrowser.first {
                                        $0.profileDirectory
                                            == profileDirectory
                                    }?.profileName ?? ""
                            }
                        )
                    ) {
                        Text(t("No specific profile", "不指定 Profile"))
                            .tag("")

                        ForEach(profilesForSelectedBrowser) { profile in
                            Text(profile.profileName)
                                .tag(profile.profileDirectory)
                        }
                    }

                    Text(
                        t(
                            "Profile routing currently supports Chromium-based browsers detected from local profile metadata.",
                            "Profile 路由目前支持从本地 profile 元数据中识别出的 Chromium 系浏览器。"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Menu(t("Quick Templates", "快速模板")) {
                    ForEach(availableBrowsers) { browser in
                        Button(t("Always open in \(browser.name)", "始终用 \(browser.name) 打开")) {
                            applyBrowserTemplate(browser)
                        }
                    }
                }
                .disabled(availableBrowsers.isEmpty)

                Stepper(
                    t(
                        "Match order: \(draft.priority)",
                        "匹配顺序：\(draft.priority)"
                    ),
                    value: $draft.priority,
                    in: 0...1000
                )
                Text(
                    t(
                        "When multiple rules match, higher numbers are checked first.",
                        "当多条规则都匹配时，数字越大越先检查。"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Toggle(t("Enabled", "启用"), isOn: $draft.enabled)
                Toggle(
                    t("Open without activating browser", "后台打开浏览器"),
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

                Button(t("Cancel", "取消")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(t("Save", "保存")) {
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
                installedApplications: installedApplications,
                language: language
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

        return t("No source app selected", "未选择来源 App")
    }

    private var sourceDetail: String {
        if draft.sourceAppBundleIdentifier.isEmpty {
            return t(
                "Use the picker, recent history, or drag a .app bundle.",
                "可使用选择器、最近历史，或拖入 .app。"
            )
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
        clearProfileIfNeeded()

        if !draft.sourceAppName.isEmpty {
            draft.name = "\(draft.sourceAppName) to \(browser.name)"
        } else if !draft.hostPattern.isEmpty {
            draft.name = "\(draft.hostPattern) to \(browser.name)"
        }
    }

    private var selectedBrowserName: String {
        availableBrowsers.first {
            $0.bundleIdentifier == draft.browserBundleIdentifier
        }?.name ?? t("selected browser", "选中的浏览器")
    }

    private var profilesForSelectedBrowser: [BrowserProfile] {
        availableBrowserProfiles.filter {
            $0.browserBundleIdentifier.caseInsensitiveCompare(
                draft.browserBundleIdentifier
            ) == .orderedSame
        }
    }

    private func clearProfileIfNeeded() {
        if profilesForSelectedBrowser.contains(where: {
            $0.profileDirectory == draft.browserProfileDirectory
        }) {
            return
        }

        draft.browserProfileName = ""
        draft.browserProfileDirectory = ""
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
                    errorMessage = t(
                        "Drop a valid .app bundle.",
                        "请拖入有效的 .app。"
                    )
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
                availableBrowsers: availableBrowsers,
                availableBrowserProfiles: availableBrowserProfiles
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

    private func t(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
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
    let language: AppLanguage
    let onSelect: (SourceApplication) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField(t("Search apps", "搜索 App"), text: $searchText)

                if !filteredRecentApplications.isEmpty {
                    Section(t("Recently Detected", "最近检测到")) {
                        ForEach(filteredRecentApplications) { choice in
                            sourceButton(choice)
                        }
                    }
                }

                Section(t("Installed Apps", "已安装 App")) {
                    ForEach(filteredInstalledApplications) { choice in
                        sourceButton(choice)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()

                Button(t("Cancel", "取消")) {
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

    private func t(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
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
