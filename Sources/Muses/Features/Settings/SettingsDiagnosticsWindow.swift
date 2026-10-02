import SwiftUI

/// Uses composition-root services; never constructs a second resolver or session.
struct SettingsDiagnosticsWindow: View {
    @State private var topic = DiagnosticTopic.playback

    private enum DiagnosticTopic: String, CaseIterable, Identifiable {
        case playback, imports, account
        var id: String { rawValue }
        var label: String {
            switch self {
            case .playback: tr("Playback", "播放")
            case .imports: tr("Import", "导入")
            case .account: tr("Account", "账号")
            }
        }
        var guidance: String {
            switch self {
            case .playback:
                tr("Check the source video on YouTube, then retry the track. For age-restricted or private media, review playback browser access in Account settings. Resolver and format details are below.",
                   "先在 YouTube 检查源视频，再重试曲目。年龄受限或私有媒体请检查账号设置中的播放浏览器访问。下方可查看解析器与格式详情。")
            case .imports:
                tr("Confirm that the playlist link opens on YouTube. For account playlists, refresh the connected account; for sync conflicts, compare the local and remote versions before applying changes. Resolver configuration is below.",
                   "先确认歌单链接可在 YouTube 打开。账号歌单请刷新已连接账号；同步冲突请先比较本机及远程版本再应用改动。下方可查看解析器配置。")
            case .account:
                tr("Account sign-in, playback browser access and Personalized Home consent are separate. Reconnect an expired account in Account settings. Home recovery must use the approved browser and the same channel; never broaden permissions to bypass a failure.",
                   "账号登录、播放浏览器访问及个性化首页同意彼此独立。在账号设置重新连接过期会话。首页恢复必须使用已批准浏览器与相同频道。")
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Picker(tr("Issue category", "问题类别"), selection: $topic) {
                    ForEach(DiagnosticTopic.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
                Text(topic.guidance).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } header: { Text(tr("Troubleshooting", "故障排查")) }
            GPUSettingsView()
            YouTubeSettingsView(destination: .diagnostics)
        }
        .formStyle(.grouped).controlSize(.regular)
        .tint(BrandColors.accent)
        .frame(minWidth: 520, minHeight: 480)
        .navigationTitle(tr("Diagnostics", "诊断"))
    }
}
