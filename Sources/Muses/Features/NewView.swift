import SwiftUI

/// Apple Music New composition: landscape editorial cards, an adaptive song
/// matrix, and square discovery shelves.
struct NewView: View {
    @Environment(SituationalRecommendationService.self) private var situational
    @Environment(PlaybackService.self) private var playback
    @Environment(LibraryService.self) private var library
    @Environment(YouTubeAccountService.self) private var youTubeAccount
    @Environment(YouTubeSearchService.self) private var youTubeSearch

    private enum DiscoverySource: String { case all, library, account, subscriptions }
    @State private var discoverySource: DiscoverySource = .all
    @State private var sections: [SituationalSection] = []
    @State private var newTracks: [TrackSnapshot] = []
    @State private var personalSections: [HomeSection] = []
    @State private var recommendationsLoading = true
    @State private var recommendationTask: Task<Void, Never>?
    @State private var galleryPreview: GalleryMediaPreview?
    @State private var playbackError: String?
    @State private var personalTask: Task<Void, Never>?

    private var featuredTracks: [TrackSnapshot] {
        discoverySource == .account ? [] : Array(newTracks.prefix(3))
    }

    private var bestNewTracks: [TrackSnapshot] {
        guard discoverySource != .account else { return [] }
        let remainder = Array(newTracks.dropFirst(featuredTracks.count).prefix(12))
        return remainder.isEmpty ? Array(newTracks.prefix(12)) : remainder
    }

    private var featuredPersonalCards: [YouTubeDiscoveryCard] {
        visiblePersonalSections
            .flatMap(\.items)
            .compactMap { item in
                if case .youTube(let card) = item { return card }
                return nil
            }
            .prefix(3)
            .map { $0 }
    }

    private var visiblePersonalSections: [HomeSection] {
        discoverySource == .library ? [] : personalSections
    }

    private var hasContent: Bool {
        (discoverySource != .account && !newTracks.isEmpty) || !visiblePersonalSections.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppleMusicSpacing.section) {
                Text(SidebarSection.new.title)
                    .font(MusesTypography.pageTitle)
                    .foregroundStyle(BrandColors.heading)
                    .padding(.horizontal, AppleMusicTokens.contentPaddingX)

                Menu {
                    Button(tr("All discovery sources", "全部发现来源")) { discoverySource = .all }
                    Button(tr("Library rediscovery", "资料库重发现")) { discoverySource = .library }
                    Button(tr("Account recommendations", "账号推荐")) { discoverySource = .account }
                    Divider()
                    Button(tr("Subscribed channels", "订阅频道")) { discoverySource = .subscriptions }
                } label: {
                    Label(tr("Discovery source", "发现来源"), systemImage: "line.3.horizontal.decrease")
                }
                .menuStyle(.borderlessButton).fixedSize()
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)

                Text(tr("Library rediscovery and account-based recommendations. These are not a release-date chart.",
                        "资料库重发现与基于账号的推荐，并非按发行日期排列的新歌榜。"))
                    .font(MusesTypography.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AppleMusicTokens.contentPaddingX)

                if let playbackError {
                    Text(playbackError).font(.callout).foregroundStyle(.secondary)
                        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
                }
                if discoverySource == .subscriptions {
                    subscriptionDiscovery
                } else if recommendationsLoading && !hasContent {
                    loadingState
                } else if hasContent {
                    editorialSection

                    if !bestNewTracks.isEmpty {
                        bestNewSongs
                    }

                    ForEach(visiblePersonalSections) { section in
                        personalShelf(section)
                    }

                    if discoverySource != .account {
                        ForEach(Array(sections.dropFirst())) { section in
                            trackShelf(section)
                        }
                    }
                } else if discoverySource == .account {
                    ContentUnavailableView {
                        Label(youTubeAccount.isConnected ? tr("No account recommendations", "暂无账号推荐") : tr("Connect YouTube", "连接 YouTube"),
                              systemImage: "person.crop.circle")
                    } description: {
                        Text(tr("Recommendations use the connected account’s likes and subscription signals.",
                                "推荐使用已连接账号的喜欢与订阅线索。"))
                    } actions: {
                        Button(tr("Account Settings", "账号设置")) {
                            NotificationCenter.default.post(name: .musesOpenSettings, object: SettingsCategory.youtube)
                        }
                    }
                } else {
                    emptyState
                }
            }
            .padding(.top, AppleMusicSpacing.browseTitleTop)
            .padding(.bottom, AppleMusicTokens.scrollBottomInset)
        }
        .background(BrowseBackground())
        .galleryMediaPreview(item: $galleryPreview)
        .onAppear {
            loadRecommendations()
            loadPersonalDiscovery()
        }
        .onDisappear {
            recommendationTask?.cancel()
            recommendationTask = nil
            personalTask?.cancel()
            personalTask = nil
        }
        .onChange(of: library.likedRevision) { _, _ in loadRecommendations() }
        .onChange(of: library.metadataRevision) { _, _ in loadRecommendations() }
        .onChange(of: library.playRevision) { _, _ in loadRecommendations() }
        .onChange(of: youTubeAccount.isConnected) { _, _ in loadPersonalDiscovery() }
        .onChange(of: youTubeAccount.activeChannelID) { _, _ in loadPersonalDiscovery() }
    }

    @ViewBuilder
    private var subscriptionDiscovery: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: tr("Subscribed channels", "订阅频道"),
                          subtitle: tr("Only channels from your connected YouTube account", "仅显示已连接 YouTube 账号的订阅频道"))
            if !youTubeAccount.isConnected {
                ContentUnavailableView {
                    Label(tr("Connect YouTube", "连接 YouTube"), systemImage: "person.crop.circle")
                } description: {
                    Text(tr("Connect to browse discovery from your subscriptions.", "连接账号后，从订阅频道发现内容。"))
                } actions: {
                    Button(tr("Account Settings", "账号设置")) {
                        NotificationCenter.default.post(name: .musesOpenSettings, object: SettingsCategory.youtube)
                    }
                }
            } else {
                if youTubeAccount.subscriptionsState.isLoading { ProgressView() }
                if let message = youTubeAccount.subscriptionsState.errorMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
                let channels = youTubeAccount.subscriptionsState.value ?? []
                if channels.isEmpty && !youTubeAccount.subscriptionsState.isLoading {
                    ContentUnavailableView {
                        Label(tr("No subscribed channels available", "暂无可用的订阅频道"), systemImage: "person.crop.rectangle.stack")
                    } actions: {
                        Button(tr("Refresh", "刷新")) { Task { await youTubeAccount.refresh() } }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .top)], spacing: 24) {
                        ForEach(channels, id: \.channelId) { channel in
                            AlbumObjectView(title: channel.title, subtitle: tr("Subscribed channel", "已订阅频道"),
                                            artwork: .resolve(remoteURL: channel.thumbnailURL), size: 164,
                                            isYouTube: true, showsHoverPlay: false,
                                            onSelect: {
                                                NotificationCenter.default.post(name: .musesNavigateFromSearch,
                                                    object: GlobalSearchRoute.channel(channel.channelId))
                                            }, onPlay: {})
                        }
                    }
                    Button(tr("Refresh subscriptions", "刷新订阅")) { Task { await youTubeAccount.refresh() } }
                        .disabled(youTubeAccount.subscriptionsState.isLoading)
                }
            }
        }.padding(.horizontal, AppleMusicTokens.contentPaddingX)
    }

    @ViewBuilder
    private var editorialSection: some View {
        if !featuredTracks.isEmpty || !featuredPersonalCards.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: tr("Featured", "精选"))
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 20) {
                        ForEach(featuredTracks) { snapshot in
                            EditorialCard(
                                eyebrow: tr("From your library", "来自资料库"),
                                title: snapshot.title,
                                subtitle: SongCreditCache.shared.artist(snapshot: snapshot),
                                artwork: ArtworkSource.resolve(for: snapshot),
                                onOpen: { openPreview(snapshot, context: newTracks) },
                                onPlay: { play(snapshot, context: newTracks) }
                            )
                            .trackContextMenu(snapshot: snapshot, onPlay: {
                                play(snapshot, context: newTracks)
                            }, videoContext: newTracks, videoSource: .songs, showsMenuButton: true, menuButtonAlignment: .bottomLeading,
                               menuButtonTrailingInset: 0)
                        }
                        if featuredTracks.isEmpty {
                            ForEach(Array(featuredPersonalCards.enumerated()), id: \.offset) { _, card in
                                EditorialCard(
                                    eyebrow: "YouTube Music",
                                    title: card.title,
                                    subtitle: card.uploader ?? "YouTube Music",
                                    artwork: ArtworkSource.resolve(
                                        remoteURL: card.thumbnailURL,
                                        youTubeId: card.id),
                                    onOpen: { openPreview(card, siblings: featuredPersonalCards) },
                                    onPlay: { Task { await play(card) } }
                                )
                                .youTubeEntryContextMenu(card: card, videoContext: featuredPersonalCards, showsMenuButton: true,
                                                        menuButtonAlignment: .bottomLeading,
                                                        menuButtonTrailingInset: 0) {
                                    Task { await play(card) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppleMusicTokens.contentPaddingX)
                }
            }
        }
    }

    private var bestNewSongs: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: tr("Rediscover your library", "重新发现资料库"))
            LazyVGrid(
                columns: [GridItem(
                    .adaptive(
                        minimum: NewPagePolicy.compactSongColumnMinimum,
                        maximum: 430
                    ),
                    spacing: 18,
                    alignment: .top
                )],
                alignment: .leading,
                spacing: 0
            ) {
                ForEach(bestNewTracks) { snapshot in
                    CompactDiscoveryTrackRow(snapshot: snapshot, videoContext: bestNewTracks) {
                        play(snapshot, context: bestNewTracks)
                    }
                    .trackContextMenu(snapshot: snapshot, onPlay: {
                        play(snapshot, context: bestNewTracks)
                    }, videoContext: bestNewTracks, videoSource: .songs)
                }
            }
            .padding(.horizontal, AppleMusicTokens.contentPaddingX)
        }
    }

    private func trackShelf(_ section: SituationalSection) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: section.title, subtitle: [section.subtitle, tr("Library rediscovery", "资料库重发现")].compactMap { $0 }.joined(separator: " · "))
            ResponsiveCarousel(cardSize: MusicObjectMetrics.albumRail, spacing: 18) {
                ForEach(Array(section.items.filter { !$0.youTubeId.isEmpty }.enumerated()), id: \.offset) { _, snapshot in
                    AlbumObjectView(
                        title: snapshot.title,
                        subtitle: SongCreditCache.shared.artist(snapshot: snapshot),
                        artwork: ArtworkSource.resolve(for: snapshot),
                        size: MusicObjectMetrics.albumRail,
                        role: .browse,
                        videoEntry: .init(id: snapshot.youTubeId, title: snapshot.title, uploader: snapshot.artist, duration: snapshot.durationSeconds),
                        videoContext: section.items, videoSource: .songs,
                        isYouTube: true,
                        nowPlayingID: snapshot.id,
                        showsHoverPlay: true,
                        onSelect: { openPreview(snapshot, context: section.items) },
                        onPlay: { play(snapshot, context: section.items) }
                    )
                    .trackContextMenu(snapshot: snapshot, onPlay: {
                        play(snapshot, context: section.items)
                    }, videoContext: section.items, videoSource: .songs, showsMenuButton: true)
                }
            }
        }
    }

    @ViewBuilder
    private func personalShelf(_ section: HomeSection) -> some View {
        let cards = section.items.compactMap { item -> YouTubeDiscoveryCard? in
            if case .youTube(let card) = item { return card }
            return nil
        }
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: section.localizedTitle, subtitle: [section.localizedSubtitle, section.source.label].compactMap { $0 }.joined(separator: " · "))
                ResponsiveCarousel(cardSize: MusicObjectMetrics.albumRail, spacing: 18) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        AlbumObjectView(
                            title: card.title,
                            subtitle: card.uploader ?? "YouTube Music",
                            artwork: ArtworkSource.resolve(
                                remoteURL: card.thumbnailURL,
                                youTubeId: card.id),
                            size: MusicObjectMetrics.albumRail,
                            role: .browse,
                            videoEntry: .init(id: card.playableVideoID ?? card.id, title: card.title, uploader: card.uploader, duration: card.duration),
                            videoEntries: cards.compactMap { sibling in
                                guard let id = sibling.playableVideoID else { return nil }
                                return .init(id: id, title: sibling.title, uploader: sibling.uploader, duration: sibling.duration)
                            },
                            isYouTube: true,
                            showsHoverPlay: true,
                            onSelect: { openPreview(card, siblings: cards) },
                            onPlay: { Task { await play(card, siblings: cards) } }
                        )
                        .youTubeEntryContextMenu(card: card, videoContext: cards, showsMenuButton: true) {
                            Task { await play(card, siblings: cards) }
                        }
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: tr("Featured", "精选"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(0..<2, id: \.self) { _ in
                            SkeletonBlock(
                                width: AppleMusicTokens.editorialWidth,
                                height: AppleMusicTokens.editorialHeight
                            )
                        }
                    }
                    .padding(.horizontal, AppleMusicTokens.contentPaddingX)
                }
            }
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: tr("Rediscover your library", "重新发现资料库"))
                LazyVGrid(
                    columns: [GridItem(.adaptive(
                        minimum: NewPagePolicy.compactSongColumnMinimum,
                        maximum: 430
                    ), spacing: 18)],
                    spacing: 10
                ) {
                    ForEach(0..<8, id: \.self) { _ in
                        SkeletonBlock(width: 300, height: 56)
                    }
                }
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(MusesTypography.system(size: 30, weight: .semibold))
                .foregroundStyle(BrandColors.textSecondary)
            Text(tr("Play more to shape New", "播放更多内容来塑造“新发现”"))
                .font(MusesTypography.headline)
                .foregroundStyle(BrandColors.textPrimary)
            Text(tr(
                "Recommendations use your YouTube library, likes, and listening history.",
                "推荐内容基于你的 YouTube 资料库、喜欢和收听历史。"
            ))
            .font(MusesTypography.subheadline)
            .foregroundStyle(BrandColors.textSecondary)
            Button(tr("Open Search", "打开搜索")) {
                NotificationCenter.default.post(name: .musesFocusSearch, object: nil)
            }
            .musesAction(prominent: true)
            .tint(BrandColors.accent)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private func loadRecommendations() {
        recommendationTask?.cancel()
        recommendationsLoading = true
        recommendationTask = Task {
            let result = await situational.compute()
            guard !Task.isCancelled else { return }
            sections = result
            newTracks = deduplicatedYouTubeTracks(result.flatMap(\.items))
            recommendationsLoading = false
        }
    }

    private func loadPersonalDiscovery() {
        personalTask?.cancel()
        let liked = youTubeAccount.account?.likedVideos ?? []
        let subscriptions = youTubeAccount.account?.subscriptions.map(\.title) ?? []
        guard youTubeAccount.isConnected, (!liked.isEmpty || !subscriptions.isEmpty) else {
            personalSections = []
            return
        }
        let channelID = youTubeAccount.activeChannelID
        personalTask = Task {
            let result = await YouTubePersonalDiscovery.sections(
                liked: liked,
                subscriptionTitles: subscriptions,
                fetchMix: { url in try await youTubeSearch.fetchPlaylist(url: url) },
                search: { query in try await youTubeSearch.search(query: query, limit: 12) }
            )
            guard !Task.isCancelled, channelID == youTubeAccount.activeChannelID else { return }
            personalSections = result
        }
    }

    private func deduplicatedYouTubeTracks(_ tracks: [TrackSnapshot]) -> [TrackSnapshot] {
        var seen = Set<String>()
        return tracks.filter { snapshot in
            guard !snapshot.youTubeId.isEmpty else { return false }
            return seen.insert(snapshot.youTubeId).inserted
        }
    }

    private func openPreview(_ snapshot: TrackSnapshot, context: [TrackSnapshot]) {
        galleryPreview = .init(id: snapshot.id.uuidString, title: snapshot.title,
            subtitle: SongCreditCache.shared.artist(snapshot: snapshot), artwork: .resolve(for: snapshot),
            duration: snapshot.durationSeconds, onPlay: { play(snapshot, context: context) })
    }

    private func openPreview(_ card: YouTubeDiscoveryCard, siblings: [YouTubeDiscoveryCard]) {
        galleryPreview = .init(id: card.id, title: card.title, subtitle: card.uploader ?? "YouTube Music",
            artwork: .resolve(remoteURL: card.thumbnailURL, youTubeId: card.playableVideoID),
            duration: card.duration, onPlay: { Task { await play(card, siblings: siblings) } })
    }

    private func play(_ snapshot: TrackSnapshot, context: [TrackSnapshot]) {
        let playable = deduplicatedYouTubeTracks(context)
        playback.playTrack(
            snapshot,
            context: playable.isEmpty ? [snapshot] : playable,
            from: .songs
        )
        PlaybackPresentation.nowPlaying()
    }

    private func play(_ card: YouTubeDiscoveryCard,
                      siblings: [YouTubeDiscoveryCard]? = nil) async {
        guard let videoID = card.playableVideoID else {
            playbackError = tr("This item has no available playback identity.", "此内容没有可用的播放身份。")
            return
        }
        let entry = YTDlpBridge.YTDlpPlaylistEntry(
            id: videoID,
            title: card.title,
            uploader: card.uploader,
            duration: card.duration
        )
        do {
            let snapshot = try await youTubeSearch.resolveTrack(entry: entry)
            guard !Task.isCancelled else { return }
            let entries = (siblings ?? featuredPersonalCards).compactMap { sibling -> YTDlpBridge.YTDlpPlaylistEntry? in
                guard let siblingVideoID = sibling.playableVideoID else { return nil }
                return YTDlpBridge.YTDlpPlaylistEntry(
                    id: siblingVideoID, title: sibling.title,
                    uploader: sibling.uploader, duration: sibling.duration)
            }
            let context = TrackSnapshot.playbackContext(
                playing: snapshot,
                youTubeEntries: entries
            )
            playbackError = nil
            playback.playTrack(snapshot, context: context, from: .search)
            PlaybackPresentation.nowPlaying()
        } catch {
            guard !Task.isCancelled else { return }
            playbackError = tr("This item could not be prepared. Try Play again.", "无法准备此内容，请再次点击播放重试。")
        }
    }
}

private struct CompactDiscoveryTrackRow: View {
    let snapshot: TrackSnapshot
    var videoContext: [TrackSnapshot] = []
    let onPlay: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 11) {
                ArtworkView(
                    source: ArtworkSource.resolve(for: snapshot),
                    cornerRadius: 5,
                    glyphSize: 16,
                    targetSize: 42
                )
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.title)
                        .font(MusesTypography.system(size: 14, weight: .medium))
                        .foregroundStyle(BrandColors.textPrimary)
                        .lineLimit(1)
                    Text(SongCreditCache.shared.artist(snapshot: snapshot))
                        .font(MusesTypography.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                NowPlayingMark(itemID: snapshot.id)
                    .font(MusesTypography.caption)
                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 8)
            .frame(height: 58)
            .background(hovering ? BrandColors.surface.opacity(0.7) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.fullAreaPlain)
        .overlay(alignment: .trailing) {
            YouTubeVideoButton(entry: .init(id: snapshot.youTubeId, title: snapshot.title, uploader: snapshot.artist, duration: snapshot.durationSeconds),
                               context: videoContext, source: .songs)
                .padding(.trailing, 8)
        }
        .onHover { hovering = $0 }
        .animation(MusesMotion.hoverAnimation(reduceMotion: reduceMotion), value: hovering)
        .overlay(alignment: .bottom) {
            Rectangle().fill(BrandColors.hairline).frame(height: 1)
        }
        .accessibilityLabel("\(snapshot.title), \(SongCreditCache.shared.artist(snapshot: snapshot))")
        .accessibilityHint(tr("Play", "播放"))
    }
}
