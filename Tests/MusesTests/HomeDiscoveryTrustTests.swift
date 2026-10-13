import Foundation
import Testing
@testable import Muses

@Suite("Home discovery trust and cache scope")
@MainActor
struct HomeDiscoveryTrustTests {
    @Test("one failed Muses section retains only its own saved items while other sections refresh")
    func localPartialFailureDoesNotPoisonFeed() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let local = PartialLocalHomeStub()
        let service = HomeDiscoveryService(provider: local, cache: cache,
            library: LibraryService(modelContainer: try makeModelContainer(inMemory: true)),
            enabledProvider: { true }, modeProvider: { .muses })
        service.load()
        try await settled(service)
        local.failSection = true
        service.reload()
        try await settled(service)
        #expect(service.sections.map(\.id) == ["local-a", "local-b", "local-c"])
        #expect(service.sections[0].source == .cached)
        #expect(service.sections[0].cachedOrigin == .localLibrary)
        #expect(service.sections[0].items.map(\.homeMediaIdentity) == ["video:old-a"])
        #expect(service.sections[1].source == .localLibrary)
        #expect(service.sections[1].items.map(\.homeMediaIdentity) == ["video:new-b"])
        #expect(service.sections[2].status == .failed("failed c"))
        #expect(service.isShowingStale)
        #expect(service.lastRefreshError == "failed a")
        await cache.flushPendingWrites()
        let cold = HomeFeedCache(directory: root)
        #expect(cold.get(for: service.buildInput(), layer: .baseline, mode: .muses)?
            .value.sections[1].items.map(\.homeMediaIdentity) == ["video:old-b"])
    }

    @Test("account Home never calls a provider while signed out or disabled")
    func unavailableAccountDoesNotFetch() async {
        let web = AccountHomeStub()
        let provider = YouTubeMusicHomeProvider(authenticated: web)
        let signedOut = await provider.fetch(for: input(.guest))
        #expect(signedOut.webCapability == .signedOut)
        #expect(signedOut.baselineSnapshot.sections.isEmpty)
        #expect(signedOut.webSnapshot == nil)
        #expect(web.inputs.isEmpty)
        web.enabled = false
        let disabled = await provider.fetch(for: input(.account(channelID: "UC_one")))
        #expect(disabled.webCapability == .notConfigured)
        #expect(disabled.cacheDirectives == .preserveAll)
        #expect(web.inputs.isEmpty)
        let buildDisabled = await YouTubeMusicHomeProvider(authenticated: nil)
            .fetch(for: input(.account(channelID: "UC_one")))
        #expect(buildDisabled.webCapability == .notConfigured)
        #expect(buildDisabled.baselineSnapshot.sections.isEmpty)
    }

    @Test("account Home rejects a mismatched response and preserves its failure code")
    func accountProviderRejectsUnsafeResponse() async {
        let web = AccountHomeStub()
        web.responseChannel = "UC_other"
        let provider = YouTubeMusicHomeProvider(authenticated: web)
        let rejected = await provider.fetch(for: input(.account(channelID: "UC_one")))
        #expect(rejected.webSnapshot == nil)
        #expect(rejected.baselineSnapshot.sections.isEmpty)
        #expect(rejected.failures.first?.code == .shapeChanged)
        #expect(!rejected.cacheDirectives.storeWeb)
        web.responseChannel = nil
        web.failure = .sessionExpired
        let expired = await provider.fetch(for: input(.account(channelID: "UC_one")))
        #expect(expired.failures.first?.code == .sessionExpired)
        #expect(expired.webSnapshot == nil)
        #expect(expired.baselineSnapshot.sections.isEmpty)
    }

    @Test("fresh account Web cache cold-loads independently of any baseline")
    func coldAccountCacheDoesNotNeedBaseline() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let web = AccountHomeStub()
        let seed = HomeFeedCache(directory: root)
        let account = input(.account(channelID: "UC_one"))
        let snapshot = accountSnapshot(channelID: "UC_one")
        try #require(seed.set(snapshot, for: account, layer: .web, mode: .youtubeMusic))
        await seed.flushPendingWrites()
        let cache = HomeFeedCache(directory: root)
        let service = try service(web, cache: cache, channel: { "UC_one" })
        service.load()
        #expect(service.sections.first?.source == .cached)
        #expect(service.sections.first?.cachedOrigin == .signedInWeb)
        #expect(service.sections.first?.accountChannelID == "UC_one")
        #expect(service.lastUpdatedAt == snapshot.fetchedAt)
        #expect(!service.isRefreshing)
        #expect(web.inputs.isEmpty)
        #expect(cache.get(for: account, layer: .baseline, mode: .youtubeMusic) == nil)
    }

    @Test("failed account refresh retains only the same-account verified success")
    func failedWebRefreshPreservesLastSuccess() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let web = AccountHomeStub()
        let service = try service(web, cache: cache, channel: { "UC_one" })
        service.load()
        try await settled(service)
        #expect(service.sections.first?.source == .signedInWeb)
        let fetchedAt = service.lastUpdatedAt
        web.failure = .offline
        service.reload()
        try await settled(service)
        #expect(service.sections.first?.source == .cached)
        #expect(service.sections.first?.cachedOrigin == .signedInWeb)
        #expect(service.sections.first?.accountChannelID == "UC_one")
        #expect(service.lastUpdatedAt == fetchedAt)
        #expect(service.isShowingStale)
        #expect(service.lastRefreshError == "offline")
        await cache.flushPendingWrites()
        let cold = HomeFeedCache(directory: root)
        #expect(cold.get(for: service.buildInput(), layer: .web, mode: .youtubeMusic)?
            .value.sections.first?.id == "web-success")
    }

    @Test("account failure without a saved success is truthful and never creates a fallback shelf")
    func accountColdFailureHasNoFallback() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let web = AccountHomeStub()
        web.failure = .offline
        let service = try service(web, cache: HomeFeedCache(directory: root), channel: { "UC_one" })
        service.load()
        try await settled(service)
        #expect(service.sections.isEmpty)
        #expect(service.lastUpdatedAt == nil)
        #expect(!service.isShowingStale)
        #expect(service.lastRefreshError == "offline")
        #expect(service.webCapability == .unavailable(reason: "offline"))
        web.failure = nil
        service.reload()
        try await settled(service)
        #expect(service.sections.first?.source == .signedInWeb)
        #expect(service.lastRefreshError == nil)
    }

    @Test("disabled consent and build support cannot resurrect saved Web after a real reload",
          arguments: [false, true])
    func disabledWebDoesNotAppear(buildDisabled: Bool) async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let account = input(.account(channelID: "UC_one"))
        try #require(cache.set(accountSnapshot(channelID: "UC_one", age: 3600),
                              for: account, layer: .web, mode: .youtubeMusic))
        let web = AccountHomeStub()
        web.enabled = false
        let service = try service(buildDisabled ? nil : web, cache: cache, channel: { "UC_one" })
        service.load()
        try await settled(service)
        service.reload()
        try await settled(service)
        #expect(service.sections.isEmpty)
        #expect(service.lastUpdatedAt == nil)
        #expect(!service.isShowingStale)
        #expect(service.webCapability == .notConfigured)
        #expect(web.inputs.isEmpty)
        // Revocation hides the normalized cache without deleting other user data.
        #expect(cache.get(for: account, layer: .web, mode: .youtubeMusic) != nil)
    }

    @Test("revoking consent while an uncooperative refresh is suspended rejects its late result")
    func revokedPendingFetchDoesNotReturn() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let web = AccountHomeStub()
        web.suspendChannel = "UC_one"
        let service = try service(web, cache: cache, channel: { "UC_one" })
        service.load()
        try await web.awaitSuspension()
        web.enabled = false
        service.webConfigurationDidChange()
        web.finishSuspended()
        try await settled(service)
        #expect(service.sections.isEmpty)
        #expect(service.webCapability == .notConfigured)
        #expect(cache.get(for: service.buildInput(), layer: .web, mode: .youtubeMusic) == nil)
    }

    @Test("logout and A-to-B switch discard a cancelled account result that arrives late")
    func scopeSwitchRejectsLateResult() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let web = AccountHomeStub()
        web.suspendChannel = "UC_A"
        var channel: String? = "UC_A"
        let service = try service(web, cache: cache, channel: { channel })
        service.load()
        try await web.awaitSuspension()
        channel = "UC_B"
        service.accountScopeDidChange()
        try await settled(service)
        web.finishSuspended()
        try await Task.sleep(for: .milliseconds(30))
        #expect(service.sections.map(\.accountChannelID) == ["UC_B"])
        #expect(service.activeScope == .account(channelID: "UC_B"))
        #expect(cache.get(for: input(.account(channelID: "UC_A")), layer: .web, mode: .youtubeMusic) == nil)
        channel = nil
        service.accountScopeDidChange()
        try await settled(service)
        #expect(service.sections.isEmpty)
        #expect(service.activeScope == .guest)
        #expect(service.webCapability == .signedOut)
    }

    @Test("changing account Home to Muses rejects a late account result and keeps local recommendations")
    func modeSwitchKeepsLocalSource() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let web = AccountHomeStub()
        web.suspendChannel = "UC_one"
        let local = LocalHomeStub()
        var mode = HomeRecommendationMode.youtubeMusic
        let provider = ModeSwitchingHomeDiscoveryProvider(modeProvider: { mode }, muses: local,
            youtubeMusic: YouTubeMusicHomeProvider(authenticated: web))
        let service = HomeDiscoveryService(provider: provider, cache: cache,
            library: LibraryService(modelContainer: try makeModelContainer(inMemory: true)),
            enabledProvider: { true }, modeProvider: { mode }, accountChannelIDProvider: { "UC_one" })
        service.load()
        try await web.awaitSuspension()
        mode = .muses
        service.recommendationModeDidChange()
        try await settled(service)
        web.finishSuspended()
        try await Task.sleep(for: .milliseconds(30))
        #expect(service.sections.map(\.source) == [.localLibrary])
        #expect(service.sections.map(\.id) == ["muses-local"])
        #expect(service.webCapability == .notConfigured)
        #expect(local.fetchCount == 1)
    }

    @Test("async reload preserves the explicit account scope")
    func asyncReloadUsesAccountScope() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let web = AccountHomeStub()
        let service = try service(web, cache: HomeFeedCache(directory: root), channel: { "UC_one" })
        service.reload()
        try await settled(service)
        #expect(web.inputs.last?.scope == .account(channelID: "UC_one"))
    }

    @Test("cancelled input preparation cannot restart Home fetching")
    func cancelledReloadDoesNotFetch() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let web = AccountHomeStub()
        let service = try service(web, cache: HomeFeedCache(directory: root), channel: { "UC_one" })
        service.reload()
        service.cancel()
        try await Task.sleep(for: .milliseconds(100))
        #expect(web.inputs.isEmpty)
        #expect(service.sections.isEmpty)
        #expect(!service.isRefreshing)
        service.reload()
        try await settled(service)
        #expect(web.inputs.count == 1)
    }

    @Test("global account pages append shelves and deduplicate media; offline retry repeats the same page")
    func globalContinuationMergesWithoutDuplicates() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let web = AccountHomeStub()
        web.globalPageAvailable = true
        let service = try service(web, cache: HomeFeedCache(directory: root), channel: { "UC_one" })
        service.load()
        try await settled(service)
        web.failNextPage = true
        service.loadMore()
        try await settled(service)
        #expect(service.globalContinuationError != nil)
        #expect(service.hasGlobalContinuation)
        service.loadMore()
        try await settled(service)
        #expect(web.requestedPages == [1, 1])
        #expect(service.globalContinuationError == nil)
        #expect(service.sections.map(\.id) == ["web-success", "web-second"])
        #expect(service.sections[0].items.map(\.homeMediaIdentity) == ["video:one", "video:two"])
        #expect(service.sections[1].items.map(\.homeMediaIdentity) == ["video:three"])
        #expect(!service.hasGlobalContinuation)
    }

    @Test("shelf continuation is deduplicated and stays outside the durable first-page snapshot")
    func shelfContinuationStaysVolatile() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let web = AccountHomeStub()
        let service = try service(web, cache: cache, channel: { "UC_one" })
        service.load()
        try await settled(service)
        service.loadMore(sectionID: "web-success")
        try await settled(service)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:one", "video:two"])
        await cache.flushPendingWrites()
        let cold = HomeFeedCache(directory: root)
        #expect(cold.get(for: service.buildInput(), layer: .web, mode: .youtubeMusic)?
            .value.sections.first?.items.map(\.homeMediaIdentity) == ["video:one"])
        web.enabled = false
        service.webConfigurationDidChange()
        service.loadMore(sectionID: "web-success")
        service.loadMore()
        try await settled(service)
        #expect(web.shelfRequests == ["web-success"])
        #expect(service.sections.isEmpty)
    }

    @Test("clearing the selected account's Web cache can persist a fresh cold-readable snapshot")
    func clearSavedCacheRecovers() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let web = AccountHomeStub()
        let service = try service(web, cache: cache, channel: { "UC_one" })
        service.load()
        try await settled(service)
        service.clearSavedWebHomeForCurrentAccount()
        try await settled(service)
        await cache.flushPendingWrites()
        let cold = HomeFeedCache(directory: root)
        #expect(cold.get(for: service.buildInput(), layer: .web, mode: .youtubeMusic)?
            .value.sections.first?.id == "web-success")
    }

    private func input(_ scope: HomeFeedScope) -> HomeDiscoveryInput {
        HomeDiscoveryInput(topArtistNames: [], recentlyPlayedArtistNames: [], likedArtistNames: [],
                           timeBand: .morning, hour: 9, scope: scope)
    }

    private func service(_ web: AccountHomeStub?, cache: HomeFeedCache,
                         channel: @escaping () -> String?) throws -> HomeDiscoveryService {
        HomeDiscoveryService(provider: YouTubeMusicHomeProvider(authenticated: web), cache: cache,
            library: LibraryService(modelContainer: try makeModelContainer(inMemory: true)),
            enabledProvider: { true }, modeProvider: { .youtubeMusic },
            accountChannelIDProvider: channel)
    }

    private func temporaryRoot() -> URL {
        isolatedHomeTestDirectory("muses-home-trust-")
    }

    private func settled(_ service: HomeDiscoveryService) async throws {
        for _ in 0..<100 where service.isRefreshing || service.isLoadingMore || !service.loadingSectionIDs.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!service.isRefreshing && !service.isLoadingMore && service.loadingSectionIDs.isEmpty)
    }
}

@MainActor
private final class LocalHomeStub: HomeDiscoveryProvider {
    private(set) var fetchCount = 0
    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        fetchCount += 1
        return .baseline(scope: input.scope, sections: [HomeSection(
            id: "muses-local", title: "Local", kind: .quickPicks,
            items: [accountCard("local")], source: .localLibrary)])
    }
}

@MainActor
private final class PartialLocalHomeStub: HomeDiscoveryProvider {
    var failSection = false
    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        let sections = failSection ? [
            HomeSection(id: "local-a", title: "A", kind: .quickPicks, items: [],
                        status: .failed("failed a"), source: .localLibrary),
            HomeSection(id: "local-b", title: "B", kind: .quickPicks,
                        items: [accountCard("new-b")], source: .localLibrary),
            HomeSection(id: "local-c", title: "C", kind: .quickPicks, items: [],
                        status: .failed("failed c"), source: .localLibrary)
        ] : [
            HomeSection(id: "local-a", title: "A", kind: .quickPicks,
                        items: [accountCard("old-a")], source: .localLibrary),
            HomeSection(id: "local-b", title: "B", kind: .quickPicks,
                        items: [accountCard("old-b")], source: .localLibrary)
        ]
        return .baseline(scope: input.scope, sections: sections)
    }
}

@MainActor
private final class AccountHomeStub: HomeDiscoveryProvider {
    var enabled = true
    var failure: HomeFetchFailureCode?
    var responseChannel: String?
    var suspendChannel: String?
    var globalPageAvailable = false
    var failNextPage = false
    private var suspended: CheckedContinuation<Void, Never>?
    private(set) var inputs: [HomeDiscoveryInput] = []
    private(set) var requestedPages: [Int] = []
    private(set) var shelfRequests: [String] = []
    var hasWebEnhancement: Bool { enabled }
    var hasGlobalContinuation: Bool { enabled && globalPageAvailable }
    func hasContinuation(for sectionID: String) -> Bool { enabled && sectionID == "web-success" }

    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        inputs.append(input)
        guard case .account(let channelID) = input.scope else { return .baseline(scope: input.scope, sections: []) }
        if channelID == suspendChannel {
            // Intentionally ignores task cancellation to test publication guards.
            await withCheckedContinuation { suspended = $0 }
        }
        let baseline = HomeFetchResult.baseline(scope: input.scope, sections: []).baselineSnapshot
        if let failure {
            return HomeFetchResult(baselineSnapshot: baseline, webSnapshot: nil,
                webCapability: .unavailable(reason: failure.rawValue),
                failures: [HomeFetchFailure(layer: .web, code: failure, message: failure.rawValue)],
                cacheDirectives: .preserveAll)
        }
        return HomeFetchResult(baselineSnapshot: baseline,
            webSnapshot: accountSnapshot(channelID: responseChannel ?? channelID),
            webCapability: .available(accountChannelID: channelID), failures: [],
            cacheDirectives: HomeCacheDirectives(storeBaseline: false, storeWeb: true))
    }

    func more(page: Int, input: HomeDiscoveryInput) async -> [HomeSection] {
        requestedPages.append(page)
        if failNextPage { failNextPage = false; return [] }
        guard case .account(let channelID) = input.scope else { return [] }
        globalPageAvailable = false
        return [accountShelf("web-success", videos: ["one", "two"], channelID: channelID),
                accountShelf("web-second", videos: ["three"], channelID: channelID)]
    }

    func more(sectionID: String, input: HomeDiscoveryInput) async -> [DiscoveryItem] {
        shelfRequests.append(sectionID)
        return [accountCard("one"), accountCard("two")]
    }

    func awaitSuspension() async throws {
        for _ in 0..<100 where suspended == nil { try await Task.sleep(for: .milliseconds(10)) }
        try #require(suspended != nil)
    }

    func finishSuspended() {
        let continuation = suspended
        suspended = nil
        suspendChannel = nil
        continuation?.resume()
    }
}

private func accountCard(_ id: String) -> DiscoveryItem {
    .youTube(YouTubeDiscoveryCard(id: "video:\(id)", title: id, browseEndpoint: nil,
        playEndpoint: HomeCardEndpoint(kind: .video, identifier: id), availability: .available))
}

private func accountShelf(_ id: String, videos: [String], channelID: String) -> HomeSection {
    HomeSection(id: id, title: id, kind: .quickPicks, items: videos.map(accountCard),
                source: .signedInWeb, accountChannelID: channelID)
}

private func accountSnapshot(channelID: String, age: TimeInterval = 0) -> HomeSnapshot {
    let now = Date().addingTimeInterval(-age)
    return HomeSnapshot(scope: .account(channelID: channelID),
        sections: [accountShelf("web-success", videos: ["one"], channelID: channelID)],
        fetchedAt: now, expiresAt: now.addingTimeInterval(HomeFeedCache.webFreshWindow))
}
