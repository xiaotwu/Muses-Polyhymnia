import Foundation
import Observation

/// Home discovery service.
///
/// `@MainActor @Observable`. Exposes `sections: [HomeSection]` and `isEnabled`.
/// `load()` is cache-first: sections from the active mode's partition (possibly stale) render
/// immediately, then refresh in the background. One section failure never poisons the others.
///
/// With `ffDiscovery` off, `load()` is a no-op and `sections` stays empty; HomeView falls back to its existing behavior.
@MainActor
@Observable
final class HomeDiscoveryService {
    /// Current sections from the selected recommendation mode.
    private(set) var sections: [HomeSection] = []
    /// Whether discovery is refreshing in the background.
    private(set) var isRefreshing: Bool = false
    /// Account/input-scoped cache freshness shown by Home.
    private(set) var lastUpdatedAt: Date?
    private(set) var isShowingStale = false
    private(set) var lastRefreshError: String?
    private(set) var activeScope: HomeFeedScope = .guest
    private(set) var activeMode: HomeRecommendationMode = .muses
    private(set) var webCapability: HomeWebCapability = .notConfigured

    private let provider: HomeDiscoveryProvider
    private let cache: HomeFeedCache
    private let library: LibraryService
    private let enabledProvider: () -> Bool
    private let modeProvider: () -> HomeRecommendationMode
    private let accountChannelIDProvider: () -> String?
    private var refreshTask: Task<Void, Never>?
    private var moreTask: Task<Void, Never>?
    /// Invalidates every refresh and continuation when Home leaves, changes mode,
    /// or changes account. A scope check alone is insufficient for guest-to-guest
    /// mode changes because both requests can share the same scope.
    private var operationID = UUID()
    private var morePage = 0
    private(set) var isLoadingMore = false
    private(set) var globalContinuationError: String?
    private(set) var loadingSectionIDs: Set<String> = []
    private(set) var continuationErrors: [String: String] = [:]

    init(provider: HomeDiscoveryProvider,
         cache: HomeFeedCache = .default,
         library: LibraryService,
         enabledProvider: @escaping () -> Bool = { UserDefaults.standard.bool(forKey: PrefKey.ffDiscovery) },
         modeProvider: @escaping () -> HomeRecommendationMode = {
             HomeRecommendationMode(
                rawValue: UserDefaults.standard.string(forKey: PrefKey.homeRecommendationMode) ?? ""
             ) ?? .muses
         },
         accountChannelIDProvider: @escaping () -> String? = { nil }) {
        self.provider = provider
        self.cache = cache
        self.library = library
        self.enabledProvider = enabledProvider
        self.modeProvider = modeProvider
        self.accountChannelIDProvider = accountChannelIDProvider
    }

    var isEnabled: Bool { enabledProvider() }
    var recommendationMode: HomeRecommendationMode { modeProvider() }

    // MARK: - Load

    /// Cache-first load of the selected mode's discovery sections.
    /// - Fill `sections` immediately from cache even when stale (stale-while-revalidate).
    /// - Fresh cache → skip the background spawn.
    /// - Otherwise refresh in the background: the provider yields per-section statuses that merge back into `sections`.
    func load() {
        guard isEnabled else { return }
        let input = buildInput()
        let mode = recommendationMode
        activeMode = mode
        activeScope = input.scope
        let baselineCache = mode == .muses
            ? cache.get(for: input, layer: .baseline, mode: mode) : nil
        let webCache = mode == .youtubeMusic && provider.hasWebEnhancement
            ? cache.get(for: input, layer: .web, mode: mode) : nil
        let selectedCache = mode == .muses ? baselineCache : webCache
        let layer: HomeFeedCache.Layer = mode == .muses ? .baseline : .web

        if let selectedCache {
            let fresh = cache.isFresh(selectedCache, layer: layer)
            sections = selectedCache.value.sections.map {
                $0.presentedFromCache(staleReason: fresh ? nil : "expired")
            }
            lastUpdatedAt = selectedCache.value.fetchedAt
            isShowingStale = !fresh
            if mode == .youtubeMusic, case .account(let channelID) = input.scope {
                webCapability = .saved(accountChannelID: channelID,
                                       stale: !fresh, reason: fresh ? nil : "expired")
            } else {
                webCapability = .notConfigured
            }
            PerfTrace.event("home.discovery.cachedHit")
            if fresh && !provider.needsLiveRefreshForContinuations {
                PerfTrace.event("home.discovery.fresh")
                return
            }
        } else {
            sections = loadingPlaceholders(for: input)
            lastUpdatedAt = nil
            PerfTrace.event("home.discovery.cold")
            isShowingStale = false
            webCapability = initialWebCapability(for: input.scope)
        }
        refresh(input: input)
    }

    func loadMore() {
        let input = buildInput()
        guard isEnabled, recommendationMode == .youtubeMusic, provider.hasWebEnhancement,
              case .account(let channelID) = input.scope, provider.hasGlobalContinuation,
              !isLoadingMore, !isRefreshing, morePage < 12 else { return }
        let page = morePage + 1
        let mode = recommendationMode
        let operation = operationID
        isLoadingMore = true
        globalContinuationError = nil
        moreTask = Task { [weak self] in
            guard let self else { return }
            let extra = await self.provider.more(page: page, input: input)
            guard !Task.isCancelled,
                  operation == self.operationID,
                  mode == self.recommendationMode,
                  self.provider.hasWebEnhancement,
                  input.scope == self.buildInput().scope else {
                return
            }
            if extra.isEmpty {
                self.globalContinuationError = tr(
                    "More Home recommendations are temporarily unavailable.",
                    "暂时无法加载更多首页推荐。",
                    zhHant: "暫時無法載入更多首頁推薦。")
            } else {
                for section in extra where section.source == .signedInWeb
                    && section.accountChannelID == channelID
                    && section.schemaVersion > 0 && section.status == .loaded {
                    if self.sections.contains(where: { $0.id == section.id }) {
                        self.appendContinuation(section.items, to: section.id)
                    } else {
                        let existing = Set(self.sections.flatMap(\.items)
                            .compactMap(\.homeMediaIdentity))
                        let unique = section.items.filter { item in
                            guard let identity = item.homeMediaIdentity else { return true }
                            return !existing.contains(identity)
                        }
                        guard !unique.isEmpty else { continue }
                        let appended = self.replacingItems(in: section, with: unique)
                        self.sections.append(appended)
                    }
                }
                self.morePage = page
            }
            self.isLoadingMore = false
            self.moreTask = nil
        }
    }

    var hasGlobalContinuation: Bool {
        recommendationMode == .youtubeMusic && provider.hasWebEnhancement
            && activeScope != .guest && provider.hasGlobalContinuation && morePage < 12
    }

    func hasContinuation(for sectionID: String) -> Bool {
        recommendationMode == .youtubeMusic && provider.hasWebEnhancement
            && activeScope != .guest && provider.hasContinuation(for: sectionID)
    }

    func loadMore(sectionID: String) {
        guard isEnabled,
              recommendationMode == .youtubeMusic, provider.hasWebEnhancement,
              buildInput().scope != .guest,
              provider.hasContinuation(for: sectionID),
              loadingSectionIDs.insert(sectionID).inserted else { return }
        let input = buildInput()
        let mode = recommendationMode
        let operation = operationID
        Task { [weak self] in
            guard let self else { return }
            let items = await self.provider.more(sectionID: sectionID, input: input)
            guard !Task.isCancelled,
                  operation == self.operationID,
                  self.provider.hasWebEnhancement,
                  input.scope == self.buildInput().scope,
                  mode == self.recommendationMode else {
                self.loadingSectionIDs.remove(sectionID)
                return
            }
            self.appendContinuation(items, to: sectionID)
            if items.isEmpty {
                self.continuationErrors[sectionID] = tr(
                    "This section could not load more items. Try again.",
                    "此区段无法加载更多内容，请重试。",
                    zhHant: "此區段無法載入更多內容，請重試。")
            } else {
                self.continuationErrors.removeValue(forKey: sectionID)
            }
            self.loadingSectionIDs.remove(sectionID)
        }
    }

    /// Cancels the in-flight refresh (page switches cancel).
    func cancel() {
        operationID = UUID()
        refreshTask?.cancel()
        moreTask?.cancel()
        provider.resetContinuations()
        refreshTask = nil
        moreTask = nil
        isRefreshing = false
        isLoadingMore = false
        globalContinuationError = nil
        loadingSectionIDs.removeAll(keepingCapacity: false)
        continuationErrors.removeAll(keepingCapacity: false)
    }

    /// Called when OAuth identity changes. Visible account content is cleared
    /// immediately; the previous account's on-disk cache remains dormant and
    /// can only be reopened by that same channel scope.
    func accountScopeDidChange() {
        guard transitionToCurrentAccountScope() else { return }
        load()
    }

    /// Applies an explicit source change without deleting either source's
    /// saved snapshot. The target cache is read synchronously by `load()`.
    func recommendationModeDidChange() {
        cancel()
        sections = []
        lastUpdatedAt = nil
        isShowingStale = false
        lastRefreshError = nil
        continuationErrors.removeAll(keepingCapacity: false)
        webCapability = .notConfigured
        morePage = 0
        activeMode = recommendationMode
        load()
    }

    /// Clears the old account immediately but deliberately does not start the
    /// new scope until the Web helper cancellation has completed.
    func accountScopeWillChange() {
        _ = transitionToCurrentAccountScope()
    }

    func resumeAfterAccountScopeChange() {
        load()
    }

    /// Forces a full refresh (pull-to-refresh / after settings changes).
    /// Uses async input building (moves the full-table reduce off the main thread); `load()` keeps the synchronous `buildInput()`
    /// to preserve the synchronous cache-hit display contract.
    func reload() {
        guard isEnabled else { return }
        operationID = UUID()
        refreshTask?.cancel()
        moreTask?.cancel()
        moreTask = nil
        isLoadingMore = false
        globalContinuationError = nil
        morePage = 0
        isRefreshing = true
        let operation = operationID
        refreshTask = Task { [weak self] in
            guard let self, !Task.isCancelled, operation == self.operationID else { return }
            let input = await self.buildInputAsync()
            guard !Task.isCancelled, operation == self.operationID else { return }
            self.refresh(input: input)
        }
    }

    /// Applies an opt-in/opt-out change without allowing a disabled Web layer
    /// (or its saved partition) to remain visible in the current feed.
    func webConfigurationDidChange() {
        cancel()
        sections.removeAll {
            $0.source == .signedInWeb || $0.cachedOrigin == .signedInWeb
        }
        if recommendationMode == .youtubeMusic {
            lastUpdatedAt = nil
            isShowingStale = false
            lastRefreshError = nil
        }
        webCapability = initialWebCapability(for: buildInput().scope)
        reload()
    }

    /// Deletes only the active OAuth account's normalized Web partition.
    /// Baseline discovery and every other account partition remain untouched.
    func clearSavedWebHomeForCurrentAccount() {
        let input = buildInput()
        guard case .account = input.scope else { return }
        cache.invalidate(scope: input.scope, layer: .web, mode: .youtubeMusic)
        sections.removeAll {
            $0.source == .signedInWeb || $0.cachedOrigin == .signedInWeb
        }
        webCapability = initialWebCapability(for: input.scope)
        lastRefreshError = nil
        reload()
    }

    /// Adds a normalized, in-memory continuation page to one live Web shelf.
    /// Continuation pages are not written to the durable cache because the
    /// associated token chain is intentionally process-local.
    func appendWebContinuation(_ items: [DiscoveryItem], to sectionID: String) {
        appendContinuation(items, to: sectionID)
    }

    private func appendContinuation(_ items: [DiscoveryItem], to sectionID: String) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        let section = sections[index]
        var seen = Set(section.items.compactMap(\.homeMediaIdentity))
        let extra = items.filter { item in
            guard let identity = item.homeMediaIdentity else { return false }
            return seen.insert(identity).inserted
        }
        guard !extra.isEmpty else { return }
        sections[index] = replacingItems(in: section, with: section.items + extra)
    }

    // MARK: - Internals

    @discardableResult
    private func transitionToCurrentAccountScope() -> Bool {
        let newScope = buildInput().scope
        guard newScope != activeScope else { return false }
        cancel()
        activeScope = newScope
        sections = []
        webCapability = initialWebCapability(for: newScope)
        lastUpdatedAt = nil
        isShowingStale = false
        lastRefreshError = nil
        continuationErrors.removeAll(keepingCapacity: false)
        morePage = 0
        return true
    }

    private func refresh(input: HomeDiscoveryInput) {
        refreshTask?.cancel()
        isRefreshing = true
        let mode = recommendationMode
        let operation = operationID
        refreshTask = Task { [weak self] in
            guard let self else { return }
            // Home never asks YouTube Data API for personalization signals.
            // YouTube Music mode personalizes only through the isolated browser session.
            let result = await self.provider.fetch(for: input)
            guard !Task.isCancelled,
                  operation == self.operationID,
                  input.scope == self.buildInput().scope,
                  mode == self.recommendationMode else { return }
            self.activeScope = input.scope
            self.activeMode = mode
            if mode == .muses {
                let cached = self.cache.get(for: input, layer: .baseline, mode: mode)
                let failure = result.failures.first { $0.layer == .baseline }
                let valid = self.cache.accepts(result.baselineSnapshot, for: input,
                                              layer: .baseline, mode: mode)
                let previous = Dictionary(uniqueKeysWithValues:
                    (cached?.value.sections ?? []).map { ($0.id, $0) })
                var sectionError: String?
                var sections = valid ? result.baselineSnapshot.sections.map { section -> HomeSection in
                    guard case .failed(let reason) = section.status else { return section }
                    sectionError = sectionError ?? reason
                    guard let saved = previous[section.id], !saved.items.isEmpty else { return section }
                    return saved.presentedFromCache(staleReason: reason ?? "refresh failed")
                } : []
                if sections.isEmpty, let failure {
                    sections = cached?.value.sections.map {
                        $0.presentedFromCache(staleReason: failure.message ?? failure.code.rawValue)
                    } ?? []
                }
                if valid, result.cacheDirectives.storeBaseline {
                    _ = self.cache.set(result.baselineSnapshot, for: input, layer: .baseline, mode: mode)
                }
                self.sections = sections
                self.lastUpdatedAt = result.cacheDirectives.storeBaseline && valid
                    ? result.baselineSnapshot.fetchedAt : cached?.value.fetchedAt
                self.isShowingStale = sections.contains { $0.source == .cached || $0.staleReason != nil }
                self.lastRefreshError = failure?.message ?? sectionError
                self.webCapability = .notConfigured
            } else {
                let canUseWeb = self.provider.hasWebEnhancement && input.scope != .guest
                let failure = result.failures.first { $0.layer == .web }
                if canUseWeb, case .account(let channelID) = input.scope,
                   failure == nil, let snapshot = result.webSnapshot,
                   self.cache.accepts(snapshot, for: input, layer: .web, mode: mode) {
                    if result.cacheDirectives.storeWeb {
                        _ = self.cache.set(snapshot, for: input, layer: .web, mode: mode)
                    }
                    self.sections = snapshot.sections
                    self.webCapability = .available(accountChannelID: channelID)
                    self.lastUpdatedAt = snapshot.fetchedAt
                    self.isShowingStale = false
                } else {
                    // Consent and build support gate durable snapshots too. A
                    // failed request may retain only this enabled account's last
                    // verified success, never public or another source's data.
                    let saved = canUseWeb
                        ? self.cache.get(for: input, layer: .web, mode: mode) : nil
                    let reason = failure?.message ?? failure?.code.rawValue
                    self.sections = saved?.value.sections.map {
                        $0.presentedFromCache(staleReason: reason)
                    } ?? []
                    self.lastUpdatedAt = saved?.value.fetchedAt
                    self.isShowingStale = saved != nil
                    if let saved, case .account(let channelID) = input.scope {
                        PerfTrace.event("home.web.stale")
                        self.webCapability = .saved(accountChannelID: channelID, stale: true,
                                                    reason: reason ?? saved.value.staleReason)
                    } else {
                        self.webCapability = canUseWeb ? result.webCapability
                            : self.initialWebCapability(for: input.scope)
                    }
                }
                self.lastRefreshError = canUseWeb ? failure?.message : nil
            }
            self.isRefreshing = false
            PerfTrace.event("home.discovery.refreshed")
        }
    }

    private func replacingItems(
        in section: HomeSection,
        with items: [DiscoveryItem]
    ) -> HomeSection {
        HomeSection(
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            kind: section.kind,
            items: items,
            status: section.status,
            source: section.source,
            cachedOrigin: section.cachedOrigin,
            accountChannelID: section.accountChannelID,
            schemaVersion: section.schemaVersion,
            fetchedAt: section.fetchedAt,
            expiresAt: section.expiresAt,
            staleReason: section.staleReason)
    }

    private func initialWebCapability(for scope: HomeFeedScope) -> HomeWebCapability {
        guard recommendationMode == .youtubeMusic else { return .notConfigured }
        if scope == .guest { return .signedOut }
        guard provider.hasWebEnhancement else { return .notConfigured }
        return .unavailable(reason: nil)
    }

    /// Loading placeholders: prefill with section titles derived from the input (titles come from provider logic, never hardcoded in views).
    private func loadingPlaceholders(for input: HomeDiscoveryInput) -> [HomeSection] {
        if recommendationMode == .muses {
            return [
                HomeSection(id: "muses:on-repeat", title: tr("On Repeat", "循环热播"),
                            kind: .youTubeCarousel, items: [], status: .loading,
                            source: .localLibrary),
                HomeSection(id: "muses:rediscover", title: tr("Rediscover", "重新发现"),
                            kind: .youTubeCarousel, items: [], status: .loading,
                            source: .localLibrary)
            ]
        }
        // Account loading does not invent remote shelf names from local history.
        return []
    }

    // MARK: - Input building

    /// Derives `HomeDiscoveryInput` from library + history (light history signals).
    func buildInput() -> HomeDiscoveryInput {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let band: ListeningContext.TimeBand = {
            switch hour {
            case 5..<12:  return .morning
            case 12..<18: return .afternoon
            case 18..<22: return .evening
            default:       return .lateNight
            }
        }()
        let topArtists = topArtistNames(limit: 5)
        let recentArtists = recentlyPlayedArtistNames(limit: 5)
        let likedArtists = likedArtistNames(limit: 5)
        return HomeDiscoveryInput(
            topArtistNames: topArtists,
            recentlyPlayedArtistNames: recentArtists,
            likedArtistNames: likedArtists,
            timeBand: band,
            hour: hour,
            seedVideoIds: seedVideoIds(),
            scope: HomeFeedScope(accountChannelID: accountChannelIDProvider()))
    }

    private func topArtistNames(limit: Int) -> [String] {
        // Reuses the library playCount aggregation (consistent with RecommendationService).
        let counts = library.allTracks().reduce(into: [String: Int]()) { acc, t in
            guard t.playCount > 0 else { return }
            acc[t.artist, default: 0] += t.playCount
        }
        return counts.sorted { $0.value > $1.value }.prefix(limit).map(\.key)
    }

    private func recentlyPlayedArtistNames(limit: Int) -> [String] {
        library.recentlyPlayedTracks(limit: 50)
            .map(\.artist)
            .deduplicated(limit: limit)
    }

    private func likedArtistNames(limit: Int) -> [String] {
        library.likedTracks().map(\.artist).deduplicated(limit: limit)
    }

    private func seedVideoIds(limit: Int = 4) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for id in library.recentlyPlayedTracks(limit: 20).compactMap(\.youTubeId) {
            if seen.insert(id).inserted { out.append(id) }
            if out.count >= limit { break }
        }
        return out
    }

    /// Async input building: aggregates discovery signals on a detached task (single fetch derivation),
    /// moving the full-table reduce off the main thread. Used by `reload()`; `load()` keeps the synchronous `buildInput()`
    /// to preserve the synchronous cache-hit display contract.
    private func buildInputAsync() async -> HomeDiscoveryInput {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let band: ListeningContext.TimeBand = {
            switch hour {
            case 5..<12:  return .morning
            case 12..<18: return .afternoon
            case 18..<22: return .evening
            default:       return .lateNight
            }
        }()
        let signals = await library.discoverySignalsAsync(limit: 5)
        return HomeDiscoveryInput(
            topArtistNames: signals.topArtistNames,
            recentlyPlayedArtistNames: signals.recentlyPlayedArtistNames,
            likedArtistNames: signals.likedArtistNames,
            timeBand: band,
            hour: hour,
            seedVideoIds: seedVideoIds(),
            scope: HomeFeedScope(accountChannelID: accountChannelIDProvider()))
    }
}

/// Deduplicates, preserves order, and truncates.
private extension Array where Element == String {
    func deduplicated(limit: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for v in self {
            let key = v.lowercased()
            if seen.insert(key).inserted { out.append(v) }
            if out.count >= limit { break }
        }
        return out
    }
}
