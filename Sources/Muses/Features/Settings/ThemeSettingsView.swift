import SwiftUI
import AppKit

struct ThemeSettingsView: View {
    @AppStorage(PrefKey.nowPlayingMode) private var modeRaw = NowPlayingMode.cover.rawValue
    @AppStorage(PrefKey.theme) private var themeRaw = AppTheme.system.rawValue
    @State private var typography = TypographyPreferences.shared
    @State private var showFonts = false

    var body: some View {
        @Bindable var typography = typography
        Section {
            Picker(tr("Theme", "主题"), selection: $themeRaw) {
                Text(tr("System", "系统")).tag(AppTheme.system.rawValue)
                Text(tr("Light", "浅色")).tag(AppTheme.light.rawValue)
                Text(tr("Dark", "深色")).tag(AppTheme.dark.rawValue)
            }
            .pickerStyle(.segmented)
            LabeledContent(tr("Now Playing", "正在播放")) {
                SettingsGlassChoice(title: tr("Now Playing", "正在播放"), selection: $modeRaw, options: [
                    .init(id: NowPlayingMode.cover.rawValue, title: tr("Cover", "封面"), symbol: "square"),
                    .init(id: NowPlayingMode.vinyl.rawValue, title: tr("Vinyl", "黑胶"), symbol: "opticaldisc")
                ])
            }
        } header: { Text(tr("Theme & artwork", "主题与封面")) }
        Section {
            Picker(tr("Text size", "字号"), selection: $typography.size) {
                ForEach(InterfaceTextSize.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker(tr("Font style", "字体风格"), selection: Binding(
                get: { typography.family == "system" ? "system" : typography.family.isEmpty ? "classic" : "custom" },
                set: { if $0 != "custom" { typography.family = $0 == "system" ? "system" : "" } }
            )) {
                Text(tr("System", "系统")).tag("system")
                Text(tr("Classic", "经典")).tag("classic")
                if !typography.family.isEmpty && typography.family != "system" {
                    Text(tr("Custom", "自选")).tag("custom")
                }
            }
            .pickerStyle(.segmented)
            LabeledContent(tr("Font", "字体")) {
                Button { showFonts = true } label: {
                    Label(typography.family.isEmpty
                          ? tr("Classic Muses", "Muses 经典") : typography.family == "system" ? tr("System", "系统") : typography.family,
                          systemImage: "textformat")
                        .lineLimit(1)
                }
                .settingsAction()
                .popover(isPresented: $showFonts) {
                    SettingsFontPicker(typography: typography)
                }
            }
            TypographyLiveSamples()
        } header: { Text(tr("Text", "文字")) }
    }
}

/// Load the complete system font list only while its native popover is visible.
private struct SettingsFontPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var typography: TypographyPreferences
    @State private var families: [String] = []
    @State private var query = ""
    @State private var keyboardSelection = SettingsFontKeyboardSelection()
    @FocusState private var searching: Bool

    private var filtered: [String] {
        families.filter { query.isEmpty || $0.localizedStandardContains(query) }
    }

    private var visibleFamilies: [String] { ["system", ""] + filtered }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Font", "字体")).font(MusesTypography.headline)
            TextField(tr("Search system fonts", "搜索系统字体"), text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searching)
                .help(tr("Use Up and Down to choose a font, Return to apply, and Escape to close.",
                         "使用上下方向键选择字体，回车应用，Escape 关闭。",
                         zhHant: "使用上下方向鍵選擇字體，Return 套用，Escape 關閉。"))
                .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { press in
                    guard SettingsFontKeyboardSelection.acceptsModifiers(press.modifiers) else { return .ignored }
                    keyboardSelection.move(by: 1, within: visibleFamilies)
                    return .handled
                }
                .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { press in
                    guard SettingsFontKeyboardSelection.acceptsModifiers(press.modifiers) else { return .ignored }
                    keyboardSelection.move(by: -1, within: visibleFamilies)
                    return .handled
                }
                .onSubmit {
                    if let family = keyboardSelection.confirmedFamily(within: visibleFamilies) {
                        typography.family = family
                    }
                }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        fontRow("system", title: tr("System", "系统"))
                        fontRow("", title: tr("Classic Muses", "Muses 经典"))
                        ForEach(filtered, id: \.self) { family in fontRow(family, title: family) }
                    }
                }
                .onChange(of: keyboardSelection.candidate) { _, family in
                    if let family { proxy.scrollTo(family, anchor: .center) }
                }
            }
            TypographyLiveSamples(compact: true)
        }
        .padding(16)
        .multilineTextAlignment(.leading)
        .frame(width: 380, height: 360)
        .onExitCommand { dismiss() }
        .onChange(of: query) { _, _ in keyboardSelection.reset() }
        .task {
            families = NSFontManager.shared.availableFontFamilies.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            searching = true
        }
    }

    private func fontRow(_ family: String, title: String) -> some View {
        Button {
            keyboardSelection.reset()
            typography.family = family
        } label: {
            HStack {
                Text(title)
                Spacer()
                if typography.family == family { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 30)
            .settingsSelection(typography.family == family)
            .overlay {
                if searching && keyboardSelection.candidate == family {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(BrandColors.accent, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.fullAreaPlain)
        .id(family)
        .accessibilityValue(keyboardSelection.candidate == family
            ? tr("Ready to apply", "待确认", zhHant: "待確認") : "")
        .accessibilityAddTraits(typography.family == family ? .isSelected : [])
    }
}

/// The three semantic roles react to the same live size and family preference.
private struct TypographyLiveSamples: View {
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            sample(tr("Title", "标题")) {
                Text(tr("Spring Prelude", "春日序曲"))
                    .font(MusesTypography.heading(tr("Spring Prelude", "春日序曲"), size: 22))
            }
            sample(tr("Track", "曲目")) {
                Text(tr("Music in the evening · Muses", "晚间音乐 · Muses"))
                    .font(MusesTypography.song(size: 15))
            }
            sample(tr("Lyrics", "歌词")) {
                Text(tr("A little light across the sky", "天边映出一缕光"))
                    .font(MusesTypography.lyric(size: 20, current: true))
            }
        }
        .padding(.vertical, 8)
    }
    private func sample<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content().foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
