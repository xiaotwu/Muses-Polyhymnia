import SwiftUI
import AppKit

/// Stages Muses' playback preference without overwriting an external yt-dlp file.
struct YTDlpConfigWizard: View {
    @AppStorage(PrefKey.ytCookieSource) private var currentSource = YTCookieSource.none.rawValue
    @State private var browser = YTCookieSource.none.rawValue
    @State private var showPreview = false
    @State private var status: String?

    private var externalConfig: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/yt-dlp/config")
    }

    var body: some View {
        Section {
            DisclosureGroup(tr("Muses playback configuration", "Muses 播放配置")) {
                Picker(tr("Browser", "浏览器"), selection: $browser) {
                    if currentSource == YTCookieSource.file.rawValue {
                        Text(tr("Existing cookie file", "现有 Cookie 文件")).tag(YTCookieSource.file.rawValue)
                    }
                    ForEach(YTCookieSource.settingsCases.filter { $0 != .file }, id: \.rawValue) {
                        Text($0.displayName).tag($0.rawValue)
                    }
                }.pickerStyle(.menu)
                Text(tr("This panel changes only Muses' playback and import cookie source. Personalized Home requires its own browser consent. Existing external yt-dlp configuration is retained.",
                        "此面板仅更改 Muses 播放与导入的 Cookie 来源。个性化首页需单独授权浏览器；保留既有外部 yt-dlp 配置。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button(tr("Preview changes…", "预览更改…")) { showPreview = true }
                        .settingsAction().disabled(browser == currentSource)
                }
                if let status { Text(status).font(MusesTypography.caption).foregroundStyle(.secondary) }
            }
            DisclosureGroup(tr("External configuration", "外部配置")) {
                LabeledContent(tr("Default external location", "默认外部位置")) {
                    Text(externalConfig.path).font(MusesTypography.caption.monospaced()).textSelection(.enabled)
                }
                Text(tr("Production yt-dlp can read external user configuration, including other locations selected by its environment. This standard path is not a claim that a file was loaded. Isolated acceptance runs ignore external configuration. This panel does not display cookie contents or change that file.",
                        "生产版 yt-dlp 可以读取外部用户配置，也可能按运行环境读取其他位置。此标准路径不代表文件已被加载。隔离验收运行忽略外部配置；此面板不显示 Cookie 内容或修改该文件。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
                Button(tr("Show location", "显示所在位置")) {
                    NSWorkspace.shared.activateFileViewerSelecting([externalConfig.deletingLastPathComponent()])
                }.settingsAction()
            }
        } header: { Text(tr("Configuration", "配置")) }
        .onAppear { browser = currentSource }
        .sheet(isPresented: $showPreview) {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("Playback configuration preview", "播放配置预览")).font(.title2.weight(.semibold))
                LabeledContent(tr("Target", "目标"), value: tr("Muses playback preference on this Mac", "本机 Muses 播放偏好"))
                LabeledContent(tr("Current source", "当前来源"), value: sourceName(currentSource))
                LabeledContent(tr("New source", "新来源"), value: sourceName(browser))
                Text(tr("External configuration, Web Home consent and account tokens are retained. The selected browser session is used only when a future playback/import request needs it.",
                        "保留外部配置、Web 首页授权及账号令牌。未来播放／导入请求需要时才使用所选浏览器会话。"))
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(tr("Cancel", "取消")) { showPreview = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(tr("Apply", "应用")) {
                        currentSource = browser
                        status = tr("Muses playback preference updated", "已更新 Muses 播放偏好")
                        showPreview = false
                    }.buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 520)
        }
    }

    private func sourceName(_ value: String) -> String {
        (YTCookieSource(rawValue: value) ?? .none).displayName
    }
}
