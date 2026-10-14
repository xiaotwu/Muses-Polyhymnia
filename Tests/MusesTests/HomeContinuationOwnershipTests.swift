import Foundation
import Testing
@testable import Muses

@Suite("Home shelf continuation ownership")
@MainActor
struct HomeContinuationOwnershipTests {
    @Test("a late old continuation cannot release a newer same-ID shelf or publish content/errors",
          arguments: ShelfTransition.allCases, ShelfResponses.allCases)
    func staleResponseCannotReleaseNewShelf(
        transition: ShelfTransition, responses: ShelfResponses
    ) async throws {
        let fixture = try ShelfOwnershipFixture()
        defer { fixture.close() }
        let service: HomeDiscoveryService = fixture.service
        service.load()
        try await initialRefreshSettled(service)
        service.loadMore(sectionID: SuspendedShelfProvider.sectionID)
        try await fixture.web.waitForRequestCount(1)

        switch transition {
        case .account:
            fixture.channel = "UC_B"
            service.accountScopeDidChange()
        case .mode:
            fixture.mode = .muses
            service.recommendationModeDidChange()
            try await initialRefreshSettled(service)
            #expect(service.sections.map(\.source) == [.localLibrary])
            fixture.mode = .youtubeMusic
            service.recommendationModeDidChange()
        case .cancelAndLoad:
            service.cancel()
            service.load()
        }
        try await initialRefreshSettled(service)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-2"])
        service.loadMore(sectionID: SuspendedShelfProvider.sectionID)
        try await fixture.web.waitForRequestCount(2)
        #expect(fixture.web.requests[0].scope == .account(channelID: "UC_A"))
        #expect(fixture.web.requests[1].scope == HomeFeedScope(accountChannelID: fixture.channel))
        #expect(service.loadingSectionIDs == [SuspendedShelfProvider.sectionID])

        fixture.web.finish(1, videos: responses.oldResponseIsEmpty ? [] : ["old-response"])
        try await fixture.web.waitForReturn(1)
        #expect(service.loadingSectionIDs == [SuspendedShelfProvider.sectionID])
        #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-2"])
        #expect(service.sections.first?.accountChannelID == fixture.channel)
        #expect(service.continuationErrors.isEmpty)
        service.loadMore(sectionID: SuspendedShelfProvider.sectionID)
        await drainReadyTasks()
        #expect(fixture.web.requests.count == 2)

        fixture.web.finish(2, videos: responses.newResponseIsEmpty ? [] : ["new-response"])
        try await fixture.web.waitForReturn(2)
        #expect(service.loadingSectionIDs.isEmpty)
        if responses.newResponseIsEmpty {
            #expect(service.continuationErrors[SuspendedShelfProvider.sectionID] != nil)
            #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-2"])
            service.loadMore(sectionID: SuspendedShelfProvider.sectionID)
            try await fixture.web.waitForRequestCount(3)
            #expect(service.loadingSectionIDs == [SuspendedShelfProvider.sectionID])
            fixture.web.finish(3, videos: ["new-response"])
            try await fixture.web.waitForReturn(3)
        }
        #expect(service.continuationErrors.isEmpty)
        #expect(service.loadingSectionIDs.isEmpty)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity)
            == ["video:base-2", "video:new-response"])
    }

    @Test("reload immediately releases old shelf markers/errors and allows the new same-ID continuation")
    func reloadAllowsNewShelfContinuation() async throws {
        let fixture = try ShelfOwnershipFixture()
        defer { fixture.close() }
        let service: HomeDiscoveryService = fixture.service
        let id = SuspendedShelfProvider.sectionID
        service.load()
        try await initialRefreshSettled(service)
        service.loadMore(sectionID: id)
        try await fixture.web.waitForRequestCount(1)
        fixture.web.finish(1, videos: [])
        try await fixture.web.waitForReturn(1)
        #expect(service.continuationErrors[id] != nil)
        service.loadMore(sectionID: id)
        try await fixture.web.waitForRequestCount(2)

        service.reload()
        #expect(service.loadingSectionIDs.isEmpty)
        #expect(service.continuationErrors.isEmpty)
        try await initialRefreshSettled(service)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-2"])
        service.loadMore(sectionID: id)
        await drainReadyTasks()
        try #require(fixture.web.requests.count == 3)
        fixture.web.finish(2, videos: ["old-response"])
        try await fixture.web.waitForReturn(2)
        #expect(service.loadingSectionIDs == [id])
        #expect(service.continuationErrors.isEmpty)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-2"])
        fixture.web.finish(3, videos: ["new-response"])
        try await fixture.web.waitForReturn(3)
        #expect(service.loadingSectionIDs.isEmpty)
        #expect(service.continuationErrors.isEmpty)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity)
            == ["video:base-2", "video:new-response"])
    }

    @Test("a late old response preserves the new failure and its in-flight retry", arguments: [false, true])
    func lateResponsePreservesNewError(oldResponseIsEmpty: Bool) async throws {
        let fixture = try ShelfOwnershipFixture()
        defer { fixture.close() }
        let service: HomeDiscoveryService = fixture.service
        let id = SuspendedShelfProvider.sectionID
        service.load()
        try await initialRefreshSettled(service)
        service.loadMore(sectionID: id)
        try await fixture.web.waitForRequestCount(1)
        service.cancel()
        service.load()
        try await initialRefreshSettled(service)
        service.loadMore(sectionID: id)
        try await fixture.web.waitForRequestCount(2)
        fixture.web.finish(2, videos: [])
        try await fixture.web.waitForReturn(2)
        let newError = try #require(service.continuationErrors[id])
        #expect(service.loadingSectionIDs.isEmpty)
        service.loadMore(sectionID: id)
        try await fixture.web.waitForRequestCount(3)

        fixture.web.finish(1, videos: oldResponseIsEmpty ? [] : ["old-response"])
        try await fixture.web.waitForReturn(1)
        #expect(service.loadingSectionIDs == [id])
        #expect(service.continuationErrors[id] == newError)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-2"])
        fixture.web.finish(3, videos: ["new-response"])
        try await fixture.web.waitForReturn(3)
        #expect(service.loadingSectionIDs.isEmpty)
        #expect(service.continuationErrors.isEmpty)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity)
            == ["video:base-2", "video:new-response"])
    }

    @Test("cancel and consent revocation discard suspended shelf results", arguments: [false, true])
    func cancelledContinuationDoesNotPublish(revokeConsent: Bool) async throws {
        let fixture = try ShelfOwnershipFixture()
        defer { fixture.close() }
        let service: HomeDiscoveryService = fixture.service
        service.load()
        try await initialRefreshSettled(service)
        service.loadMore(sectionID: SuspendedShelfProvider.sectionID)
        try await fixture.web.waitForRequestCount(1)
        if revokeConsent {
            fixture.web.enabled = false
            service.webConfigurationDidChange()
        } else {
            service.cancel()
        }
        #expect(service.loadingSectionIDs.isEmpty)
        #expect(service.continuationErrors.isEmpty)
        fixture.web.finish(1, videos: ["old-response"])
        try await fixture.web.waitForReturn(1)
        try await initialRefreshSettled(service)
        #expect(service.loadingSectionIDs.isEmpty)
        #expect(service.continuationErrors.isEmpty)
        if revokeConsent {
            #expect(service.sections.isEmpty)
            #expect(service.webCapability == .notConfigured)
        } else {
            #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-1"])
        }
    }

    @Test("current-operation capability loss releases its own marker without publishing an error")
    func unavailableContinuationReleasesOwnMarker() async throws {
        let fixture = try ShelfOwnershipFixture()
        defer { fixture.close() }
        let service: HomeDiscoveryService = fixture.service
        service.load()
        try await initialRefreshSettled(service)
        service.loadMore(sectionID: SuspendedShelfProvider.sectionID)
        try await fixture.web.waitForRequestCount(1)
        fixture.web.enabled = false
        fixture.web.finish(1, videos: ["unavailable-response"])
        try await fixture.web.waitForReturn(1)
        #expect(service.loadingSectionIDs.isEmpty)
        #expect(service.continuationErrors.isEmpty)
        #expect(service.sections.first?.items.map(\.homeMediaIdentity) == ["video:base-1"])
    }

    private func initialRefreshSettled(_ service: HomeDiscoveryService) async throws {
        for _ in 0..<100 where service.isRefreshing {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(!service.isRefreshing)
    }
}

enum ShelfTransition: String, CaseIterable, Sendable {
    case account, mode, cancelAndLoad
}

enum ShelfResponses: String, CaseIterable, Sendable {
    case bothSucceed, oldFails, newFails, bothFail
    var oldResponseIsEmpty: Bool { self == .oldFails || self == .bothFail }
    var newResponseIsEmpty: Bool { self == .newFails || self == .bothFail }
}

@MainActor
private final class ShelfOwnershipFixture {
    var channel: String? = "UC_A"
    var mode = HomeRecommendationMode.youtubeMusic
    let root = isolatedHomeTestDirectory("muses-home-continuation-")
    let web = SuspendedShelfProvider()
    private(set) var service: HomeDiscoveryService!

    init() throws {
        let provider = ModeSwitchingHomeDiscoveryProvider(modeProvider: { [unowned self] in self.mode },
            muses: ShelfLocalProvider(), youtubeMusic: YouTubeMusicHomeProvider(authenticated: web))
        service = HomeDiscoveryService(provider: provider, cache: HomeFeedCache(directory: root),
            library: LibraryService(modelContainer: try makeModelContainer(inMemory: true)),
            enabledProvider: { true }, modeProvider: { [unowned self] in self.mode },
            accountChannelIDProvider: { [unowned self] in self.channel })
    }

    func close() {
        service.cancel()
        web.finishAll()
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor
private final class ShelfLocalProvider: HomeDiscoveryProvider {
    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        let now = Date()
        return HomeFetchResult(
            baselineSnapshot: HomeSnapshot(scope: input.scope, sections: [HomeSection(
                id: "muses", title: "Muses", kind: .quickPicks, items: [], source: .localLibrary)],
                fetchedAt: now, expiresAt: now.addingTimeInterval(600)),
            webSnapshot: nil, webCapability: .notConfigured, failures: [], cacheDirectives: .preserveAll)
    }
}

/// Ignores resets deliberately: a provider may finish external work after its
/// consumer invalidates a feed, so publication and loading ownership belong to the service.
@MainActor
private final class SuspendedShelfProvider: HomeDiscoveryProvider {
    static let sectionID = "shared-account-shelf"
    struct Request {
        let sectionID: String
        let scope: HomeFeedScope
    }
    var enabled = true
    private(set) var requests: [Request] = []
    private var pending: [Int: CheckedContinuation<[DiscoveryItem], Never>] = [:]
    private var returned: Set<Int> = []
    private var fetchCount = 0
    var hasWebEnhancement: Bool { enabled }
    func hasContinuation(for sectionID: String) -> Bool { enabled && sectionID == Self.sectionID }

    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        fetchCount += 1
        let now = Date()
        let empty = HomeFetchResult.baseline(scope: input.scope, sections: []).baselineSnapshot
        guard case .account(let channelID) = input.scope else {
            return HomeFetchResult(baselineSnapshot: empty, webSnapshot: nil,
                webCapability: .signedOut, failures: [], cacheDirectives: .preserveAll)
        }
        let shelf = HomeSection(id: Self.sectionID, title: "Account shelf", kind: .quickPicks,
            items: [shelfCard("base-\(fetchCount)")], source: .signedInWeb, accountChannelID: channelID)
        return HomeFetchResult(baselineSnapshot: empty,
            webSnapshot: HomeSnapshot(scope: input.scope, sections: [shelf], fetchedAt: now,
                expiresAt: now.addingTimeInterval(HomeFeedCache.webFreshWindow)),
            webCapability: .available(accountChannelID: channelID), failures: [],
            cacheDirectives: .preserveAll)
    }

    func more(sectionID: String, input: HomeDiscoveryInput) async -> [DiscoveryItem] {
        requests.append(Request(sectionID: sectionID, scope: input.scope))
        let number = requests.count
        let items = await withCheckedContinuation { pending[number] = $0 }
        returned.insert(number)
        return items
    }

    func finish(_ request: Int, videos: [String]) {
        pending.removeValue(forKey: request)?.resume(returning: videos.map(shelfCard))
    }

    func finishAll() {
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations { continuation.resume(returning: []) }
    }

    func waitForRequestCount(_ count: Int) async throws {
        for _ in 0..<100 where requests.count < count {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(requests.count == count)
    }

    func waitForReturn(_ request: Int) async throws {
        for _ in 0..<100 where !returned.contains(request) {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(returned.contains(request))
        await drainReadyTasks()
    }
}

@MainActor
private func drainReadyTasks() async {
    for _ in 0..<20 { await Task.yield() }
}

private func shelfCard(_ id: String) -> DiscoveryItem {
    .youTube(YouTubeDiscoveryCard(id: "video:\(id)", title: id, browseEndpoint: nil,
        playEndpoint: HomeCardEndpoint(kind: .video, identifier: id), availability: .available))
}
