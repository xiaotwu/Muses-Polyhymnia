import SwiftUI

enum YTAudioQualityOption: String, CaseIterable {
    case bestaudio, k256 = "256k", k128 = "128k", k64 = "64k"
    case best, p1080 = "1080p", p720 = "720p"

    var label: String {
        switch self {
        case .bestaudio: return tr("Best audio", "最高音质")
        case .k256: return tr("High (256k)", "高音质 (256k)")
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
    @State private var cacheSummary = SettingsMediaCacheSummary()
    @State private var cacheBytes: Int64 = 0
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
                    ForEach(YTAudioQualityOption.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                }.pickerStyle(.menu)
                Text(tr("Automatic uses the best available audio source. Quality depends on YouTube; changing the profile reloads the current track. Codec and bitrate are reported only when known.",
                        "自动使用可用的最佳音频源。音质取决于 YouTube；更改方案会重新加载当前曲目。仅显示实际已知的编码及码率。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
            }
        } header: { Text(tr("Quality", "音质")).font(MusesTypography.headline.weight(.semibold)) }

        Section {
            LabeledContent {
                Button(role: .destructive) {
                    pendingRemoval = ActionConfirmation(
                        title: tr("Clear media cache?", "清除媒体缓存？"),
                        message: tr("Remove \(ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file)) of downloaded media from this app's stream cache. The current track reloads. Playlists, likes, history, artwork and saved Home remain; media can be downloaded again.", "从应用媒体缓存移除 \(ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file)) 已下载媒体。当前曲目会重新加载。歌单、收藏、历史、封面与首页快照保留；媒体可再次下载。"),
                        actionTitle: tr("Clear", "清除"),
                        action: {
                            MediaFileCache.clearAll()
                            cacheReadGeneration = UUID()
                            cacheBytes = 0
                            cacheSummary = SettingsMediaCacheSummary()
                            playback.reloadCurrent()
                        }
                    )
                } label: {
                    Image(systemName: "trash").frame(width: 18, height: 18)
                }
                .settingsAction()
                .accessibilityLabel(tr("Clear media cache", "清除媒体缓存"))
                .help(tr("Clear media cache", "清除媒体缓存"))
            } label: {
                Text(tr("Downloaded media", "已下载媒体"))
                Text(ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file))
                    .font(MusesTypography.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, Double(cacheBytes) / (Double(max(1, cacheLimitGB)) * 1_073_741_824)))
                .accessibilityLabel(tr("Stream cache relative to pre-download budget", "媒体缓存占预下载预算"))
                .accessibilityValue(ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file))
            Text(tr("Pre-download budget: \(cacheLimitGB) GB. Playback downloads may exceed this budget; existing cache is retained.", "预下载预算：\(cacheLimitGB) GB。播放下载可超过此预算；保留已有缓存。"))
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup(tr("Cache categories", "缓存分类")) {
                LabeledContent(tr("Audio file formats", "音频文件格式"), value: byteLabel(cacheSummary.audio))
                LabeledContent(tr("MP4 / WebM / video containers", "MP4／WebM／视频容器"), value: byteLabel(cacheSummary.video))
                LabeledContent(tr("Other / partial files", "其他／未完成文件"), value: byteLabel(cacheSummary.other))
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

    private func byteLabel(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func refreshCache() async {
        let generation = UUID()
        cacheReadGeneration = generation
        let root = MediaFileCache.directory
        let summary = await Task.detached(priority: .utility) { SettingsMediaCacheSummary.read(root) }.value
        guard !Task.isCancelled, cacheReadGeneration == generation else { return }
        cacheSummary = summary
        cacheBytes = summary.audio + summary.video + summary.other
    }

    private func playingLabel(_ q: AudioQualityInfo) -> String {
        var parts: [String] = []
        if !q.codec.isEmpty { parts.append(q.codec) }
        if q.sampleRate > 0 { parts.append(AudioQualityInfo.sampleRateLabel(q.sampleRate)) }
        if q.bitDepth > 0 { parts.append("\(q.bitDepth)-bit") }
        let chosen = YTAudioQualityOption(rawValue: ytQuality)?.label ?? ytQuality
        parts.append(chosen)
        return parts.joined(separator: " · ")
    }
}

/// Immutable display metadata; no media content is opened or changed.
private struct SettingsMediaCacheSummary: Sendable {
    var audio: Int64 = 0
    var video: Int64 = 0
    var other: Int64 = 0
    static func read(_ root: URL) -> Self {
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return .init() }
        var result = Self()
        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { continue }
            let bytes = Int64(values.fileSize ?? 0)
            switch file.pathExtension.lowercased() {
            case "m4a", "mp3", "aac", "opus", "ogg", "flac", "wav": result.audio += bytes
            case "mp4", "webm", "mkv", "mov": result.video += bytes
            default: result.other += bytes
            }
        }
        return result
    }
}
