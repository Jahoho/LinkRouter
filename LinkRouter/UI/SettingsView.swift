import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showsSetupHealth = false
    @State private var showsResetConfirmation = false
    @State private var showsOnboarding = false

    var body: some View {
        TabView {
            overviewTab
                .tabItem {
                    Label(t("Overview", "概览"), systemImage: "switch.2")
                }

            rulesTab
                .tabItem {
                    Label(t("Rules", "规则"), systemImage: "list.bullet")
                }

            diagnosticsTab
                .tabItem {
                    Label(t("Diagnostics", "诊断"), systemImage: "waveform.path.ecg")
                }

            advancedTab
                .tabItem {
                    Label(t("Advanced", "高级"), systemImage: "gearshape")
                }
        }
        .sheet(isPresented: $showsSetupHealth) {
            SetupHealthView(
                items: appState.setupHealthItems,
                language: appState.language
            )
        }
        .sheet(isPresented: $showsOnboarding) {
            OnboardingView(
                language: appState.language,
                defaultBrowserStatus:
                    appState.localized(appState.defaultBrowserStatus),
                isDefaultBrowser:
                    appState.defaultBrowserStatus.isLinkRouterDefault,
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
            t("Reset routing configuration?", "重置路由配置？"),
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(t("Reset to Defaults", "恢复默认配置"), role: .destructive) {
                _ = appState.resetConfiguration()
            }
        } message: {
            Text(
                t(
                    "This replaces the current rules with the seed rules. Export first if you want a backup.",
                    "这会用默认规则替换当前规则。如果想保留备份，请先导出配置。"
                )
            )
        }
        .frame(width: 760, height: 620)
        .navigationTitle(t("LinkRouter Settings", "LinkRouter 设置"))
        .onAppear {
            if appState.shouldShowOnboarding {
                showsOnboarding = true
            }
        }
    }

    private var overviewTab: some View {
        Form {
            Section(t("Status", "状态")) {
                LabeledContent(
                    t("URL listener", "链接监听"),
                    value: t("Active", "运行中")
                )
                LabeledContent(
                    t("Default web browser", "默认网页浏览器"),
                    value: appState.localized(
                        appState.defaultBrowserStatus
                    ).title
                )
                Text(appState.localized(appState.defaultBrowserStatus).detail)
                    .font(.caption)
                    .foregroundStyle(
                        appState.defaultBrowserStatus.isLinkRouterDefault
                            ? Color.secondary
                            : Color.orange
                    )
                LabeledContent(
                    t("Links received", "已接收链接"),
                    value: String(appState.receivedRequestCount)
                )

                HStack {
                    Button(t("Setup Guide", "设置引导")) {
                        showsOnboarding = true
                    }

                    Button(t("Setup Health", "设置健康检查")) {
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
                    Text(
                        t(
                            "Setup guide has not been completed yet.",
                            "设置引导尚未完成。"
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section(t("Language", "语言")) {
                Picker(
                    t("Interface language", "界面语言"),
                    selection: Binding(
                        get: { appState.language },
                        set: { appState.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(t("Startup", "启动")) {
                Toggle(
                    t("Launch at login", "登录时启动"),
                    isOn: Binding(
                        get: { appState.launchAtLoginStatus.isEnabled },
                        set: { isEnabled in
                            appState.setLaunchAtLoginEnabled(isEnabled)
                        }
                    )
                )

                LabeledContent(
                    t("Status", "状态"),
                    value: appState.launchAtLoginStatus.title(
                        language: appState.language
                    )
                )

                Text(
                    appState.launchAtLoginStatus.detail(
                        language: appState.language
                    )
                )
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

            Section(t("Installed browsers", "已安装浏览器")) {
                browserList

                HStack {
                    Button(t("Refresh Browser List", "刷新浏览器列表")) {
                        appState.refreshBrowsers()
                    }

                    if let browserLaunchStatus = appState.browserLaunchStatus {
                        Text(browserLaunchStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 6)
    }

    private var rulesTab: some View {
        Form {
            Section(t("Routing rules", "路由规则")) {
                RuleManagementView()
            }
        }
        .formStyle(.grouped)
        .padding(.top, 6)
    }

    private var diagnosticsTab: some View {
        Form {
            Section(t("Last received link", "最近收到的链接")) {
                if let lastRequest = appState.lastRequest {
                    LabeledContent(t("Sanitized URL", "脱敏 URL")) {
                        Text(lastRequest.sanitizedDescription)
                            .textSelection(.enabled)
                    }

                    LabeledContent(t("Received at", "接收时间")) {
                        Text(lastRequest.receivedAt, format: .dateTime)
                    }

                    LabeledContent(
                        t("Source app", "来源 App"),
                        value: lastRequest.source.application?.name
                            ?? t("Unknown", "未知")
                    )

                    LabeledContent(
                        t("Bundle identifier", "Bundle identifier"),
                        value: lastRequest.source.application?.bundleIdentifier
                            ?? t("Unknown", "未知")
                    )

                    LabeledContent(
                        t("Detection method", "识别方式"),
                        value: lastRequest.source.method.rawValue
                    )

                    LabeledContent(
                        t("Confidence", "置信度"),
                        value: lastRequest.source.confidence.rawValue
                    )

                    LabeledContent(t("Detection note", "识别说明")) {
                        Text(lastRequest.source.reason)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(
                        t(
                            "Open a web link after selecting LinkRouter as the default browser.",
                            "将 LinkRouter 设为默认浏览器后，打开一个网页链接即可在这里看到诊断。"
                        )
                    )
                        .foregroundStyle(.secondary)
                }
            }

            Section(t("Last routing result", "最近路由结果")) {
                routingResultView
            }

            Section(t("Source compatibility", "来源兼容性")) {
                sourceCompatibilityView
            }
        }
        .formStyle(.grouped)
        .padding(.top, 6)
    }

    private var advancedTab: some View {
        Form {
            Section(t("Configuration storage", "配置存储")) {
                LabeledContent(
                    t("Status", "状态"),
                    value: appState.localized(appState.configurationStatus).title
                )

                LabeledContent(
                    t("Schema version", "Schema 版本"),
                    value: String(
                        appState.routingConfiguration.schemaVersion
                    )
                )

                LabeledContent(t("File", "文件")) {
                    Text(appState.configurationFileURL.path)
                        .textSelection(.enabled)
                }

                Text(appState.localized(appState.configurationStatus).detail)
                    .foregroundStyle(
                        appState.configurationStatus.isUsingInMemoryFallback
                            ? Color.red
                            : Color.secondary
                    )

                HStack {
                    Button(t("Export Configuration", "导出配置")) {
                        exportConfiguration()
                    }
                    .disabled(!appState.canEditConfiguration)

                    Button(t("Import Configuration", "导入配置")) {
                        importConfiguration()
                    }
                    .disabled(!appState.canEditConfiguration)

                    Button(t("Reset to Defaults", "恢复默认配置"), role: .destructive) {
                        showsResetConfirmation = true
                    }
                    .disabled(!appState.canEditConfiguration)
                }
            }

            Section(t("Privacy", "隐私")) {
                Text(
                    t(
                        "LinkRouter currently logs only the URL scheme and host. Paths, queries, fragments, and credentials are removed.",
                        "LinkRouter 默认只记录 URL scheme 和 host。路径、查询参数、fragment 和凭据都会被移除。"
                    )
                )
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 6)
    }

    private var browserList: some View {
        Group {
            if appState.availableBrowsers.isEmpty {
                Text(
                    t(
                        "No HTTPS-capable browser was found.",
                        "没有找到可打开 HTTPS 的浏览器。"
                    )
                )
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

                        Button(t("Open Test Page", "打开测试页")) {
                            appState.openTestPage(in: browser)
                        }
                        .disabled(appState.isLaunchingBrowser)
                    }
                }
            }
        }
    }

    private var routingResultView: some View {
        Group {
            if let result = appState.lastRoutingResult {
                LabeledContent(
                    t("Status", "状态"),
                    value: result.succeeded
                        ? t("Succeeded", "成功")
                        : t("Failed", "失败")
                )

                LabeledContent(
                    t("Matched rule", "命中规则"),
                    value: result.decision.matchedRule?.name
                        ?? t("Fallback", "兜底")
                )

                LabeledContent(
                    t("Selected browser", "选择的浏览器"),
                    value: result.decision.browserName
                )

                LabeledContent(
                    t("Final browser", "最终浏览器"),
                    value: result.finalBrowserName ?? t("None", "无")
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
                    Text(t("Why this happened", "为什么这样路由"))
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
                Text(
                    t(
                        "No routing decision has been completed yet.",
                        "还没有完成过路由决策。"
                    )
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private var sourceCompatibilityView: some View {
        Group {
            if appState.recentRoutingHistory.isEmpty {
                Text(
                    t(
                        "Open links from real apps to build a lightweight compatibility report.",
                        "从真实 App 打开链接后，这里会生成轻量兼容性报告。"
                    )
                )
                .foregroundStyle(.secondary)
            } else {
                DisclosureGroup(
                    t(
                        "\(appState.sourceCompatibilityReports.count) apps, \(appState.unknownSourceHistoryCount) unknown samples",
                        "\(appState.sourceCompatibilityReports.count) 个 App，\(appState.unknownSourceHistoryCount) 条未知样本"
                    )
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if appState.sourceCompatibilityReports.isEmpty {
                            Text(
                                t(
                                    "Recent links did not include a usable source app yet.",
                                    "最近链接还没有可用的来源 App。"
                                )
                            )
                            .foregroundStyle(.secondary)
                        } else {
                            ForEach(appState.sourceCompatibilityReports) {
                                report in
                                SourceCompatibilityRow(
                                    report: report,
                                    language: appState.language
                                )
                            }
                        }

                        if appState.unknownSourceHistoryCount > 0 {
                            Text(
                                t(
                                    "Unknown samples use the fallback browser and are useful for testing source detection gaps.",
                                    "未知样本会使用兜底浏览器，也能帮助判断来源识别缺口。"
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding(.top, 4)
                }

                Text(
                    t(
                        "This report is derived from the last 20 sanitized routing results and is not stored as permanent history.",
                        "此报告来自最近 20 条脱敏路由结果，不作为永久历史保存。"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        appState.text(english, chinese)
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

    let language: AppLanguage
    let defaultBrowserStatus: (title: String, detail: String)
    let isDefaultBrowser: Bool
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
                        Text(t("Set Up LinkRouter", "设置 LinkRouter"))
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(
                            t(
                                "LinkRouter stays small by doing one job locally: receive web links, apply your rules, and forward them to the right browser.",
                                "LinkRouter 保持轻量，只做一件事：接收网页链接，应用你的规则，再转发到正确的浏览器。"
                            )
                        )
                            .foregroundStyle(.secondary)
                    }
                }

                onboardingStep(
                    title: t(
                        "1. Keep LinkRouter running",
                        "1. 保持 LinkRouter 运行"
                    ),
                    detail: t(
                        "It lives in the menu bar. If the app quits, macOS will no longer deliver links to it.",
                        "它会常驻菜单栏。如果 App 退出，macOS 就不会再把链接交给它。"
                    )
                )

                onboardingStep(
                    title: t(
                        "2. Make it the default browser",
                        "2. 设为默认浏览器"
                    ),
                    detail:
                        isDefaultBrowser
                            ? t(
                                "Done. New web links should reach LinkRouter first.",
                                "已完成。新的网页链接会先到达 LinkRouter。"
                            )
                            : t(
                                "Open System Settings and set Default web browser to LinkRouter, then refresh this status.",
                                "打开系统设置，把默认网页浏览器设为 LinkRouter，然后刷新这里的状态。"
                            )
                ) {
                    HStack {
                        Text(defaultBrowserStatus.title)
                            .font(.caption)
                            .foregroundStyle(
                                isDefaultBrowser
                                    ? Color.secondary
                                    : Color.orange
                            )

                        Button(t("Refresh Status", "刷新状态")) {
                            onRefreshDefaultBrowser()
                        }
                    }
                }

                onboardingStep(
                    title: t(
                        "3. Verify browsers and fallback",
                        "3. 验证浏览器和兜底浏览器"
                    ),
                    detail:
                        t(
                            "Settings lists installed browsers and can open a test page. If no rule matches, LinkRouter uses \(fallbackBrowserName).",
                            "设置中会列出已安装浏览器，也可以打开测试页。如果没有规则命中，LinkRouter 会使用 \(fallbackBrowserName)。"
                        )
                )

                onboardingStep(
                    title: t(
                        "4. Create rules from real app clicks",
                        "4. 从真实 App 点击创建规则"
                    ),
                    detail:
                        t(
                            "Open a test link from Mail, Codex, WeChat, or another app, then create a rule from Recent source apps or Recent routing history.",
                            "从 Mail、Codex、微信或其他 App 打开一次测试链接，然后从最近来源 App 或路由历史中创建规则。"
                        )
                )

                onboardingStep(
                    title: t(
                        "5. Privacy and backups",
                        "5. 隐私和备份"
                    ),
                    detail:
                        t(
                            "Diagnostics show sanitized hosts by default. Rules are stored as local JSON at \(configurationPath). Export before major changes.",
                            "诊断默认只显示脱敏后的 host。规则以本地 JSON 存储在 \(configurationPath)。大改规则前建议先导出备份。"
                        )
                )

                Button(t("Open Setup Health", "打开设置健康检查")) {
                    onOpenSetupHealth()
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(t("Show Later", "稍后再看")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(t("Mark Setup Complete", "标记设置完成")) {
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

    private func t(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }
}

private struct SetupHealthView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [SetupHealthItem]
    let language: AppLanguage

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
                            Text(item.level.title(language: language))
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

                Button(language.text("Close", "关闭")) {
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

private struct SourceCompatibilityRow: View {
    let report: SourceCompatibilityReport
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: iconName)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(report.appName)
                        .font(.headline)

                    Spacer()

                    Text(report.status.title(language: language))
                        .font(.caption)
                        .foregroundStyle(color)
                }

                Text(report.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(
                    language.text(
                        "\(report.sampleCount) samples; confidence: \(report.confidenceSummary)",
                        "\(report.sampleCount) 条样本；置信度：\(report.confidenceSummary)"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    language.text(
                        "Methods: \(methodSummary)",
                        "识别方式：\(methodSummary)"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var methodSummary: String {
        report.detectionMethods
            .map(\.rawValue)
            .joined(separator: ", ")
    }

    private var iconName: String {
        switch report.status {
        case .reliable:
            return "checkmark.circle.fill"
        case .needsMoreSamples:
            return "questionmark.circle.fill"
        case .unstable:
            return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch report.status {
        case .reliable:
            return .green
        case .needsMoreSamples:
            return .orange
        case .unstable:
            return .red
        }
    }
}
