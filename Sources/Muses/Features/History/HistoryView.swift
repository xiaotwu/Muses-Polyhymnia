import SwiftUI

/// Listening history is a local, useful dashboard rather than a raw event log.
/// It distinguishes loading, empty, and persistence failure explicitly.
struct HistoryView: View {
    @Environment(HistoryService.self) private var history
    @Environment(LibraryService.self) private var library
    @Environment(PlaybackService.self) private var playback
    @Environment(YouTubeImportService.self) private var importService: YouTubeImportService?
    @AppStorage(PrefKey.ffSmartHistory) private var enabled = true
    @State private var range: RecapRange = .week
    @State private var dashboard: ListeningHistoryDashboard?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var showClearConfirm = false
    @State private var heatmapExpanded = false
    @State private var rankingVideoIDs: [String] = []

    private let metricColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppleMusicSpacing.section) {
                header
                if enabled {
                    content
                } else {
                    disabledState
                }
            }
            .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            .padding(.top, AppleMusicSpacing.browseTitleTop)
            .padding(.bottom, OverlayChromeMetrics.scrollBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BrowseBackground())
        .task { reload() }
        .onChange(of: enabled) { _, _ in reload() }
        .onChange(of: range) { _, _ in reload() }
        .onChange(of: history.historyRevision) { _, _ in reload() }
        .onChange(of: SongCreditCache.shared.revision) { _, _ in reload() }
        .onChange(of: library.metadataRevision) { _, _ in reload() }
        .task(id: rankingVideoIDs) {
            guard let importService else { return }
            for videoID in rankingVideoIDs {
                guard !Task.isCancelled else { return }
                _ = await importService.songMetadata(videoID: videoID)
            }
        }
        .alert(
            tr("Clear all listening history?", "清空全部收听历史？"),
            isPresented: $showClearConfirm
        ) {
            Button(tr("Clear", "清空"), role: .destructive) { clearHistory() }
            Button(tr("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(tr(
                "This removes the listening activity stored on this Mac.",
                "这会移除此 Mac 上保存的收听活动。"
            ))
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(tr("History", "历史"))
                .font(MusesTypography.pageTitle)
                .foregroundStyle(BrandColors.heading)
            Spacer()
            if dashboard?.totalEventCount ?? 0 > 0 {
                ChromeIconButton(
                    systemName: "trash",
                    help: tr("Clear history", "清空历史"),
                    accessibility: tr("Clear listening history", "清空收听历史")
                ) { showClearConfirm = true }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading, dashboard == nil {
            ProgressView(tr("Loading listening history…", "正在载入收听历史…"))
                .frame(maxWidth: .infinity, minHeight: 240)
        } else if let loadError {
            errorState(loadError)
        } else if let dashboard, dashboard.totalEventCount > 0 {
            if dashboard.recap.eventCount > 0 {
                dashboardContent(dashboard)
            } else {
                Picker(tr("History range", "历史时间范围"), selection: $range) {
                    ForEach(RecapRange.allCases, id: \.self) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 330)
                rangeEmptyState
            }
        } else {
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                title: tr("Nothing played yet", "还没有播放记录"),
                subtitle: tr(
                    "Play a song and its listening activity will appear here.",
                    "播放歌曲后，其收听活动会显示在这里。"
                ),
                actionTitle: tr("Open Search", "打开搜索"),
                action: {
                    NotificationCenter.default.post(name: .musesFocusSearch, object: nil)
                }
            )
        }
    }

    private func dashboardContent(_ value: ListeningHistoryDashboard) -> some View {
        VStack(alignment: .leading, spacing: AppleMusicSpacing.section) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(tr("Listening overview", "收听概览"))
                        .font(MusesTypography.sectionTitle)
                    Spacer()
                    rangePicker
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("Listening overview", "收听概览"))
                        .font(MusesTypography.sectionTitle)
                    rangePicker
                }
            }

            metricGrid(value.recap)
            DisclosureGroup(isExpanded: $heatmapExpanded) {
                ListeningHeatmapView(heatmap: value.heatmap)
                    .padding(.top, 10)
            } label: {
                Label(tr("Listening heatmap", "收听热力图"), systemImage: "square.grid.3x3")
                    .font(MusesTypography.headline)
            }
            topLists(value.recap)
            recentActivity(value.recent, range: value.recap.rangeLabel)
        }
    }

    private var rangePicker: some View {
        Picker(tr("History range", "历史时间范围"), selection: $range) {
            ForEach(RecapRange.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 330)
    }

    private func metricGrid(_ recap: ListeningRecap) -> some View {
        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
            HistoryMetricCard(
                value: ListeningFormat.duration(recap.totalListenedMs),
                label: tr("Time listened", "收听时长")
            )
            HistoryMetricCard(
                value: "\(recap.uniqueTracks)",
                label: tr("Different songs", "不同歌曲")
            )
            HistoryMetricCard(
                value: "\(recap.uniqueArtists)",
                label: tr("Artists", "艺术家")
            )
            HistoryMetricCard(
                value: completionLabel(recap),
                label: tr("Finished plays", "完整播放")
            )
        }
    }

    private func topLists(_ recap: ListeningRecap) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                rankingCard(
                    title: tr("Songs on repeat", "循环热歌"),
                    rows: recap.topTracks.prefix(5).map {
                        ($0.title, $0.artist, tr("\($0.plays) plays", "播放 \($0.plays) 次", zhHant: "播放 \($0.plays) 次"))
                    }
                )
                rankingCard(
                    title: tr("Top artists", "热门艺术家"),
                    rows: recap.topArtists.prefix(5).map {
                        ($0.name, ListeningFormat.duration($0.listenedMs), tr("\($0.plays) plays", "播放 \($0.plays) 次", zhHant: "播放 \($0.plays) 次"))
                    }
                )
            }
            VStack(spacing: 16) {
                rankingCard(
                    title: tr("Songs on repeat", "循环热歌"),
                    rows: recap.topTracks.prefix(5).map {
                        ($0.title, $0.artist, tr("\($0.plays) plays", "播放 \($0.plays) 次", zhHant: "播放 \($0.plays) 次"))
                    }
                )
                rankingCard(
                    title: tr("Top artists", "热门艺术家"),
                    rows: recap.topArtists.prefix(5).map {
                        ($0.name, ListeningFormat.duration($0.listenedMs), tr("\($0.plays) plays", "播放 \($0.plays) 次", zhHant: "播放 \($0.plays) 次"))
                    }
                )
            }
        }
    }

    private func rankingCard(title: String, rows: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(MusesTypography.headline)
                .padding(.bottom, 14)
            if rows.isEmpty {
                Text(tr("Not enough listening activity yet", "收听活动还不够多"))
                    .font(MusesTypography.callout)
                    .foregroundStyle(BrandColors.textSecondary)
                    .padding(.vertical, 18)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(MusesTypography.title3.weight(.heavy))
                            .foregroundStyle(index == 0 ? BrandColors.accent : BrandColors.textSecondary)
                            .frame(width: 24, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.0).font(MusesTypography.callout.weight(.semibold)).lineLimit(1)
                            Text(row.1).font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary).lineLimit(1)
                        }
                        Spacer(minLength: 10)
                        Text(row.2)
                            .font(MusesTypography.caption.monospacedDigit())
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                    .padding(.vertical, 9)
                    if index < rows.count - 1 { Divider().padding(.leading, 36) }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            BrandColors.surface.opacity(0.55),
            in: RoundedRectangle(cornerRadius: AppleMusicTokens.cardCorner, style: .continuous)
        )
    }

    private func recentActivity(_ events: [ListeningEventSnapshot], range: String) -> some View {
        let context = historyPlaybackContext(events)
        return VStack(alignment: .leading, spacing: 12) {
            Text(tr("Recent activity · \(range)", "最近活动 · \(range)", zhHant: "最近活動 · \(range)"))
                .font(MusesTypography.sectionTitle)
            LazyVStack(spacing: 2) {
                ForEach(events) { event in
                    let track = library.track(by: event.trackId).map { TrackSnapshot(from: $0) }
                    HistoryTimelineRow(
                        event: event,
                        track: track,
                        isCurrent: playback.state.track?.id == event.trackId,
                        onPlay: { play(event, within: events) },
                        videoContext: context
                    )
                }
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("History could not be loaded", "无法载入历史记录"))
                .font(MusesTypography.headline)
            Text(message)
                .font(MusesTypography.callout)
                .foregroundStyle(BrandColors.textSecondary)
            Button(tr("Try Again", "重试")) { reload() }.musesAction()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            BrandColors.surface.opacity(0.65),
            in: RoundedRectangle(cornerRadius: AppleMusicTokens.cardCorner, style: .continuous)
        )
    }

    private var rangeEmptyState: some View {
        EmptyStateView(
            icon: "calendar.badge.clock",
            title: tr("No listening in \(range.label)", "\(range.label) 暂无收听记录", zhHant: "\(range.label) 暫無收聽記錄"),
            subtitle: tr(
                "Choose another range to explore earlier listening activity.",
                "可切换时间范围查看更早的收听活动。"
            )
        )
    }

    private var disabledState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Listening history is off", "收听历史已关闭"))
                .font(MusesTypography.headline)
                .foregroundStyle(BrandColors.textPrimary)
            Text(tr(
                "Turn it on in Settings to keep play, skip, and stop activity on this Mac.",
                "在设置中开启后，播放、跳过和停止活动会保存在此 Mac。"
            ))
            .font(MusesTypography.callout)
            .foregroundStyle(BrandColors.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            BrandColors.surface.opacity(0.55),
            in: RoundedRectangle(cornerRadius: AppleMusicTokens.cardCorner, style: .continuous)
        )
    }

    private func reload() {
        guard enabled else {
            isLoading = false
            dashboard = nil
            rankingVideoIDs = []
            loadError = nil
            return
        }
        isLoading = true
        do {
            var tracks: [UUID: TrackSnapshot] = [:]
            var missingTracks: Set<UUID> = []
            let value = try history.dashboard(range: range) { trackID, storedArtist in
                if tracks[trackID] == nil, !missingTracks.contains(trackID) {
                    if let track = library.track(by: trackID) {
                        tracks[trackID] = TrackSnapshot(from: track)
                    } else {
                        missingTracks.insert(trackID)
                    }
                }
                guard let track = tracks[trackID] else { return storedArtist }
                return SongCreditCache.shared.historicalArtist(
                    videoID: track.youTubeId, storedArtist: storedArtist)
            }
            dashboard = value
            rankingVideoIDs = value.recap.topTracks.prefix(5).compactMap { tracks[$0.id]?.youTubeId }
                .reduce(into: [String]()) { result, videoID in
                    if !videoID.isEmpty, !result.contains(videoID) { result.append(videoID) }
                }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            rankingVideoIDs = []
        }
        isLoading = false
    }

    private func clearHistory() {
        do {
            try history.clearAllReporting()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        reload()
    }

    private func play(_ event: ListeningEventSnapshot, within events: [ListeningEventSnapshot]) {
        let context = historyPlaybackContext(events)
        guard let selected = context.first(where: { $0.id == event.trackId }) else { return }
        playback.playTrack(selected, context: context, from: .recently)
    }

    private func historyPlaybackContext(_ events: [ListeningEventSnapshot]) -> [TrackSnapshot] {
        events.compactMap { library.track(by: $0.trackId) }
            .reduce(into: [TrackSnapshot]()) { result, track in
                guard !result.contains(where: { $0.id == track.id }) else { return }
                result.append(TrackSnapshot(from: track))
            }
    }

    private func completionLabel(_ recap: ListeningRecap) -> String {
        guard recap.eventCount > 0 else { return "—" }
        let percent = Int((Double(recap.completedCount) / Double(recap.eventCount) * 100).rounded())
        return "\(percent)%"
    }
}

/// Timeline rows consume stored event values rather than sampling the playback clock.
private struct HistoryTimelineRow: View {
    let event: ListeningEventSnapshot
    let track: TrackSnapshot?
    let isCurrent: Bool
    let onPlay: () -> Void
    let videoContext: [TrackSnapshot]

    @Environment(YouTubeImportService.self) private var importService: YouTubeImportService?
    private var displayArtist: String {
        track.map { SongCreditCache.shared.historicalArtist(videoID: $0.youTubeId, storedArtist: event.artist) } ?? event.artist
    }

    private var isPlayable: Bool { track?.youTubeId != nil }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(source: track.map(ArtworkSource.resolve(for:)) ?? .placeholder,
                        cornerRadius: 6, glyphSize: 16, targetSize: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(MusesTypography.song(size: 13, emphasized: true, text: event.title))
                    .lineLimit(1)
                Text(displayArtist)
                    .font(MusesTypography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                    .lineLimit(1)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { time; listeningDetails }
                    VStack(alignment: .leading, spacing: 4) { time; listeningDetails }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(action: onPlay) {
                Image(systemName: "play.fill").frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(BrandColors.textPrimary)
            .disabled(!isPlayable)
            .help(isPlayable ? tr("Play", "播放") : tr("This song is no longer available in the library", "此歌曲已无法从资料库播放"))
            .accessibilityLabel(tr("Play \(event.title)", "播放 \(event.title)"))
            Menu { historyActions } label: {
                Image(systemName: "ellipsis").frame(width: 28, height: 28)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tr("Options for \(event.title)", "\(event.title) 的选项"))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            .accessibilityLabel(tr("Options for \(event.title)", "\(event.title) 的选项"))
            .help(tr("Options for \(event.title)", "\(event.title) 的选项"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isCurrent ? BrandColors.accent.opacity(0.09) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .contextMenu { historyActions }
        .task(id: track?.youTubeId) {
            guard let videoID = track?.youTubeId, !videoID.isEmpty, let importService else { return }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled else { return }
            _ = await importService.songMetadata(videoID: videoID)
        }
    }

    @ViewBuilder private var historyActions: some View {

            if let track, isPlayable {
                TrackContextMenuItems(snapshot: track, onPlay: onPlay,
                                      videoContext: videoContext, videoSource: .recently)
            } else {
                Button(tr("Play", "播放"), systemImage: "play.fill", action: onPlay)
                    .disabled(true)
            }

    }

    private var time: some View {
        Text(event.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
            .font(MusesTypography.caption2)
            .foregroundStyle(BrandColors.textSecondary)
    }

    private var listeningDetails: some View {
        HStack(spacing: 10) {
            Text(tr("Listened \(ListeningFormat.duration(event.listenedMs))", "已听 \(ListeningFormat.duration(event.listenedMs))"))
            if let ratio = event.completionRatio, ratio.isFinite {
                Text(tr("\(Int((min(1, max(0, ratio)) * 100).rounded()))% complete", "完成 \(Int((min(1, max(0, ratio)) * 100).rounded()))%"))
            } else {
                Text(tr("Completion unknown", "完成度未知"))
            }
        }
        .font(MusesTypography.caption2.monospacedDigit())
        .foregroundStyle(BrandColors.textSecondary)
    }
}

private struct HistoryMetricCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(MusesTypography.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(BrandColors.textPrimary)
            Text(label)
                .font(MusesTypography.caption)
                .foregroundStyle(BrandColors.textSecondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

enum ListeningFormat {
    static func duration(_ ms: Int) -> String {
        let seconds = max(0, ms / 1000)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}
