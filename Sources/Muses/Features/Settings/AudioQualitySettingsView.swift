import SwiftUI

enum YTAudioQualityOption: String, CaseIterable {
    case bestaudio, k256 = "256k", k128 = "128k", k64 = "64k"
    case best, p1080 = "1080p", p720 = "720p"

    var label: String {
        switch self {
        case .bestaudio: return tr("Best audio", "最高音质")
        case .k256: return tr("High (best available)", "高音质（最佳可用）", zhHant: "高音質（最佳可用）")
        case .k128: return tr("Medium (128k)", "中等 (128k)")
        case .k64: return tr("Data saver (64k)", "省流 (64k)")
        case .best: return tr("Best video", "最高画质视频")
        case .p1080: return "1080p"
        case .p720: return "720p"
        }
    }

    var isVideo: Bool {
        self == .best || self == .p1080 || self == .p720
    }
}

/// yt-dlp download quality + cache status. Changing quality reloads the current track.
struct AudioQualitySettingsView: View {
    @Environment(PlaybackService.self) private var playback
    @Environment(StreamPrecacheService.self) private var precache
    @AppStorage(PrefKey.ytAudioQuality) private var ytQuality: String = "bestaudio"
    @AppStorage(PrefKey.streamPrecacheLimitGB) private var cacheLimitGB = 2
    @State private var cacheReadGeneration = UUID()
    @State private var cacheSummary: SettingsMediaCacheSummary?
    @State private var cacheClearFailed = false
    @State private var cacheReadFailed = false
    @State private var pendingRemoval: ActionConfirmation?

    var body: some View {
        Section {

            Picker(tr("Quality profile", "音质方案"), selection: $ytQuality) {
                Text(tr("Automatic", "自动")).tag("bestaudio")
                Text(tr("Data saver", "省流量")).tag("64k")
                Text(tr("High quality", "高品质")).tag("256k")
                if !["bestaudio", "64k", "256k"].contains(ytQuality) {
                    Text(tr("Custom", "自选")).tag(ytQuality)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: ytQuality) { _, _ in
                precache.configure()
                playback.reloadCurrent()
                Task { await refreshCache() }
            }
            DisclosureGroup(tr("Format & source details", "格式与来源详情")) {
                Picker(tr("Download format", "下载格式"), selection: $ytQuality) {
                    ForEach(YTAudioQualityOption.allCases.filter { !$0.isVideo }, id: \.rawValue) {
                        Text($0.label).tag($0.rawValue)
                    }
                    if YTAudioQualityOption(rawValue: ytQuality)?.isVideo == true {
                        Text(tr("Best available audio", "最佳可用音频", zhHant: "最佳可用音訊")).tag(ytQuality)
                    }
                }.pickerStyle(.menu)
                Text(tr("Automatic and High quality use the best available public audio source. Changing the profile reloads the current track. Codec and bitrate describe the actual source when known.",
                        "自动和高品质使用最佳可用公开音频源。更改方案会重新加载当前曲目。仅显示实际音源已知的编码及码率。",
                        zhHant: "自動和高品質使用最佳可用公開音訊來源。更改方案會重新載入目前曲目。僅顯示實際音源已知的編碼及位元率。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
            }
        } header: { Text(tr("Quality", "音质")).font(MusesTypography.headline.weight(.semibold)) }

        Section {
            Picker(tr("Media cache capacity", "媒体缓存容量"), selection: $cacheLimitGB) {
                ForEach([1, 2, 5, 10], id: \.self) { Text("\($0) GB").tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: cacheLimitGB) { _, _ in
                precache.configure()
                Task { await refreshCache() }
            }
            LabeledContent {
                Button(role: .destructive) {
                    pendingRemoval = ActionConfirmation(
                        title: tr("Clear media cache?", "清除媒体缓存？"),
                        message: cacheClearMessage,
                        actionTitle: tr("Clear", "清除"),
                        action: clearCache
                    )
                } label: {
                    Image(systemName: "trash").frame(width: 18, height: 18)
                }
                .settingsAction()
                .accessibilityLabel(tr("Clear media cache", "清除媒体缓存"))
                .help(tr("Clear media cache", "清除媒体缓存"))
            } label: {
                Text(tr("Downloaded media", "已下载媒体"))
                Text(cacheSizeLabel)
                    .font(MusesTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if let cacheSummary {
                ProgressView(value: min(1, Double(cacheSummary.total) / Double(MediaCacheBudget.bytes(forGigabytes: cacheLimitGB))))
                    .accessibilityLabel(tr("Media cache capacity used", "已用媒体缓存容量"))
                    .accessibilityValue(cacheSizeLabel)
            }
            if cacheClearFailed {
                Label(tr("Could not clear the media cache. Some files may remain. Check storage access, then try Clear again.",
                         "无法清除媒体缓存，部分文件可能仍然保留。请检查存储访问权限，然后再次选择清除。",
                         zhHant: "無法清除媒體快取，部分檔案可能仍然保留。請檢查儲存存取權限，然後再次選擇清除。"),
                      systemImage: "exclamationmark.triangle")
                    .font(MusesTypography.caption).foregroundStyle(.red)
            }
            if cacheReadFailed {
                Label(cacheReadFailureMessage, systemImage: "exclamationmark.triangle")
                    .font(MusesTypography.caption).foregroundStyle(.red)
                Button(tr("Retry cache size", "重试读取缓存大小", zhHant: "重試讀取快取大小")) {
                    Task { await refreshCache() }
                }
                .settingsAction()
            }
            Text(tr("This capacity applies to playback downloads and pre-downloads, even when pre-download is off. Older unused media is removed as needed. Files in use are kept; new downloads wait if those files fill the capacity. Your library is unchanged.",
                    "此容量同时限制播放下载与预下载，关闭预下载时也有效。需要时会清理较早未使用的媒体。正在使用的文件保留；若其已占满容量，则暂停新增缓存。资料库不受影响。",
                    zhHant: "此容量同時限制播放下載與預下載，關閉預下載時也有效。需要時會清理較早未使用的媒體。使用中的檔案會保留；若已占滿容量，則暫停新增快取。資料庫不受影響。"))
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup(tr("Cache categories", "缓存分类")) {
                LabeledContent(tr("Audio file formats", "音频文件格式"), value: byteLabel(cacheSummary?.audio))
                LabeledContent(tr("MP4 / WebM / video containers", "MP4／WebM／视频容器"), value: byteLabel(cacheSummary?.video))
                LabeledContent(tr("Other / partial files", "其他／未完成文件"), value: byteLabel(cacheSummary?.other))
                Text(tr("Only the stream cache is cleared here. Artwork, Home snapshots, your library and account credentials are retained.", "此处仅清理媒体缓存。封面、首页快照、资料库及账号凭据保留。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
            }
            if let q = playback.state.quality, playback.state.track != nil {
                DisclosureGroup(tr("Current audio", "当前音频")) {
                    Text(playingLabel(q)).font(MusesTypography.caption).textSelection(.enabled)
                }
            }
        } header: { Text(tr("Cache", "缓存")).font(MusesTypography.headline.weight(.semibold)) }
        .actionConfirmation($pendingRemoval)
        .task { await refreshCache() }
    }

    private var cacheSizeLabel: String { byteLabel(cacheSummary?.total) }

    private var cacheClearMessage: String {
        if let cacheSummary, !cacheReadFailed {
            return tr("Remove \(byteLabel(cacheSummary.total)) of downloaded media from this app's stream cache. The current track reloads. Playlists, likes, history, artwork and saved Home remain; media can be downloaded again.",
                      "从应用媒体缓存移除 \(byteLabel(cacheSummary.total)) 已下载媒体。当前曲目会重新加载。歌单、收藏、历史、封面与首页快照保留；媒体可再次下载。")
        }
        return tr("Remove downloaded media from this app's stream cache. Its current size is unavailable. The current track reloads after clearing succeeds. Playlists, likes, history, artwork and saved Home remain; media can be downloaded again.",
                  "移除应用媒体缓存中已下载的媒体。当前缓存大小不可用。清除成功后会重新加载当前曲目。歌单、收藏、历史、封面与首页快照保留；媒体可再次下载。",
                  zhHant: "移除應用程式媒體快取中已下載的媒體。目前快取大小無法取得。清除成功後會重新載入目前曲目。歌單、收藏、歷史、封面與首頁快照保留；媒體可再次下載。")
    }

    private var cacheReadFailureMessage: String {
        if cacheSummary != nil {
            return tr("Could not refresh the cache size. The last known size is shown. Check storage access and retry.",
                      "无法刷新缓存大小，当前显示上次读取的数值。请检查存储访问权限后重试。",
                      zhHant: "無法重新整理快取大小，目前顯示上次讀取的數值。請檢查儲存存取權限後重試。")
        }
        return tr("Could not read the cache size. Check storage access and retry.",
                  "无法读取缓存大小。请检查存储访问权限后重试。",
                  zhHant: "無法讀取快取大小。請檢查儲存存取權限後重試。")
    }

    private func byteLabel(_ bytes: Int64?) -> String {
        guard let bytes else { return tr("Unavailable", "不可用", zhHant: "無法取得") }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func clearCache() {
        cacheReadGeneration = UUID()
        do {
            try MediaFileCache.clearAll()
            cacheClearFailed = false
            playback.reloadCurrent()
        } catch {
            cacheClearFailed = true
        }
        Task { await refreshCache() }
    }

    private func refreshCache() async {
        let generation = UUID()
        cacheReadGeneration = generation
        let root = MediaFileCache.directory
        let result = await Task.detached(priority: .utility) {
            Result { try SettingsMediaCacheSummary.read(root) }
        }.value
        guard !Task.isCancelled, cacheReadGeneration == generation else { return }
        switch result {
        case .success(let summary):
            cacheSummary = summary
            cacheReadFailed = false
        case .failure:
            cacheReadFailed = true
        }
    }

    private func playingLabel(_ q: AudioQualityInfo) -> String {
        var parts: [String] = []
        if !q.codec.isEmpty, !["native", "unknown"].contains(q.codec.lowercased()) { parts.append(q.codec) }
        if q.sampleRate > 0 { parts.append(AudioQualityInfo.sampleRateLabel(q.sampleRate)) }
        if q.bitDepth > 0 { parts.append("\(q.bitDepth)-bit") }
        if let bitrate = q.bitrateLabel { parts.append(bitrate) }
        return parts.joined(separator: " · ")
    }
}

/// Immutable display metadata; no media content is opened or changed.
struct SettingsMediaCacheSummary: Equatable, Sendable {
    var audio: Int64 = 0
    var video: Int64 = 0
    var other: Int64 = 0
    var total: Int64 { audio + video + other }

    static func read(_ root: URL) throws -> Self {
        guard MediaFileCache.isSafeDirectory(root, allowMissing: false) else { throw CocoaError(.fileReadNoPermission) }
        let files = try FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        var result = Self()
        for file in files {
            let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            guard let size = values.fileSize, size >= 0 else { throw CocoaError(.fileReadUnknown) }
            let bytes = Int64(size)
            switch file.pathExtension.lowercased() {
            case "m4a", "mp3", "aac", "opus", "ogg", "flac", "wav": result.audio += bytes
            case "mp4", "webm", "mkv", "mov": result.video += bytes
            default: result.other += bytes
            }
        }
        return result
    }
}
