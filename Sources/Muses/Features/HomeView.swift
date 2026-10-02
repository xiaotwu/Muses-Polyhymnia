import AppKit
import SwiftData
import SwiftUI

/// YouTube Music Home information architecture in Muses' native visual system.
struct HomeView: View {
    @Environment(LibraryService.self) var library
    @Environment(PlaybackService.self) var playback
    @Environment(YouTubeSearchService.self) var youTubeSearch
    @Environment(HomeDiscoveryService.self) var discovery
    @Environment(WebHomeSessionController.self) var webHome
    @Environment(YouTubeAccountService.self) var youTubeAccount
    @Environment(GlobalSearchService.self) var globalSearch
    @Query(sort: \YouTubeImport.importedAt, order: .reverse) var imports: [YouTubeImport]

    @State var galleryPreview: GalleryMediaPreview?
    @State var homeSourceSelection: HomeSourceSelection = .recommended
    @State var recentlyPlayed: [TrackSnapshot] = []
    @State var fallbackEntries: [YTDlpBridge.YTDlpPlaylistEntry] = []
    @State var fallbackLoading = false
    @State var fallbackError: String?
    @State var interactionError: String?
    @State var fallbackTask: Task<Void, Never>?
    @State var accountChangeTask: Task<Void, Never>?

    var activeImports: [YouTubeImport] {
        imports.filter { $0.deletedAt == nil }
    }

    var supportedRecent: [TrackSnapshot] {
        recentlyPlayed.filter { !$0.youTubeId.isEmpty }
    }

    var remoteTopPickItems: [DiscoveryItem] {
        let remote = visibleDiscoverySections.flatMap(\.items).filter(isPresentableDiscoveryItem)
        let fallback = fallbackEntries.map {
            DiscoveryItem.youTube(YouTubeDiscoveryCard(entry: $0))
        }
        return remote.isEmpty ? fallback : remote
    }

    var topPickItems: [DiscoveryItem] {
        TopPicksResolver.picks(
            hero: nil,
            mixed: remoteTopPickItems,
            recent: homeSourceSelection == .recommended ? supportedRecent.map(DiscoveryItem.track) : [],
            max: 6
        )
    }

    var firstVisibleDiscoverySectionID: String? {
        discovery.sections.first { !$0.items.filter(isPlayableDiscoveryItem).isEmpty }?.id
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: AppleMusicSpacing.section) {
                    Text(tr("Home", "首页"))
                        .font(MusesTypography.pageTitle)
                        .foregroundStyle(BrandColors.heading)
                        .padding(.horizontal, AppleMusicTokens.contentPaddingX)

                    homeSourceStatus

                    moodChips

                    if discovery.isShowingStale {
                        staleBanner
                    }

                    if shouldShowWebRecovery {
                        webRecoveryBanner
                    }

                    if let interactionError {
                        DiscoveryFailureStrip(
                            message: interactionError,
                            onRetry: {
                                self.interactionError = nil
                                discovery.reload()
                            }
                        )
                        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
                    }

                    if homeSourceSelection != .imports {
                        if visibleDiscoverySections.isEmpty,
                           homeSourceSelection == .account || homeSourceSelection == .publicDiscovery,
                           !discovery.isRefreshing {
                            ContentUnavailableView {
                                Label(homeSourceSelection.title, systemImage: homeSourceSelection == .account ? "person.crop.circle" : "globe")
                            } description: {
                                Text(homeSourceSelection == .account
                                     ? tr("No account recommendations are available. Personalized Web Home requires its own browser consent.",
                                          "暂无可用的账号推荐。个性化 Web 首页需要独立的浏览器同意。")
                                     : tr("No public recommendations are available right now.", "暂时没有可用的公共推荐。"))
                            } actions: {
                                Button(homeSourceSelection == .account ? tr("Account Settings", "账号设置") : tr("Retry", "重试")) {
                                    if homeSourceSelection == .account { openHomeAccountSettings() }
                                    else { discovery.reload() }
                                }
                            }
                        } else {
                            homeSpotlight
                            topPicks
                            discoveryShelves
                        }
                        PodcastContinueShelf()
                    }

                    if homeSourceSelection == .imports || (homeSourceSelection == .recommended && !activeImports.isEmpty) {
                        if activeImports.isEmpty {
                            ContentUnavailableView {
                                Label(tr("No imported playlists", "暂无已导入歌单"), systemImage: "music.note.list")
                            } description: {
                                Text(tr("Import a YouTube playlist from All Playlists.", "从全部歌单导入 YouTube 歌单。"))
                            } actions: {
                                Button(tr("Open Playlists", "打开歌单")) {
                                    NotificationCenter.default.post(name: .musesNavigateFromSearch, object: GlobalSearchRoute.section(.playlists))
                                }
                            }
                        } else { importedPlaylistsShelf }
                    }
                }
                .padding(.top, AppleMusicSpacing.browseTitleTop)
                .padding(.bottom, AppleMusicTokens.scrollBottomInset)
                .id("home-top")
            }
            .defaultScrollAnchor(.top)
            .onAppear { reader.scrollTo("home-top", anchor: .top) }
            .onReceive(NotificationCenter.default.publisher(for: .musesHomeScrollToTop)) { _ in
                reader.scrollTo("home-top", anchor: .top)
            }
        }
        .background(BrowseBackground())
        .galleryMediaPreview(item: $galleryPreview)
        .onAppear {
            if discovery.recommendationMode == .youtubeMusic {
                homeSourceSelection = .publicDiscovery
            }
            refreshRecentlyPlayed()
            if discovery.isEnabled {
                discovery.load()
            } else {
                loadFallback()
            }
        }
        .onDisappear {
            fallbackTask?.cancel()
            fallbackTask = nil
            accountChangeTask?.cancel()
            accountChangeTask = nil
            discovery.cancel()
        }
        .onChange(of: library.playRevision) { _, _ in
            refreshRecentlyPlayed()
            refreshLocalRecommendationsIfNeeded()
        }
        .onChange(of: library.likedRevision) { _, _ in
            refreshLocalRecommendationsIfNeeded()
        }
        .onChange(of: library.metadataRevision) { _, _ in
            refreshRecentlyPlayed()
            refreshLocalRecommendationsIfNeeded()
        }
        .onChange(of: youTubeAccount.activeChannelID) { _, _ in
            discovery.accountScopeWillChange()
            accountChangeTask?.cancel()
            accountChangeTask = Task {
                await webHome.accountDidChange()
                guard !Task.isCancelled else { return }
                discovery.resumeAfterAccountScopeChange()
            }
        }
    }

    private func refreshLocalRecommendationsIfNeeded() {
        guard discovery.recommendationMode == .muses else { return }
        discovery.reload()
    }

}

struct YouTubeHomeMood: Identifiable {
    let id: String
    let en: String
    let zh: String
    let searchQuery: String

    var localizedTitle: String { tr(en, zh) }

    static let all: [YouTubeHomeMood] = [
        .init(id: "podcasts", en: "Podcasts", zh: "播客", searchQuery: "music podcasts"),
        .init(id: "energize", en: "Energize", zh: "活力", searchQuery: "energizing music"),
        .init(id: "feel-good", en: "Feel good", zh: "好心情", searchQuery: "feel good music"),
        .init(id: "workout", en: "Workout", zh: "健身", searchQuery: "workout music"),
        .init(id: "relax", en: "Relax", zh: "放松", searchQuery: "relaxing music"),
        .init(id: "party", en: "Party", zh: "派对", searchQuery: "party music"),
        .init(id: "commute", en: "Commute", zh: "通勤", searchQuery: "commute music"),
        .init(id: "focus", en: "Focus", zh: "专注", searchQuery: "focus music"),
        .init(id: "romance", en: "Romance", zh: "浪漫", searchQuery: "romantic music"),
        .init(id: "sad", en: "Sad", zh: "伤感", searchQuery: "sad songs"),
        .init(id: "sleep", en: "Sleep", zh: "睡眠", searchQuery: "sleep music")
    ]
}

struct HomeDiscoveryEmptyState: View {
    let onSearch: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Start your next listen", "开始下一次聆听"))
                .font(MusesTypography.headline)
                .foregroundStyle(BrandColors.textPrimary)
            Text(tr("Search YouTube Music or retry discovery to fill this page.",
                    "搜索 YouTube Music，或重试发现内容来丰富此页面。"))
                .font(MusesTypography.subheadline)
                .foregroundStyle(BrandColors.textSecondary)
            HStack(spacing: 10) {
                Button(tr("Search", "搜索"), systemImage: "magnifyingglass", action: onSearch)
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Search", "搜索"))
                Button(tr("Retry", "重试"), systemImage: "arrow.clockwise", action: onRetry)
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Retry", "重试"))
            }
            .musesAction()
            .tint(BrandColors.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColors.surface,
                    in: RoundedRectangle(cornerRadius: AppleMusicTokens.cardCorner,
                                         style: .continuous))
    }
}

struct DiscoveryFailureStrip: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(BrandColors.textSecondary)
            Text(message)
                .font(MusesTypography.subheadline)
                .foregroundStyle(BrandColors.textSecondary)
            Spacer()
            Button(tr("Retry", "重试"), systemImage: "arrow.clockwise", action: onRetry)
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Retry", "重试"))
                .musesAction()
                .tint(BrandColors.accent)
        }
        .padding(14)
        .background(BrandColors.surface,
                    in: RoundedRectangle(cornerRadius: AppleMusicTokens.cardCorner,
                                         style: .continuous))
    }
}

/// An explicit public-discovery fallback when the provider returned content
/// that could not be verified as music. This is intentionally distinct from
/// both a successful empty result and a transport failure.
struct DiscoveryUnavailableShelf: View {
    let title: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(BrandColors.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MusesTypography.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.textPrimary)
                Text(tr(
                    "No reliable YouTube Music results are available right now.",
                    "暂时没有可靠的 YouTube Music 结果。"))
                    .font(MusesTypography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
            }
            Spacer()
            Button(tr("Retry", "重试"), systemImage: "arrow.clockwise", action: onRetry)
                .labelStyle(ActionIconLabelStyle())
                .help(tr("Retry", "重试"))
                .musesAction()
                .controlSize(.small)
        }
        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
