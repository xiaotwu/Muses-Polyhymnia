import SwiftUI

struct LyricsTranslationPicker: View {
    @Binding var selection: String

    var body: some View {
        Picker(tr("Default translation", "默认翻译"), selection: $selection) {
            Text(tr("Off", "关闭")).tag("off")
            Text("English").tag("en")
            Text("简体中文").tag("zh-Hans")
            Text("繁體中文").tag("zh-Hant")
        }
    }
}

struct LyricsSettingsView: View {
    @AppStorage(PrefKey.lyricsSource) private var lyricsSource = "auto"
    @AppStorage(PrefKey.lyricsIntelligence) private var intelligentMatching = true
    @AppStorage(PrefKey.lyricsTranslationLanguage) private var translationTarget = "off"
    @AppStorage(PrefKey.lyricsRomanization) private var romanization = false
    @State private var showSources = false
    @State private var availability = LyricsIntelligence.availability

    var body: some View {
        Section {
            LyricsTranslationPicker(selection: $translationTarget)
                .disabled(!supportsTranslation)
            Toggle(tr("Default romanization", "默认音译"), isOn: $romanization)
                .disabled(availability != .available && !romanization)
        } header: { Text(tr("Display", "显示")).font(MusesTypography.headline.weight(.semibold)) }
        Section {
            HStack(spacing: 8) {
                Toggle(tr("Intelligent matching", "智能匹配"), isOn: $intelligentMatching)
                    .disabled(availability != .available && !intelligentMatching)
                LyricsIntelligenceStatusControl(availability: $availability)
            }
            SettingsStatus(title: availability.message,
                           symbol: availability == .available ? "checkmark.circle" : "info.circle")
            DisclosureGroup(tr("Advanced sources", "高级来源"), isExpanded: $showSources) {
                Picker(tr("Preferred source", "优先来源"), selection: $lyricsSource) {
                    Text(tr("Automatic", "自动")).tag("auto")
                    Text("LRCLIB").tag("lrclib")
                    Text("Musixmatch").tag("musixmatch")
                    Text("Lyrics.ovh").tag("lyricsOVH")
                }.pickerStyle(.menu)
                Text(tr("Automatic tries supported sources. This is a preference, not a guarantee of timing or availability. The reading menu shows the actual source and controls translation for the current song.",
                        "自动尝试支持的来源。此为偏好，不保证时序或可用性。阅读菜单显示实际来源，并控制当前歌曲的翻译。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text(tr("Matching", "匹配")).font(MusesTypography.headline.weight(.semibold)) }
        .onAppear { showSources = lyricsSource != "auto"; availability = LyricsIntelligence.availability }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            availability = LyricsIntelligence.availability
        }
    }

    private var supportsTranslation: Bool {
        if #available(macOS 15.0, *) { return true }
        return false
    }
}

/// Availability is read-only; recovery opens native settings or rechecks the local model.
private struct LyricsIntelligenceStatusControl: View {
    @Binding var availability: LyricsIntelligence.Availability
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            Image(systemName: "info.circle").frame(width: 28, height: 28)
        }
        .buttonStyle(.fullAreaPlain)
        .accessibilityLabel(tr("Intelligent matching status and recovery", "智能匹配状态与恢复"))
        .help(availability.message)
        .popover(isPresented: $presented) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Intelligent matching", "智能匹配")).font(.headline)
                SettingsStatus(title: availability.message,
                               symbol: availability == .available ? "checkmark.circle" : "info.circle")
                Text(tr("Uses Apple's on-device model on a supported Mac and in a supported region, with Apple Intelligence enabled and its model ready. It selects retrieved candidates; it never generates lyrics or timing.",
                        "需要支持的 Mac 与地区、已启用的 Apple Intelligence 及就绪的设备端模型。它仅选择已检索的候选，不生成歌词或时序。"))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Text(recoveryExplanation).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(tr("Close", "关闭")) { presented = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    switch availability {
                    case .disabled:
                        Button(tr("System Settings", "系统设置")) {
                            if let url = URL(string: "x-apple.systempreferences:") { NSWorkspace.shared.open(url) }
                        }.settingsAction()
                    case .olderSystem, .ineligible:
                        Link(tr("Support conditions", "支持条件"), destination: URL(string: "https://support.apple.com/121115")!)
                            .settingsAction()
                    case .available, .downloading, .unavailable:
                        Button(tr("Refresh status", "刷新状态")) { availability = LyricsIntelligence.availability }
                            .settingsAction()
                    }
                }
            }
            .padding(16).frame(width: 340)
            .onExitCommand { presented = false }
        }
    }

    private var recoveryExplanation: String {
        switch availability {
        case .available:
            tr("If matching fails, ordinary source retrieval still works. Choose a candidate with Match Lyrics in the reading menu; the original lyrics remain available.",
               "匹配失败时仍可普通检索。在阅读菜单使用“匹配歌词”选择候选；原文歌词仍可使用。")
        case .disabled:
            tr("Enable Apple Intelligence in System Settings, then return to Muses. Ordinary lyric retrieval remains available.",
               "请在系统设置中启用 Apple Intelligence 后返回 Muses。普通歌词检索仍可使用。")
        case .downloading:
            tr("Wait for Apple's model preparation to finish, then refresh this status. Ordinary lyric retrieval remains available while you wait.",
               "请等待 Apple 完成模型准备，再刷新此状态。等待期间仍可普通检索歌词。")
        case .olderSystem, .ineligible:
            tr("Review Apple's device, language and region support. Use ordinary lyric retrieval or manual matching on this Mac.",
               "请查看 Apple 对设备、语言及地区的支持条件。此 Mac 可使用普通检索或手动匹配歌词。")
        case .unavailable:
            tr("Recheck the local model status. If it remains unavailable, use ordinary source retrieval or manual matching; no extra permission is required.",
               "请重新检查本机模型状态。若仍不可用，可使用普通检索或手动匹配，无需额外权限。")
        }
    }
}

struct LyricsSupportView: View {
    let availability: LyricsIntelligence.Availability

    var body: some View {
        Section {
            DisclosureGroup(tr("Lyrics & translation", "歌词与翻译")) {
                Text(tr("Lyrics come from sources, never generated from memory.", "歌词来自检索来源，不凭记忆生成。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
                Text(tr("Automatic translation and romanization may contain errors. Original lyrics remain available.",
                        "自动翻译和音译可能有误，原文歌词始终保留。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
            }
            LabeledContent(tr("Intelligence support", "智能功能支持")) {
                SettingsIconButton(title: tr("Apple Intelligence availability", "Apple Intelligence 可用性"), symbol: "arrow.up.right") {
                    NSWorkspace.shared.open(URL(string: "https://support.apple.com/121115")!)
                }
            }
        } header: { Text(tr("Information", "说明")) }
    }
}
