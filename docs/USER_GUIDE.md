# LinkRouter 使用与验收指南

本文档适用于当前开发版 LinkRouter。它是菜单栏 App，没有 Dock 图标，
目前主要通过 Xcode 启动，也可以在 Settings 中开启登录后自动启动。

## 一、现在先完成这些检查

按顺序完成，不要一开始就添加很多新规则。

### 0. 首次设置引导

第一次启动时，LinkRouter 会尝试打开 Settings 并显示 `Set Up LinkRouter`
引导。

建议按引导顺序完成：

1. 确认 LinkRouter 正在菜单栏运行。
2. 将 LinkRouter 设置为默认浏览器。
3. 刷新默认浏览器状态。
4. 打开测试页确认浏览器能被指定启动。
5. 从真实 App 点击链接，再从最近来源或历史创建规则。
6. 了解配置文件位置，并在大改规则前导出备份。

如果以后还想重新查看引导，可以点击菜单栏 LinkRouter 图标里的
`Setup Guide`。

### 1. 启动 LinkRouter

开发调试时：

1. 用 Xcode 打开 `LinkRouter.xcodeproj`。
2. 顶部 Scheme 选择 `LinkRouter`。
3. 运行目标选择 `My Mac`。
4. 按 `Command + R`。
5. 查看屏幕顶部菜单栏，找到 LinkRouter 的分流箭头图标。

预期结果：

- Xcode 没有出现红色编译错误。
- 菜单栏出现 LinkRouter 图标。
- 点击图标后显示 `URL listener is active`。
- App 必须保持运行；停止 Xcode 或退出 LinkRouter 后，链接不会再被接管。

独立日常使用时：

1. 在项目目录运行：

```sh
scripts/build_release_app.sh
```

2. 脚本会输出一个 Release 版 `LinkRouter.app` 路径。
3. 把这个 `LinkRouter.app` 放到 `/Applications`。
4. 以后从 `/Applications/LinkRouter.app` 打开，不需要再从 Xcode 运行。
5. 第一次换成独立 App 后，需要重新在系统设置里选择默认浏览器为
   `/Applications` 里的 LinkRouter。

注意：Xcode 仍然是“构建工具”，但日常使用不需要 Xcode。每次你改代码并想用新版，
都需要重新 build 一次并替换 `/Applications/LinkRouter.app`。

### 2. 打开设置窗口

1. 点击菜单栏中的 LinkRouter 图标。
2. 点击 `Settings`。

设置窗口现在分为四个区域：

- `Overview` / `概览`：默认浏览器、语言、启动项、浏览器测试。
- `Rules` / `规则`：路由规则、fallback browser、最近来源 App。
- `Diagnostics` / `诊断`：最近收到的链接、最近路由结果。
- `Default Apps` / `默认 App`：常见文件类型的默认打开 App。
- `Advanced` / `高级`：配置文件、导入导出、隐私说明。

在 `Overview` 的 `Language` 中可以切换 English / 中文。这个设置会保存，
下次启动仍然生效。

先检查：

- `URL listener` 显示 `Active`。
- `Default web browser` 显示 `LinkRouter is default`。如果还显示
  Safari、Chrome 或 `Unable to determine`，先完成本文第 4 步。
- `Installed browsers` 至少显示 Safari。
- 当前电脑还应显示 Google Chrome。
- `Configuration storage` 状态显示 `Loaded from disk`、
  `Created default configuration` 或 `Saved to disk`。
- 如果状态为红色的 `Using in-memory fallback`，先不要修改规则，
  参见本文“配置损坏”部分。
- 点击 `View Setup Health` 可以查看完整健康检查，包括默认浏览器、
  fallback 浏览器、配置文件、来源检测、路由历史和登录启动状态。

在 `Startup` 区域：

- 打开 `Launch at login` 可以让 LinkRouter 登录后自动启动。
- 如果状态显示 `Requires approval`，按提示去 System Settings 里批准。

### 3. 测试浏览器能否被指定打开

在 `Installed browsers` 区域：

1. 点击 Safari 右侧的 `Open Test Page`。
2. 确认 Safari 打开 `https://example.com`。
3. 返回设置窗口。
4. 点击 Google Chrome 右侧的 `Open Test Page`。
5. 确认 Chrome 打开同一测试页。

预期结果：

- 状态文字显示 `Opened test page in Safari/Google Chrome`。
- 点击 Safari 时不能错误地打开 Chrome，反之亦然。
- 如果某个浏览器无法打开，先点击 `Refresh Browser List` 再重试。

### 4. 将 LinkRouter 设为默认浏览器

LinkRouter 必须成为系统默认浏览器，才能接收其他 App 的普通网页链接。

在 macOS 26 中：

1. 打开 `System Settings`（系统设置）。
2. 在左上方搜索框输入 `default web browser` 或 `默认网页浏览器`。
3. 打开对应设置项。
4. 将默认网页浏览器选择为 `LinkRouter`。
5. 如果系统弹出确认对话框，确认更改。

部分 macOS 版本也可以直接在：

`System Settings` → `Desktop & Dock` → `Default web browser`

找到该选项。系统设置的分组可能随 macOS 小版本调整，以搜索结果为准。

如果列表里没有 LinkRouter：

1. 确认 LinkRouter 正在通过 Xcode 运行。
2. 确认 Xcode 的 `TARGETS -> LinkRouter -> Signing & Capabilities`
   已选择 `Personal Team`，而不是只使用 `Sign to Run Locally`。
3. 退出并重新打开 System Settings。
4. 再次搜索默认网页浏览器。
5. 必要时停止并重新运行一次 LinkRouter。

如果仍然没有出现，先在 Terminal 检查当前构建是否真的有开发者签名：

```sh
codesign -dvvv ~/Library/Developer/Xcode/DerivedData/LinkRouter-*/Build/Products/Debug/LinkRouter.app 2>&1 | grep TeamIdentifier
security find-identity -v -p codesigning
```

预期结果：

- `TeamIdentifier` 不是 `not set`。
- `security find-identity` 至少显示 1 个有效签名身份。

如果看到 `Signature=adhoc`、`TeamIdentifier=not set` 或
`0 valid identities found`，说明 App 只是“可以本机运行”，但还不是
macOS 26 接受的可信浏览器候选。回到 Xcode 登录 Apple ID，选择
`Personal Team` 后重新运行。

回到 LinkRouter Settings 后，点击 `Refresh Default Browser Status`。
预期 `Default web browser` 显示 `LinkRouter is default`。

## 二、检查默认规则

打开 LinkRouter Settings，找到 `Routing rules`。

当前默认规则应该是：

| 来源 App | Bundle identifier | 目标浏览器 | 匹配顺序 |
|---|---|---|---:|
| Codex | `com.openai.codex` | Google Chrome | 100 |
| WeChat | `com.tencent.xinWeChat` | Safari | 90 |
| Mail | `com.apple.mail` | Safari | 80 |

`Fallback browser` 应为 Safari。

规则含义：

- Toggle 打开：规则启用。
- Toggle 关闭：规则保留，但暂时不参与匹配。
- 规则列表可以先选中一条规则，再用 `上移` / `下移` 调整检查顺序；也可以把规则拖到另一条规则上方。只有多条规则都可能命中时，检查顺序才重要。
- 规则可以只按 App、只按 Domain，或按 App + Domain 组合匹配。
- 如果目标浏览器有检测到的 Chromium Profile，可以在规则编辑器中选择
  `Browser profile`，用于区分 Work / Personal 等浏览器上下文。
- 多个条件会同时生效，例如 `Mail + *.github.com` 只匹配 Mail 里打开的
  GitHub 链接。
- 没有规则匹配，或来源识别为 Unknown 时，使用 fallback browser。
- 修改 Toggle 或 fallback 后会立即保存。
- Add/Edit 只有点击 `Save` 后才会保存。
- 如果规则名称旁边出现橙色警告图标，展开 `详情` 查看原因。通常是目标浏览器不存在、
  目标误指向 LinkRouter，或来源 bundle identifier 格式异常。

## 三、现在执行核心验收

每次测试前确保：

- LinkRouter 正在运行。
- LinkRouter 已经是系统默认浏览器。
- 测试 URL 是普通 `http` 或 `https` 链接。

### 测试 A：Fallback

1. 打开 Terminal。
2. 运行：

```sh
open 'https://example.com/fallback-test'
```

3. 查看最终打开的浏览器。
4. 打开 LinkRouter Settings。

预期结果：

- 通常由 Safari 打开。
- `Last received link` 显示 `https://example.com`。
- Source app 可能是 Terminal，也可能是 `Unknown`，两者都可接受。
- `Last routing result` 的 `Matched rule` 为 `Fallback`。
- `Final browser` 为 Safari。
- `Why this happened` 会解释为什么没有规则命中以及最终使用哪个浏览器。

### 测试 B：Codex

1. 保持 LinkRouter 运行。
2. 在 Codex 中点击一个普通网页链接。
3. 查看是否由 Chrome 打开。
4. 立即打开 LinkRouter Settings 查看诊断。

理想结果：

- `Source app` 为 Codex。
- Bundle identifier 为 `com.openai.codex`。
- `Matched rule` 为 `Codex to Chrome`。
- `Final browser` 为 Google Chrome。
- `Why this happened` 应说明检测到 Codex、命中 Codex 规则，并最终打开 Chrome。

如果链接打开了 Safari：

- 查看 Source app 是否为 `Unknown` 或其他辅助进程。
- 记录 `Detection method`、`Confidence` 和 `Detection note`。
- 这说明来源识别没有拿到 Codex，而不是规则引擎失效。

### 测试 C：WeChat

1. 在微信中点击一个普通网页链接。
2. 确认 Safari 打开。
3. 查看 LinkRouter Settings。

理想结果：

- Bundle identifier 为 `com.tencent.xinWeChat`。
- `Matched rule` 为 `WeChat to Safari`。
- `Final browser` 为 Safari。

### 测试 D：Mail

1. 打开 Mail。
2. 打开一封包含普通网页链接的邮件。
3. 点击邮件里的 `http` 或 `https` 链接。
4. 查看 LinkRouter Settings。

理想结果：

- `Source app` 为 Mail。
- Bundle identifier 为 `com.apple.mail`。
- `Matched rule` 为 `Mail to Safari`。
- `Final browser` 为 Safari。

如果失败，先确认点击的是普通网页链接，而不是邮箱地址、附件、
App Store 链接或系统设置深链。

### 测试 E：其他 App

依次从 Telegram、Obsidian、Finder 或其他 App 打开网页链接。

如果还没有对应规则，预期使用 Safari fallback。每测一个 App，都记录：

- Source app
- Bundle identifier
- Detection method
- Confidence
- Matched rule
- Final browser

## 四、添加一条规则

### 推荐方式：从最近检测到的 App 创建

1. 先从一个或多个目标 App 打开网页链接。
2. 回到 LinkRouter Settings。
3. 在 `Routing rules` 顶部查看 `Recent source apps`。
4. 找到想配置的 App。
5. 如果这个来源还没有规则，点击 `Create Rule from This App`。
6. 如果这个来源已经有规则，点击 `Edit Rule for This App`。
7. 确认规则名称、来源 App 和目标浏览器。
8. 点击 `Save`。

这种方式不需要手动查 bundle identifier。LinkRouter 会使用最近检测到的
来源 App 自动填写，并把最近测试过的多个 App 保留在列表里。

如果看到橙色置信度提示，说明来源检测不是最高置信度。可以保存，但建议先确认
`Source app` 和 bundle identifier 确实是你想配置的 App。

### 从最近路由历史创建

1. 在 `Routing rules` 顶部点击 `View Recent Routing History`。
2. 从最近 20 条记录中找到想配置的 App。
3. 点击 `Create or Edit Rule`。
4. 如果该来源已有规则，会打开已有规则；否则会创建新规则。
5. 确认目标浏览器后点击 `Save`。

历史记录只显示脱敏 URL，例如 `https://example.com`，不会显示 path、
query、fragment 或 token。

每条历史记录还会显示简短解释，例如来源检测结果、命中的规则或 fallback、
最终浏览器，以及是否发生过 recovery fallback。这用于排查“为什么这次打开了
这个浏览器”。

### 手动方式：高级编辑

以 Telegram 为例：

1. 先从 Telegram 打开一次链接。
2. 在 `Last received link` 中查看检测到的 Bundle identifier。
3. 找到 `Routing rules`，点击 `Add Rule`。
4. 填写：
   - `Rule name`：例如 `Telegram to Chrome`
   - 点击 `Choose Source App`，从最近 App 或已安装 App 中选择 Telegram
   - 也可以把 Telegram 的 `.app` 文件拖进规则编辑器
   - `Destination browser`：选择目标浏览器
   - `Enabled`：打开
   - `Open without activating browser`：日常使用建议关闭
5. 点击 `Save`。
6. 再从 Telegram 点击一次链接验证。

注意：

- `Source app name` 只是显示名称。
- 真正匹配使用的是 `Source bundle identifier`。
- Bundle identifier 通常类似 `com.company.App`，不能包含空格。
- 不要凭 App 名称猜 bundle identifier，优先使用 LinkRouter 诊断中实际检测到的值。
- `Advanced source fields` 仍然保留给排查或手动修正使用，日常不需要打开。

### 添加域名或组合规则

创建规则时可以填写：

- `Domain pattern`：例如 `github.com` 或 `*.github.com`
- `URL scheme`：可选，通常留空；需要限制时填 `http` 或 `https`

示例：

- 只填 `Domain pattern = *.github.com`：任何 App 打开的 GitHub 链接都按这条规则走。
- 选择 `Source App = Mail`，再填 `Domain pattern = *.github.com`：只有 Mail 中打开的 GitHub 链接才按这条规则走。

如果多条规则都能匹配，列表里更靠前的规则会先被使用。`Why this happened`
会显示其他同样匹配、但检查顺序更靠后的规则。

### 使用快速模板

在规则编辑器里点击 `Quick Templates`，可以把当前规则快速改成：

```text
Always open in Safari / Chrome / Arc ...
```

这只会修改目标浏览器和规则名称，不会隐藏底层规则。

## 五、浏览器 Profile 路由

这个功能用于解决“工作链接进工作 Profile、个人链接进个人 Profile”的痛点，
是 LinkRouter 相比普通浏览器分流工具更有差异化的方向之一。

当前支持范围：

- Google Chrome
- Microsoft Edge
- Brave

这些浏览器的 Profile 信息来自本机 Chromium `Local State` 文件。Safari 和 Arc
暂不强行支持，因为没有同样稳定的无权限启动方式。

测试步骤：

1. 确认 Chrome 里至少有两个 Profile，例如 `Personal` 和 `Work`。
2. 重启 LinkRouter，或在 `Overview` 中点击 `Refresh Browser List`。
3. 打开 `Rules`，新增或编辑一条规则。
4. `Destination browser` 选择 Google Chrome。
5. 如果 LinkRouter 检测到了 Profile，会出现 `Browser profile` 下拉框。
6. 选择一个 Profile，点击 `Save`。
7. 从匹配来源 App 打开链接。

预期结果：

- 链接由 Chrome 打开。
- Chrome 使用所选 Profile。
- `Diagnostics` 的 `Final browser` 或解释文本中能看到 profile 名称。

如果没有看到 `Browser profile`：

- 先确认目标浏览器是 Chrome/Edge/Brave。
- 确认该浏览器已经创建过 Profile。
- 点击 `Refresh Browser List` 后重新打开规则编辑器。
- 如果仍然没有，说明本机没有可读的 Chromium profile metadata；这时规则仍可按普通浏览器路由。

## 六、Default Apps 文件默认打开方式

`Default Apps` 是一个轻量相邻模块，用来解决“我不知道 `.md` 对应什么 UTI，
也不知道该去哪里改默认打开 App”的问题。

当前支持：

- 文本与代码：`.md`、`.txt`、`.rtf`、`.json`、`.yaml`、`.xml`、`.swift`
- 文档：`.pdf`、`.doc`、`.docx`、`.pages`
- 表格：`.csv`、`.tsv`、`.xls`、`.xlsx`、`.numbers`
- 演示文稿：`.ppt`、`.pptx`、`.key`
- 图片：`.png`、`.jpg`、`.jpeg`、`.heic`、`.gif`、`.webp`、`.svg`
- 网页文件：`.html`、`.css`、`.js`
- 自定义：你可以在顶部输入扩展名，例如 `plist` 或 `log`，把它加入管理列表。

测试 `.md` 的建议流程：

1. 打开 Settings → `Default Apps`。
2. 找到 `.md`。
3. 查看当前默认 App。
4. 从右侧下拉选择一个候选 App，例如 Obsidian、VS Code 或 TextEdit。
5. 点击 `Refresh` 或 `Refresh All`。
6. 在 Finder 中双击一个 `.md` 文件验证。

添加自定义扩展名：

1. 在顶部输入框输入扩展名，例如 `plist`，不用加点也可以。
2. 点击 `Add`。
3. 展开 `Custom` / `自定义` 分组。
4. 从该扩展名右侧下拉选择默认 App。
5. 如果不想继续管理这个自定义类型，点击 `Remove`。这只会从 LinkRouter
   的管理列表移除，不会主动改回 macOS 的默认打开方式。

注意：

- 这里修改的是 macOS 全局默认打开方式，不是 LinkRouter 自己内部的规则。
- 这个模块和网页链接路由互不影响。
- 如果某个扩展名没有候选 App，说明 macOS 没有报告可打开该类型的应用。
- 如果不确定，先只测试 `.md`，不要一次性改多个文件类型。

## 七、修改、停用和删除规则

### 修改

1. 点击规则右侧 `Edit`。
2. 修改浏览器或名称。
3. 点击 `Save`。
4. 从对应 App 再打开一次链接验证。

### 调整检查顺序

1. 在规则列表中点击要调整的规则，让它进入选中状态。
2. 点击 `上移`，让它更早被检查。
3. 点击 `下移`，让它更晚被检查。
4. 也可以直接拖动一条规则到另一条规则上方。
5. 再从对应 App 打开链接验证。

普通用户不需要理解内部数字。规则编辑器里的 `Advanced match order`
只用于极少数需要精细调试的情况。

### 查看规则详情和警告

每条规则默认只显示最重要的信息：

- 规则名称
- 匹配条件
- 目标浏览器
- 编辑 / 删除

需要排查时，展开 `详情`：

- 查看它是第几位被检查。
- 查看内部顺序值。
- 查看浏览器 Profile。
- 查看 warning 详情。

### 临时停用

1. 关闭规则左侧 Toggle。
2. 不需要再点击 Save。
3. 再打开链接，确认它改走其他规则或 fallback。

### 删除

1. 点击 `Delete`。
2. 在确认框中再次点击红色删除按钮。
3. 删除后重新测试来源 App。

不确定是否以后还会用时，建议先停用，不要删除。

## 八、设置 Fallback Browser

在 `Routing rules` 底部找到 `Fallback browser`：

1. 选择 Safari、Chrome 或其他已发现浏览器。
2. 选择后会立即保存。
3. 用 Terminal 的 fallback 测试再次验证。

Fallback 会在以下情况使用：

- 来源 App 无法识别。
- 没有启用的规则匹配。
- 某条规则的目标浏览器不存在或启动失败。

## 九、菜单栏临时控制

点击菜单栏 LinkRouter 图标，可以使用：

- `Pause Routing for 10 Minutes`：临时停用规则，所有链接走 fallback browser。
- `Resume Routing`：提前恢复规则。
- `Open Next Link With`：只指定下一次链接使用某个浏览器。
- `Clear Next-Link Override`：取消下一次链接指定。

这几个功能不会改动你的规则文件，适合临时处理一次特殊链接。

## 十、导入、导出和重置配置

在 Settings 的 `Configuration storage` 区域：

- `Export Configuration`：导出当前 JSON 配置，适合备份或分享给另一个测试者。
- `Import Configuration`：导入一个 LinkRouter JSON 配置，导入成功后立即保存并生效。
- `Reset to Defaults`：恢复 Codex、WeChat、Mail 和 Safari fallback 的默认配置。

建议在大幅调整规则前先导出一次。

## 十一、每次操作后检查什么

### 每次启动 App

- 菜单栏是否出现 LinkRouter 图标。
- `URL listener is active` 是否显示。
- Settings 中浏览器数量是否正常。
- Configuration storage 是否没有红色错误。

### 每次修改规则

- 是否出现 `Added/Updated/Deleted rule and saved`。
- Configuration storage 是否显示 `Saved to disk`。
- 用对应来源 App 再打开一次链接。
- 检查 `Matched rule` 和 `Final browser`。

### 每次发现路由错误

不要立即反复修改规则。先记录：

- Source app
- Bundle identifier
- Detection method
- Confidence
- Matched rule
- Selected browser
- Final browser
- 红色或橙色错误文字

先判断是“来源识别错误”“规则未匹配”还是“浏览器启动失败”。

## 十、配置文件与恢复

配置文件位于：

```text
~/Library/Application Support/LinkRouter/routing-config.json
```

正常情况下不要手动编辑。图形界面保存时会原子写入。

如果 `Configuration storage` 显示红色
`Using in-memory fallback`：

1. 不要删除或覆盖原配置文件。
2. 当前 App 会使用内置的 Codex、WeChat 和 Safari 默认配置继续运行。
3. 规则编辑功能会被禁用，防止覆盖损坏文件。
4. 记录界面显示的错误详情，再进行配置恢复。

## 十一、当前版本限制

- 来源 App 检测是 best-effort，macOS 不保证 URL handler 能知道原始来源。
- Codex、WeChat 等真实点击兼容性仍需要你逐项测试。
- 开机自启动需要在 Settings 的 `Launch at login` 中开启。
- 默认浏览器状态需要点击 `Refresh Default Browser Status` 或重启 App 后刷新。
- 最近路由历史当前只保存在内存中，退出 App 后会清空。
- 当前 `Ask me every time` 弹窗队列尚未实现；临时选择请先使用菜单栏
  `Open Next Link With`。
- 当前使用 Xcode 开发版，停止 Xcode 的运行任务会退出 LinkRouter。

## 十二、推荐的本轮检查顺序

今天只做以下流程即可：

1. 用 Xcode 运行 LinkRouter。
2. 打开 Settings，检查 Safari、Chrome 和配置状态。
3. 分别点击两个 `Open Test Page`。
4. 在 System Settings 中把 LinkRouter 设为默认浏览器。
5. 执行 Terminal fallback 测试。
6. 从 Codex 点击链接并记录诊断结果。
7. 从 WeChat 点击链接并记录诊断结果。
8. 从 Mail 点击链接并记录诊断结果。
9. 打开 Add Rule 表单，检查字段和浏览器列表，然后点击 Cancel。
10. 点击一条规则的 Edit，检查已有内容，然后点击 Cancel。
11. 把测试结果反馈给开发流程，再决定是否修正来源识别。
