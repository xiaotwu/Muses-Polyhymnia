import AppKit
import SwiftUI

extension HomeView {
    /// An application editorial role using the first playable item in source order.
    /// No release-date or external editorial classification is inferred.
    var spotlightSelection: (item: DiscoveryItem, provenance: String)? {
        for section in visibleDiscoverySections {
            if let item = section.items.first(where: isPlayableDiscoveryItem) {
                return (item, sourceAwareSubtitle(section))
            }
        }
        if homeSourceSelection == .recommended, let snapshot = supportedRecent.first {
            return (.track(snapshot), tr("Your library · recently played", "你的资料库 · 最近播放"))
        }
        return nil
    }

    @ViewBuilder
    var homeSpotlight: some View {
        if let selection = spotlightSelection {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: tr("Muses Spotlight", "Muses 聚焦"), subtitle: selection.provenance)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top) {
                        switch selection.item {
                        case .youTube(let card):
                            EditorialCard(eyebrow: tr("Muses Spotlight", "Muses 聚焦"),
                                          title: card.title,
                                          subtitle: webCardSubtitle(card),
                                          artwork: .resolve(remoteURL: card.thumbnailURL, youTubeId: card.playableVideoID),
                                          onOpen: { openWebCard(card) },
                                          onPlay: { Task { await play(card) } })
                                .youTubeEntryContextMenu(card: card, showsMenuButton: true,
                                                        menuButtonAlignment: .bottomLeading) {
                                    Task { await play(card) }
                                }
                        case .track(let snapshot):
                            let context = visibleDiscoverySections.flatMap(\.items).compactMap { item -> TrackSnapshot? in
                                if case .track(let track) = item { return track }
                                return nil
                            }
                            EditorialCard(eyebrow: tr("Muses Spotlight", "Muses 聚焦"),
                                          title: snapshot.title,
                                          subtitle: SongCreditCache.shared.artist(snapshot: snapshot),
                                          artwork: .resolve(for: snapshot),
                                          onOpen: { openPreview(snapshot, context: context.isEmpty ? supportedRecent : context) },
                                          onPlay: { play(snapshot, context: context.isEmpty ? supportedRecent : context) })
                                .trackContextMenu(snapshot: snapshot,
                                                  onPlay: { play(snapshot, context: context.isEmpty ? supportedRecent : context) },
                                                  showsMenuButton: true, menuButtonAlignment: .bottomLeading)
                        }
                    }.padding(.horizontal, AppleMusicTokens.contentPaddingX)
                }
            }
        }
    }

    @ViewBuilder
    var topPicks: some View {
        if !topPickItems.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: tr("Top Picks", "精选推荐"))
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 18) {
                        ForEach(topPickItems) { item in
                            portraitCard(item)
                                .frame(width: SongGridMetrics.maxCard)
                        }
                    }
                    .padding(.horizontal, AppleMusicTokens.contentPaddingX)
                }
            }
        } else if discovery.isRefreshing || fallbackLoading || discovery.sections.contains(where: isLoading) {
            portraitSkeletons
        } else {
            HomeDiscoveryEmptyState(onSearch: {
                NotificationCenter.default.post(name: .musesFocusSearch, object: nil)
            }, onRetry: {
                if discovery.isEnabled { discovery.reload() } else { loadFallback() }
            })
            .padding(.horizontal, AppleMusicTokens.contentPaddingX)
        }
    }

    var portraitSkeletons: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: tr("Top Picks", "精选推荐"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonBlock(
                            width: SongGridMetrics.maxCard,
                            height: SongGridMetrics.maxCard + HomeMediaCardMetrics.footerHeight
                        )
                    }
                }
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            }
        }
    }

    @ViewBuilder
    func portraitCard(_ item: DiscoveryItem) -> some View {
        switch item {
        case .youTube(let card):
            SongStationCard(
                title: card.title,
                subtitle: card.uploader ?? "YouTube Music",
                artwork: ArtworkSource.resolve(
                    remoteURL: card.thumbnailURL, youTubeId: card.playableVideoID),
                videoEntry: card.playableVideoID.map { .init(id: $0, title: card.title, uploader: card.uploader, duration: card.duration) },
                isYouTube: true,
                style: card.browseEndpoint?.kind == .channel ? .portraitOverlay : .home,
                showsHoverPlay: card.playableVideoID != nil,
                onOpen: { openWebCard(card) },
                onPlay: { Task { await play(card) } }
            )
            .youTubeEntryContextMenu(card: card, showsMenuButton: true) {
                Task { await play(card) }
            }
        case .track(let snapshot):
            SongStationCard(
                title: snapshot.title,
                subtitle: SongCreditCache.shared.artist(snapshot: snapshot),
                artwork: ArtworkSource.resolve(for: snapshot),
                videoEntry: .init(id: snapshot.youTubeId, title: snapshot.title, uploader: snapshot.artist, duration: snapshot.durationSeconds),
                isYouTube: true,
                nowPlayingID: snapshot.id,
                style: .home,
                onOpen: { openPreview(snapshot, context: supportedRecent) },
                onPlay: { play(snapshot, context: supportedRecent) }
            )
            .trackContextMenu(snapshot: snapshot, onPlay: {
                play(snapshot, context: supportedRecent)
            }, showsMenuButton: true)
        }
    }

    @ViewBuilder
    var discoveryShelves: some View {
        if discovery.isEnabled {
            let sections = visibleDiscoverySections
            let hasLoadedAny = sections.contains { section in
                if case .loaded = section.status { return true }
                return false
            }
            let failedSections = sections.filter { section in
                if case .failed = section.status { return true }
                return false
            }

            if !failedSections.isEmpty && !hasLoadedAny {
                DiscoveryFailureStrip(
                    message: tr("Could not load recommendations right now.", "暂时无法加载推荐内容。"),
                    onRetry: discovery.reload
                )
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            } else if !failedSections.isEmpty && hasLoadedAny {
                DiscoveryFailureStrip(
                    message: tr("Some recommendations could not be loaded.", "部分推荐未能加载。"),
                    onRetry: discovery.reload
                )
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            }

            if discovery.recommendationMode == .muses {
                listenAgainShelf
            }

            ForEach(sections.filter {
                !ListenAgainEmptyPolicy.hidesDiscoverySection(id: $0.id, title: $0.title)
            }) { section in
                discoveryShelf(section, suppressFailureStrip: !failedSections.isEmpty)
            }

            if discovery.hasGlobalContinuation {
                HStack {
                    Spacer()
                    Button {
                        discovery.loadMore()
                    } label: {
                        Label(tr("More recommendations", "更多推荐", zhHant: "更多推薦"),
                              systemImage: "chevron.down")
                    }
                    .musesAction()
                    .disabled(discovery.isLoadingMore || discovery.isRefreshing)
                    .accessibilityLabel(tr("Load more Home recommendations",
                                           "加载更多首页推荐", zhHant: "載入更多首頁推薦"))
                    Spacer()
                }
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            }
            if let error = discovery.globalContinuationError {
                Text(error)
                    .font(MusesTypography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                    .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            }
        } else {
            listenAgainShelf
            if let fallbackError, fallbackEntries.isEmpty {
                DiscoveryFailureStrip(message: fallbackError, onRetry: loadFallback)
                    .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            } else if !fallbackEntries.isEmpty {
                fallbackShelf
            }
        }
    }

    var listenAgainShelf: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: tr("Listen again", "再听一次"))
            if ListenAgainEmptyPolicy.showsRecentCards(hasRecents: !supportedRecent.isEmpty) {
                ResponsiveCarousel(
                    cardSize: MusicObjectMetrics.albumRail,
                    spacing: 18,
                    alignment: .top
                ) {
                    ForEach(supportedRecent) { snapshot in
                        squareCard(
                            .track(snapshot),
                            sectionItems: supportedRecent.map(DiscoveryItem.track)
                        )
                    }
                }
            } else {
                Text(tr(
                    "Play something and it will show up here.",
                    "播放内容后会出现在这里。"
                ))
                .font(MusesTypography.subheadline)
                .foregroundStyle(BrandColors.textSecondary)
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            }
        }
    }

    @ViewBuilder
    func discoveryShelf(_ section: HomeSection, suppressFailureStrip: Bool = false) -> some View {
        let items = section.items.filter(isPresentableDiscoveryItem)
        switch section.status {
        case .loading:
            squareShelfSkeleton(title: section.localizedTitle)
        case .failed(let message):
            if !suppressFailureStrip {
                DiscoveryFailureStrip(
                    message: message ?? tr("This section could not be loaded.", "无法加载此区段。"),
                    onRetry: discovery.reload
                )
                .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            }
        case .idle, .loaded:
            if !items.isEmpty {
                if section.kind == .quickPicks {
                    quickPicksShelf(section, items: items)
                } else {
                    VStack(alignment: .leading, spacing: 13) {
                        discoverySectionHeader(section)
                        ResponsiveCarousel(
                            cardSize: MusicObjectMetrics.albumRail,
                            spacing: 18,
                            alignment: .top
                        ) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                squareCard(item, sectionItems: items)
                            }
                        }
                    }
                }
            }
        }
    }

    func quickPicksShelf(_ section: HomeSection,
                                 items: [DiscoveryItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: section.localizedTitle,
                              subtitle: sourceAwareSubtitle(section))
                Spacer()
                continuationButton(for: section)
                Button(tr("Play all", "全部播放"), systemImage: "play.fill") {
                    playAll(items.filter(isPlayableDiscoveryItem))
                }
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Play all", "全部播放"))
                .musesAction()
                .controlSize(.small)
            }
            .padding(.trailing, AppleMusicTokens.contentPaddingX)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible())],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(items.prefix(8).enumerated()), id: \.offset) { _, item in
                    quickPickRow(item, context: items)
                }
            }
            .padding(.horizontal, AppleMusicTokens.contentPaddingX)
        }
    }

    @ViewBuilder
    func quickPickRow(_ item: DiscoveryItem,
                              context: [DiscoveryItem]) -> some View {
        switch item {
        case .youTube(let card):
            Button { Task { await play(card, siblings: context) } } label: {
                HStack(spacing: 10) {
                    ArtworkView(
                        source: ArtworkSource.resolve(
                            remoteURL: card.thumbnailURL,
                            youTubeId: card.playableVideoID),
                        cornerRadius: 5, glyphSize: 18, targetSize: 48
                    )
                    .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(MusesTypography.system(size: 13, weight: .semibold))
                            .foregroundStyle(BrandColors.textPrimary)
                            .lineLimit(1)
                        Text(card.uploader ?? "YouTube Music")
                            .font(MusesTypography.caption)
                            .foregroundStyle(BrandColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "play.fill")
                        .font(MusesTypography.system(size: 11, weight: .semibold))
                        .foregroundStyle(BrandColors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.fullAreaPlain)
            .youTubeEntryContextMenu(card: card) {
                Task { await play(card, siblings: context) }
            }
        case .track(let snapshot):
            Button { play(snapshot, context: [snapshot]) } label: {
                HStack(spacing: 10) {
                    ArtworkView(source: ArtworkSource.resolve(for: snapshot),
                                cornerRadius: 5, glyphSize: 18, targetSize: 48)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.title).font(MusesTypography.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(SongCreditCache.shared.artist(snapshot: snapshot)).font(MusesTypography.caption)
                            .foregroundStyle(BrandColors.textSecondary).lineLimit(1)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.fullAreaPlain)
        }
    }

    func squareShelfSkeleton(title: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: title)
            ResponsiveCarousel(
                cardSize: MusicObjectMetrics.albumRail,
                spacing: 18,
                alignment: .top
            ) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonCard(size: MusicObjectMetrics.albumRail, aspect: .square)
                }
            }
        }
    }

    @ViewBuilder
    func squareCard(_ item: DiscoveryItem, sectionItems: [DiscoveryItem]) -> some View {
        switch item {
        case .youTube(let card):
            let canPlay = card.playableVideoID != nil
            AlbumObjectView(
                title: card.title,
                subtitle: webCardSubtitle(card),
                artwork: ArtworkSource.resolve(
                    remoteURL: card.thumbnailURL, youTubeId: card.playableVideoID),
                size: MusicObjectMetrics.albumRail,
                role: .browse,
                style: .home,
                videoEntry: card.playableVideoID.map { .init(id: $0, title: card.title, uploader: card.uploader, duration: card.duration) },
                isYouTube: true,
                showsHoverPlay: canPlay,
                onSelect: { openWebCard(card) },
                onPlay: {
                    if canPlay {
                        Task { await play(card, siblings: sectionItems) }
                    } else {
                        openWebCard(card)
                    }
                }
            )
            .youTubeEntryContextMenu(card: card, showsMenuButton: true) {
                Task { await play(card, siblings: sectionItems) }
            }
        case .track(let snapshot):
            let context = sectionItems.compactMap { item -> TrackSnapshot? in
                if case .track(let value) = item { return value }
                return nil
            }
            AlbumObjectView(
                title: snapshot.title,
                subtitle: SongCreditCache.shared.artist(snapshot: snapshot),
                artwork: ArtworkSource.resolve(for: snapshot),
                size: MusicObjectMetrics.albumRail,
                role: .browse,
                style: .home,
                nowPlayingID: snapshot.id,
                showsHoverPlay: true,
                onSelect: { openPreview(snapshot, context: context) },
                onPlay: { play(snapshot, context: context) }
            )
            .trackContextMenu(snapshot: snapshot, onPlay: { play(snapshot, context: context) }, showsMenuButton: true)
        }
    }

    var fallbackShelf: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: tr("Explore on YouTube Music", "探索 YouTube Music"))
            ResponsiveCarousel(
                cardSize: MusicObjectMetrics.albumRail,
                spacing: 18,
                alignment: .top
            ) {
                ForEach(fallbackEntries, id: \.id) { entry in
                    AlbumObjectView(
                        title: entry.title,
                        subtitle: entry.uploader ?? "YouTube Music",
                        artwork: ArtworkSource.resolve(
                            remoteURL: nil, youTubeId: entry.id),
                        size: MusicObjectMetrics.albumRail,
                        role: .play,
                        style: .home,
                        showsHoverPlay: true,
                        onSelect: {},
                        onPlay: { Task { await play(entry) } }
                    )
                    .youTubeEntryContextMenu(entry: entry) {
                        Task { await play(entry) }
                    }
                }
            }
        }
    }

    var importedPlaylistsShelf: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: tr("Imported Playlists", "已导入歌单"))
            ResponsiveCarousel(
                cardSize: MusicObjectMetrics.albumRail,
                spacing: 18,
                alignment: .top
            ) {
                ForEach(activeImports.prefix(12), id: \.id) { imported in
                    AlbumObjectView(
                        title: imported.title,
                        subtitle: imported.channel,
                        artwork: importArtwork(imported),
                        size: MusicObjectMetrics.albumRail,
                        role: .browse,
                        style: .home,
                        showsHoverPlay: true,
                        onSelect: {
                            NotificationCenter.default.post(
                                name: .musesNavigateYouTubeImport, object: imported)
                        },
                        onPlay: { play(imported) }
                    )
                    .contextMenu {
                        Button(tr("Play", "播放"), systemImage: "play.fill") {
                            play(imported)
                        }
                        Button(tr("Open", "打开")) {
                            NotificationCenter.default.post(
                                name: .musesNavigateYouTubeImport, object: imported)
                        }
                        Button {
                            let context = (imported.items ?? []).sorted { $0.order < $1.order }.compactMap(\.track).map(TrackSnapshot.init(from:))
                            if let first = context.first { PlaybackPresentation.video(first, context: context, playback: playback) }
                        } label: {
                            Label {
                                Text(tr("Floating video", "悬浮视频"))
                            } icon: {
                                YouTubeMark(size: 12)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel(tr("Floating video", "悬浮视频"))
                    }
                }
            }
        }
    }

    var moodChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(YouTubeHomeMood.all) { mood in
                    MoodChipButton(title: mood.localizedTitle) {
                        globalSearch.scope = .youtube
                        globalSearch.query = mood.searchQuery
                        NotificationCenter.default.post(name: .musesFocusSearch, object: nil)
                    }
                }
            }
            .padding(.horizontal, AppleMusicTokens.contentPaddingX)
            .padding(.vertical, 2)
        }
        .accessibilityLabel(tr("Moods and activities", "心情与活动"))
    }

    var visibleDiscoverySections: [HomeSection] {
        discovery.sections.filter { section in
            let origin = section.cachedOrigin ?? section.source
            switch homeSourceSelection {
            case .recommended: return true
            case .publicDiscovery: return origin == .publicDiscovery
            case .account: return origin == .signedInWeb || origin == .officialAccount
            case .imports: return false
            }
        }
    }

    var homeSourceStatus: some View {
        Menu {
            Button(tr("Recommended on this Mac", "这台 Mac 上的推荐")) {
                selectHomeSource(.recommended)
            }
            Button(tr("Public discovery", "公共发现")) {
                selectHomeSource(.publicDiscovery)
            }
            Button(tr("Your account", "你的账号")) {
                guard youTubeAccount.isConnected else {
                    openHomeAccountSettings()
                    return
                }
                selectHomeSource(.account)
            }
            Button(tr("Imported playlists", "已导入歌单")) {
                homeSourceSelection = .imports
            }
            Divider()
            Text(homeSourceStatusText)
            if discovery.isShowingStale { Text(staleBannerDetail) }
            if let error = discovery.lastRefreshError { Text(error) }
            Button(tr("Refresh", "刷新")) { discovery.reload() }
                .disabled(homeSourceSelection == .imports || discovery.isRefreshing)
            Button(tr("Account and personalized Home settings…", "账号与个性化首页设置…")) {
                openHomeAccountSettings()
            }
        } label: {
            Label(homeSourceSelection.title, systemImage: homeSourceStatusIcon)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tr("Home source: \(homeSourceSelection.title)", "首页来源：\(homeSourceSelection.title)"))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
        .help(homeSourceStatusText)
    }

    func openHomeAccountSettings() {
        NotificationCenter.default.post(name: .musesOpenSettings, object: SettingsCategory.youtube)
    }

    func selectHomeSource(_ source: HomeSourceSelection) {
        homeSourceSelection = source
        let mode: HomeRecommendationMode = source == .recommended ? .muses : .youtubeMusic
        if mode != discovery.recommendationMode {
            UserDefaults.standard.set(mode.rawValue, forKey: PrefKey.homeRecommendationMode)
            discovery.recommendationModeDidChange()
        }
    }

    var homeSourceStatusText: String {
        if homeSourceSelection == .imports {
            return tr("Playlists already imported into your library; no browser session is required.",
                      "已导入资料库的歌单，无需浏览器会话。")
        }
        if homeSourceSelection == .publicDiscovery {
            return tr("Anonymous public discovery. Account recommendations are shown only in the Account source.",
                      "匿名公共发现；账号推荐仅在账号来源中显示。")
        }
        if discovery.recommendationMode == .muses {
            return tr("Recommended privately on this Mac",
                      "由这台 Mac 私密推荐", zhHant: "由這台 Mac 私密推薦")
        }
        let accountName = youTubeAccount.account?.channel?.title
        switch discovery.webCapability {
        case .available:
            return tr("YouTube Music personalized · " + (accountName ?? "Account"),
                      "YouTube Music 个性化 · " + (accountName ?? "账号"))
        case .saved:
            return tr("Saved YouTube Music personalized · " + (accountName ?? "Account"),
                      "已保存的 YouTube Music 个性化 · " + (accountName ?? "账号"))
        case .unavailable, .rejected:
            return tr("Anonymous YouTube Music discovery · signed-in enhancement unavailable",
                      "匿名 YouTube Music 公共发现 · 登录增强不可用",
                      zhHant: "匿名 YouTube Music 公開探索 · 登入增強不可用")
        case .notConfigured, .signedOut:
            return tr("Anonymous YouTube Music discovery (Public discovery)",
                      "匿名 YouTube Music 公共发现",
                      zhHant: "匿名 YouTube Music 公開探索")
        }
    }

    var homeSourceStatusIcon: String {
        if homeSourceSelection == .imports { return "music.note.list" }
        if homeSourceSelection == .publicDiscovery { return "globe" }
        if discovery.recommendationMode == .muses { return "macbook" }
        return switch discovery.webCapability {
        case .available: "person.crop.circle.fill.badge.checkmark"
        case .saved: "clock.arrow.circlepath"
        case .unavailable, .rejected: "arrow.down.right.circle"
        case .notConfigured, .signedOut:
            youTubeAccount.activeChannelID == nil ? "globe" : "person.crop.circle"
        }
    }

    var staleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
            VStack(alignment: .leading, spacing: 2) {
                Text(isShowingSavedWeb
                     ? tr("Showing saved YouTube Music personalization.",
                          "正在显示已保存的 YouTube Music 个性化内容。")
                     : tr("Showing saved Home recommendations.",
                          "正在显示已保存的首页推荐。"))
                    .font(MusesTypography.caption.weight(.semibold))
                Text(staleBannerDetail)
                    .font(MusesTypography.caption2)
                    .lineLimit(2)
            }
            Spacer()
            Button(tr("Retry", "重试"), systemImage: "arrow.clockwise") { discovery.reload() }
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Retry", "重试"))
                .musesAction()
                .controlSize(.small)
        }
        .foregroundStyle(BrandColors.textSecondary)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(BrandColors.surface,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
    }

    var isShowingSavedWeb: Bool {
        discovery.sections.contains {
            $0.source == .cached && $0.cachedOrigin == .signedInWeb
        }
    }

    var staleBannerDetail: String {
        let updated = discovery.lastUpdatedAt.map {
            tr("Updated \($0.formatted(date: .abbreviated, time: .shortened))",
               "更新于 \($0.formatted(date: .abbreviated, time: .shortened))", zhHant: "更新於 \($0.formatted(date: .abbreviated, time: .shortened))")
        }
        return [updated, discovery.lastRefreshError]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var shouldShowWebRecovery: Bool {
        guard discovery.recommendationMode == .youtubeMusic,
              webHome.isEnabled,
              !isShowingSavedWeb,
              discovery.lastRefreshError != nil else { return false }
        return switch discovery.webCapability {
        case .unavailable, .rejected: true
        default: false
        }
    }

    var webRecoveryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield")
                .font(MusesTypography.system(size: 17, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Personalized Web Home is unavailable",
                        "个性化 Web 首页暂不可用"))
                    .font(MusesTypography.subheadline.weight(.semibold))
                Text(WebHomeRecoveryCopy.message(for: webHome.status))
                    .font(MusesTypography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(tr("Retry", "重试"), systemImage: "arrow.clockwise") { discovery.reload() }
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Retry", "重试"))
                .musesAction()
            Button {
                NotificationCenter.default.post(
                    name: .musesOpenSettings, object: SettingsCategory.youtube)
            } label: {
                MusesSymbol(size: 18)
            }
            .help(tr("Settings", "设置"))
            .accessibilityLabel(tr("Settings", "设置"))
            .musesAction()
        }
        .padding(14)
        .background(BrandColors.surface,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
        .accessibilityElement(children: .contain)
    }

    var accountRefreshFailureBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(MusesTypography.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Some YouTube account data is unavailable",
                        "部分 YouTube 账号数据暂不可用"))
                    .font(MusesTypography.subheadline.weight(.semibold))
                Text(tr(
                    "Saved recommendations remain visible. Retry without signing out.",
                    "已保存的推荐仍会显示；可直接重试，无需退出登录。"))
                    .font(MusesTypography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
            }
            Spacer()
            Button(tr("Retry", "重试"), systemImage: "arrow.clockwise") {
                Task { await youTubeAccount.refresh() }
            }
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Retry", "重试"))
            .musesAction()
        }
        .padding(14)
        .background(BrandColors.surface,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
    }

    func refreshRecentlyPlayed() {
        recentlyPlayed = library.recentlyPlayedTracks(limit: 20)
            .filter { !$0.youTubeId.isEmpty }
    }

    func loadFallback() {
        fallbackTask?.cancel()
        fallbackTask = nil
        fallbackLoading = false
        fallbackEntries = []
        fallbackError = tr("Official discovery is unavailable. Enable discovery or try again later.",
                           "官方发现内容暂不可用，请开启发现功能或稍后重试。",
                           zhHant: "官方探索內容暫不可用，請啟用探索功能或稍後重試。")
    }

    func play(_ snapshot: TrackSnapshot,
                      context: [TrackSnapshot],
                      source: QueueSource = .search) {
        let playableContext = context.isEmpty ? [snapshot] : context
        playback.playTrack(snapshot, context: playableContext, from: source)
        PlaybackPresentation.nowPlaying()
    }

    func play(_ card: YouTubeDiscoveryCard,
                      siblings: [DiscoveryItem]? = nil) async {
        guard let videoID = card.playableVideoID else {
            interactionError = tr(
                "This YouTube Music item is not available for playback.",
                "此 YouTube Music 内容当前不可播放。")
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
            let entries = (siblings ?? itemsContaining(card)).compactMap { item -> YTDlpBridge.YTDlpPlaylistEntry? in
                guard case .youTube(let sibling) = item,
                      let siblingVideoID = sibling.playableVideoID else { return nil }
                return YTDlpBridge.YTDlpPlaylistEntry(
                    id: siblingVideoID,
                    title: sibling.title,
                    uploader: sibling.uploader,
                    duration: sibling.duration
                )
            }
            let context = TrackSnapshot.playbackContext(playing: snapshot, youTubeEntries: entries)
            interactionError = nil
            playback.playTrack(snapshot, context: context, from: .search)
        PlaybackPresentation.nowPlaying()
        } catch {
            interactionError = tr(
                "This YouTube Music item could not be prepared: \(error.localizedDescription)",
                "无法准备此 YouTube Music 内容：\(error.localizedDescription)", zhHant: "無法準備此 YouTube Music 內容：\(error.localizedDescription)"
            )
        }
    }

    func play(_ entry: YTDlpBridge.YTDlpPlaylistEntry) async {
        do {
            let snapshot = try await youTubeSearch.resolveTrack(entry: entry)
            let context = TrackSnapshot.playbackContext(
                playing: snapshot,
                youTubeEntries: fallbackEntries
            )
            interactionError = nil
            playback.playTrack(snapshot, context: context, from: .search)
        PlaybackPresentation.nowPlaying()
        } catch {
            interactionError = tr(
                "This YouTube Music item could not be prepared: \(error.localizedDescription)",
                "无法准备此 YouTube Music 内容：\(error.localizedDescription)", zhHant: "無法準備此 YouTube Music 內容：\(error.localizedDescription)"
            )
        }
    }

    func play(_ imported: YouTubeImport) {
        let snapshots = (imported.items ?? [])
            .sorted { $0.order < $1.order }
            .compactMap(\.track)
            .filter { !$0.youTubeId.isEmpty }
            .map(TrackSnapshot.init(from:))
        guard let first = snapshots.first else {
            interactionError = tr(
                "This playlist has no playable YouTube items.",
                "这个歌单中没有可播放的 YouTube 内容。"
            )
            return
        }
        interactionError = nil
        playback.playTrack(first, context: snapshots, from: .import)
        PlaybackPresentation.nowPlaying()
    }

    func playAll(_ items: [DiscoveryItem]) {
        Task {
            var snapshots: [TrackSnapshot] = []
            var failedTitles: [String] = []
            for item in items {
                switch item {
                case .track(let snapshot):
                    snapshots.append(snapshot)
                case .youTube(let card):
                    guard let videoID = card.playableVideoID else {
                        failedTitles.append(card.title)
                        continue
                    }
                    let entry = YTDlpBridge.YTDlpPlaylistEntry(
                        id: videoID, title: card.title,
                        uploader: card.uploader, duration: card.duration)
                    do {
                        let snapshot = try await youTubeSearch.resolveTrack(entry: entry)
                        snapshots.append(snapshot)
                    } catch {
                        failedTitles.append(card.title)
                    }
                }
            }
            guard let first = snapshots.first else {
                interactionError = tr(
                    "None of these songs could be prepared for playback.",
                    "这些歌曲目前都无法准备播放。"
                )
                return
            }
            interactionError = failedTitles.isEmpty ? nil : tr(
                "Playing available songs. Could not prepare: \(failedTitles.joined(separator: ", "))",
                "正在播放可用歌曲。以下内容无法准备：\(failedTitles.joined(separator: "、"))", zhHant: "正在播放可用歌曲。以下內容無法準備：\(failedTitles.joined(separator: "、"))"
            )
            playback.playTrack(first, context: snapshots, from: .search)
        PlaybackPresentation.nowPlaying()
        }
    }

    func importArtwork(_ imported: YouTubeImport) -> ArtworkSource {
        let firstID = (imported.items ?? []).min(by: { $0.order < $1.order })?.youTubeId
        return ArtworkSource.resolve(
            remoteURL: imported.artworkUrl,
            youTubeId: firstID
        )
    }

    func itemsContaining(_ card: YouTubeDiscoveryCard) -> [DiscoveryItem] {
        discovery.sections.first { section in
            section.items.contains { item in
                guard case .youTube(let candidate) = item else { return false }
                return candidate.id == card.id
            }
        }?.items ?? []
    }

    func isPlayableDiscoveryItem(_ item: DiscoveryItem) -> Bool {
        switch item {
        case .youTube(let card): return card.playableVideoID?.isEmpty == false
        case .track(let snapshot): return !snapshot.youTubeId.isEmpty
        }
    }

    func isPresentableDiscoveryItem(_ item: DiscoveryItem) -> Bool {
        switch item {
        case .youTube(let card): return !card.id.isEmpty
        case .track(let snapshot): return !snapshot.youTubeId.isEmpty
        }
    }

    @ViewBuilder
    func discoverySectionHeader(_ section: HomeSection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader(
                title: section.localizedTitle,
                subtitle: sourceAwareSubtitle(section))
            Spacer()
            continuationButton(for: section)
        }
        .padding(.trailing, AppleMusicTokens.contentPaddingX)
    }

    @ViewBuilder
    func continuationButton(for section: HomeSection) -> some View {
        if discovery.hasContinuation(for: section.id) {
            Button {
                discovery.loadMore(sectionID: section.id)
            } label: {
                Label(tr("More", "更多"), systemImage: "chevron.right.circle")
            }
            .musesAction()
            .controlSize(.small)
            .disabled(discovery.loadingSectionIDs.contains(section.id))
            .help(tr("Load more from this section",
                     "从此区段加载更多内容"))
            .accessibilityLabel(tr("Load more from \(section.title)",
                                   "加载更多：\(section.title)", zhHant: "載入更多：\(section.title)"))
        }
        if let error = discovery.continuationErrors[section.id] {
            Text(error)
                .font(MusesTypography.caption)
                .foregroundStyle(BrandColors.textSecondary)
                .accessibilityLabel(error)
        }
    }

    func openWebCard(_ card: YouTubeDiscoveryCard) {
        if card.playableVideoID != nil {
            galleryPreview = .init(id: card.id, title: card.title,
                subtitle: webCardSubtitle(card),
                artwork: .resolve(remoteURL: card.thumbnailURL, youTubeId: card.playableVideoID),
                duration: card.duration, onPlay: { Task { await play(card) } })
            return
        }
        guard card.availability == .available,
              let endpoint = card.browseEndpoint ?? card.playEndpoint else { return }
        let browseID: String
        let kind: MusicCatalogKind
        switch endpoint.kind {
        case .video: Task { await play(card) }; return
        case .playlist: browseID = endpoint.identifier.hasPrefix("VL") ? endpoint.identifier : "VL" + endpoint.identifier; kind = .playlist
        case .browse: browseID = endpoint.identifier; kind = endpoint.identifier.hasPrefix("MPRE") ? .album : .playlist
        case .channel: browseID = endpoint.identifier; kind = .artist
        }
        globalSearch.reset()
        globalSearch.musicCatalog.browse(MusicCatalogItem(id: "browse:" + browseID, kind: kind,
            title: card.title, subtitle: card.uploader ?? "YouTube Music",
            artwork: card.thumbnailURL.flatMap(URL.init(string:)), artists: [], releases: [], channels: []))
        NotificationCenter.default.post(name: .musesNavigateFromSearch, object: GlobalSearchRoute.section(.search))
    }

    func openPreview(_ snapshot: TrackSnapshot, context: [TrackSnapshot]) {
        galleryPreview = .init(id: snapshot.id.uuidString, title: snapshot.title,
            subtitle: SongCreditCache.shared.artist(snapshot: snapshot),
            artwork: .resolve(for: snapshot), duration: snapshot.durationSeconds,
            onPlay: { play(snapshot, context: context) })
    }

    func webCardSubtitle(_ card: YouTubeDiscoveryCard) -> String {
        let base = card.uploader ?? "YouTube Music"
        let state: String? = switch card.availability {
        case .available: nil
        case .unavailable: tr("Unavailable", "不可用")
        case .regionBlocked: tr("Not available in this region", "此地区不可用")
        case .privateItem: tr("Private", "私密")
        case .deleted: tr("Deleted", "已删除")
        }
        return state.map { "\(base) · \($0)" } ?? base
    }

    func continuationFailureMessage(_ code: HomeFetchFailureCode) -> String {
        switch code {
        case .sessionExpired:
            tr("Your Web session expired. Check it again in YouTube Settings.",
               "Web 会话已过期，请在 YouTube 设置中重新检查。")
        case .accountMismatch:
            tr("The Web session belongs to another channel.",
               "Web 会话属于另一个频道。")
        case .shapeChanged:
            tr("YouTube Music changed this section's response.",
               "YouTube Music 已更改此区段的响应结构。")
        default:
            tr("More recommendations are temporarily unavailable.",
               "暂时无法加载更多推荐。")
        }
    }

    func isLoading(_ section: HomeSection) -> Bool {
        if case .loading = section.status { return true }
        return false
    }

    func sourceAwareSubtitle(_ section: HomeSection) -> String {
        let source: String
        if section.source == .cached {
            let origin = section.cachedOrigin?.label ?? HomeSource.publicDiscovery.label
            source = tr("Saved · \(origin)", "已保存 · \(origin)", zhHant: "已保存 · \(origin)")
        } else {
            source = section.source.label
        }
        guard let subtitle = section.localizedSubtitle, !subtitle.isEmpty,
              !subtitle.localizedCaseInsensitiveContains(source) else { return source }
        return "\(subtitle) · \(source)"
    }
}

enum HomeSourceSelection: String {
    case recommended, publicDiscovery, account, imports
    var title: String {
        switch self {
        case .recommended: tr("Recommended on this Mac", "这台 Mac 上的推荐")
        case .publicDiscovery: tr("Public discovery", "公共发现")
        case .account: tr("Your account", "你的账号")
        case .imports: tr("Imported playlists", "已导入歌单")
        }
    }
}

private struct MoodChipButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .buttonBorderShape(.capsule)
            .frame(minHeight: 28)
    }
}
