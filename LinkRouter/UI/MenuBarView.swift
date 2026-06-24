import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("URL listener is active", "链接监听已启用"), systemImage: "checkmark.circle")

            if let lastRequest = appState.lastRequest {
                Text(t("Last link: \(lastRequest.sanitizedDescription)", "最近链接：\(lastRequest.sanitizedDescription)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    t(
                        "Source: \(lastRequest.source.application?.name ?? "Unknown") (\(lastRequest.source.confidence.rawValue))",
                        "来源：\(lastRequest.source.application?.name ?? "未知") (\(lastRequest.source.confidence.rawValue))"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(t("No links received yet", "还没有收到链接"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(t("Browsers found: \(appState.availableBrowsers.count)", "已发现浏览器：\(appState.availableBrowsers.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.localized(appState.defaultBrowserStatus).title)
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
                Button(t("Resume Routing", "恢复路由")) {
                    appState.resumeRouting()
                }
            } else {
                Button(t("Pause Routing for 10 Minutes", "暂停路由 10 分钟")) {
                    appState.pauseRoutingForTenMinutes()
                }
            }

            if appState.nextLinkBrowserOverride != nil {
                Button(t("Clear Next-Link Override", "清除下一次链接指定")) {
                    appState.clearNextLinkOverride()
                }
            }

            Menu(t("Open Next Link With", "下一次链接打开方式")) {
                ForEach(appState.availableBrowsers) { browser in
                    Button(browser.name) {
                        appState.openNextLink(in: browser)
                    }
                }
            }
            .disabled(appState.availableBrowsers.isEmpty)

            Divider()

            SettingsLink {
                Label(t("Settings", "设置"), systemImage: "gear")
            }

            Button {
                appState.resetOnboarding()
                NSApp.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
            } label: {
                Label(t("Setup Guide", "设置引导"), systemImage: "checklist")
            }

            Button(t("Quit LinkRouter", "退出 LinkRouter")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(minWidth: 260)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        appState.text(english, chinese)
    }
}
