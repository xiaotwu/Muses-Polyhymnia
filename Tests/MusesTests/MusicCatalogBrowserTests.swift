import Foundation
import Testing
@testable import Muses

private actor CatalogBrowserFixture: MusicCatalogProviding {
    var failNext = true
    var failBrowseAfterFirst = false
    var browseCount = 0
    var searchCount = 0
    init(failBrowseAfterFirst: Bool = false) {
        self.failBrowseAfterFirst = failBrowseAfterFirst
    }
    let session = UUID()
    func page(_ ids: [String], next: Bool) -> MusicCatalogPage {
        .init(items: ids.map { .init(id: $0, kind: .song, title: $0, subtitle: "", artwork: nil, artists: [], releases: [], channels: []) }, filters: [], next: next ? .init(session: session, endpoint: "search", token: "fixture") : nil, fetchedAt: Date(), region: "US")
    }
    func search(_ query: String, kind: MusicCatalogKind?) async throws -> MusicCatalogPage {
        searchCount += 1
        return page([query], next: true)
    }
    func browse(_ id: String) async throws -> MusicCatalogPage {
        browseCount += 1
        if failBrowseAfterFirst && browseCount > 1 { throw MusicCatalogError.unavailable }
        var result = page([id, id], next: true)
        result.metadata = .init(title: id, subtitle: "Album", artists: [])
        return result
    }
    func next(_ cursor: MusicCatalogCursor) async throws -> MusicCatalogPage {
        if failNext { failNext = false; throw MusicCatalogError.unavailable }
        return page(["first", "second"], next: false)
    }
    func reset() {}
}

private final class CatalogLocaleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: LocaleScopedMusicCatalogProvider.Scope
    init(_ value: LocaleScopedMusicCatalogProvider.Scope) { self.value = value }
    func get() -> LocaleScopedMusicCatalogProvider.Scope { lock.withLock { value } }
    func set(_ value: LocaleScopedMusicCatalogProvider.Scope) {
        lock.withLock { self.value = value }
    }
}

private actor InterruptedCatalogFixture: MusicCatalogProviding {
    var searches = 0
    private var first: CheckedContinuation<MusicCatalogPage, Never>?
    func search(_ query: String, kind: MusicCatalogKind?) async throws -> MusicCatalogPage {
        searches += 1
        if searches == 1 { return await withCheckedContinuation { first = $0 } }
        return page("resumed")
    }
    func releaseFirst() { first?.resume(returning: page("late")); first = nil }
    func browse(_ id: String) async throws -> MusicCatalogPage { page(id) }
    func next(_ cursor: MusicCatalogCursor) async throws -> MusicCatalogPage { page("next") }
    func reset() {}
    private func page(_ id: String) -> MusicCatalogPage {
        .init(items: [.init(id: id, kind: .song, title: id, subtitle: "", artwork: nil,
                           artists: [], releases: [], channels: [])],
              filters: [], next: nil, fetchedAt: Date(), region: "US")
    }
}

private actor LocaleCatalogFixture: MusicCatalogProviding {
    let scope: LocaleScopedMusicCatalogProvider.Scope
    let session = UUID()
    init(scope: LocaleScopedMusicCatalogProvider.Scope) { self.scope = scope }
    func search(_ query: String, kind: MusicCatalogKind?) async throws
        -> MusicCatalogPage { page(query) }
    func browse(_ id: String) async throws -> MusicCatalogPage { page(id) }
    func next(_ cursor: MusicCatalogCursor) async throws -> MusicCatalogPage {
        guard cursor.session == session else { throw MusicCatalogError.expiredCursor }
        return page("next")
    }
    func reset() {}
    private func page(_ title: String) -> MusicCatalogPage {
        .init(
            items: [.init(id: "video:abcdefghijk", kind: .song,
                          title: title, subtitle: "", artwork: nil,
                          artists: [], releases: [], channels: [])],
            filters: [],
            next: .init(session: session, endpoint: "search", token: "token",
                        region: scope.region, language: scope.language),
            fetchedAt: Date(), region: scope.region, language: scope.language)
    }
}

@Suite("Structured catalog browser state") @MainActor
struct MusicCatalogBrowserTests {
    @Test func reentryResumesInterruptedInitialRequestAndRejectsLateResult() async {
        let provider = InterruptedCatalogFixture()
        let browser = MusicCatalogBrowser(provider: provider)
        browser.search("first", kind: .song)
        for _ in 0..<500 where await provider.searches == 0 { await Task.yield() }
        browser.cancel()
        browser.searchIfNeeded("first")
        await settle(browser)
        #expect(browser.kind == .song)
        #expect(browser.items.map(\.id) == ["resumed"])
        await provider.releaseFirst()
        for _ in 0..<20 { await Task.yield() }
        #expect(browser.items.map(\.id) == ["resumed"])
        #expect(await provider.searches == 2)
    }

    @Test func returningToSearchRetainsCategoryPagesAndCursor() async {
        let provider = CatalogBrowserFixture()
        let browser = MusicCatalogBrowser(provider: provider)
        browser.search("first", kind: .song)
        await settle(browser)
        browser.more()
        await settle(browser)
        browser.retry()
        await settle(browser)
        let fetchedAt = browser.fetchedAt
        browser.cancel()
        browser.searchIfNeeded(" first ")
        #expect(browser.kind == .song)
        #expect(browser.items.map(\.id) == ["first", "second"])
        #expect(browser.nextCursor == nil)
        #expect(browser.fetchedAt == fetchedAt)
        #expect(!browser.loading)
        #expect(await provider.searchCount == 1)
    }

    @Test func returningToFailedPageRetainsRetryCursor() async {
        let provider = CatalogBrowserFixture()
        let browser = MusicCatalogBrowser(provider: provider)
        browser.search("first", kind: .song)
        await settle(browser)
        browser.more()
        await settle(browser)
        let cursor = browser.nextCursor
        browser.cancel()
        browser.searchIfNeeded("first")
        #expect(browser.failed)
        #expect(browser.kind == .song)
        #expect(browser.items.map(\.id) == ["first"])
        #expect(browser.nextCursor?.session == cursor?.session)
        #expect(browser.nextCursor?.endpoint == cursor?.endpoint)
        #expect(browser.nextCursor?.token == cursor?.token)
        browser.retry()
        await settle(browser)
        #expect(browser.items.map(\.id) == ["first", "second"])
        #expect(await provider.searchCount == 1)
    }

    @Test func reentryStartsNewIdentityButDoesNotReplaceDetail() async {
        let browser = MusicCatalogBrowser(provider: CatalogBrowserFixture())
        browser.search("first", kind: .song)
        await settle(browser)
        browser.searchIfNeeded("second")
        await settle(browser)
        #expect(browser.kind == nil)
        #expect(browser.items.map(\.id) == ["second"])
        let detail = MusicCatalogItem(id: "browse:album", kind: .album,
            title: "Album", subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.open(detail)
        await settle(browser)
        browser.searchIfNeeded("second")
        #expect(browser.detail?.id == detail.id)
        #expect(browser.items.map(\.id) == ["browse:album", "browse:album"])
    }

    @Test func savedBrowseOpensWithoutSearchAndRetainsRowsOnFailedRefresh() async {
        let browser = MusicCatalogBrowser(provider: CatalogBrowserFixture(failBrowseAfterFirst: true))
        let show = MusicCatalogItem(id: "browse:MPSPshow", kind: .podcast,
            title: "Show", subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.browse(show)
        await settle(browser)
        #expect(browser.detail?.id == show.id)
        #expect(browser.items.count == 2)
        browser.refresh()
        await settle(browser)
        #expect(browser.items.count == 2)
        #expect(browser.failed)
        #expect(browser.isStale)
    }
    @Test func detailMetadataSurvivesPaginationButNotNavigation() async {
        let browser = MusicCatalogBrowser(provider: CatalogBrowserFixture())
        browser.search("first")
        await settle(browser)
        browser.open(.init(id: "browse:album", kind: .album, title: "Album", subtitle: "", artwork: nil, artists: [], releases: [], channels: []))
        await settle(browser)
        #expect(browser.metadata?.title == "browse:album")
        browser.more()
        await settle(browser)
        browser.retry()
        await settle(browser)
        #expect(browser.metadata?.title == "browse:album")
        browser.back()
        #expect(browser.metadata == nil)
        await settle(browser)
        #expect(browser.metadata == nil)
    }

    private func settle(_ browser: MusicCatalogBrowser) async {
        for _ in 0..<500 where browser.loading { await Task.yield() }
    }
    @Test func failedPagePreservesRowsAndRetryCursor() async {
        let browser = MusicCatalogBrowser(provider: CatalogBrowserFixture())
        browser.search("first")
        await settle(browser)
        #expect(browser.items.map(\.id) == ["first"])
        browser.more()
        await settle(browser)
        #expect(browser.failed)
        #expect(browser.items.map(\.id) == ["first"])
        #expect(browser.nextCursor != nil)
        browser.retry()
        await settle(browser)
        #expect(!browser.failed)
        #expect(browser.items.map(\.id) == ["first", "second"])
        #expect(browser.nextCursor == nil)
    }
    @Test func newQueryClearsOldSelectionImmediately() async {
        let browser = MusicCatalogBrowser(provider: CatalogBrowserFixture())
        browser.search("first")
        await settle(browser)
        browser.search("second", kind: .album)
        #expect(browser.items.isEmpty)
        await settle(browser)
        #expect(browser.items.map(\.id) == ["second"])
        browser.clear()
        #expect(browser.items.isEmpty)
        #expect(browser.fetchedAt == nil)
        #expect(browser.nextCursor == nil)
    }
    @Test func browseRetainsRepeatedOccurrences() async throws {
        let browser = MusicCatalogBrowser(provider: CatalogBrowserFixture())
        browser.search("first")
        await settle(browser)
        browser.open(.init(id: "browse:album", kind: .album, title: "Album", subtitle: "", artwork: nil, artists: [], releases: [], channels: []))
        await settle(browser)
        #expect(browser.items.map(\.id) == ["browse:album", "browse:album"])
        browser.back()
        await settle(browser)
        #expect(browser.items.map(\.id) == ["first"])
    }
    @Test func detailsForwardAndBranchReset() async {
        let browser = MusicCatalogBrowser(provider: CatalogBrowserFixture())
        browser.search("first")
        let a = MusicCatalogItem(id: "browse:a", kind: .album, title: "A", subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        let b = MusicCatalogItem(id: "browse:b", kind: .album, title: "B", subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.open(a)
        browser.open(b)
        browser.back()
        #expect(browser.detail?.id == a.id)
        browser.forward()
        #expect(browser.detail?.id == b.id)
        browser.back()
        browser.back()
        #expect(browser.detail == nil)
        browser.open(a)
        #expect(!browser.canGoForward)
        browser.search("new")
        #expect(!browser.canGoBack)
        #expect(!browser.canGoForward)
        browser.clear()
    }
    @Test func podcastEpisodeUsesUnifiedYouTubePlaybackPath() {
        let item = MusicCatalogItem(id: "video:abcdefghijk", kind: .episode, title: "Episode", subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        #expect(item.playableEntry?.id == "abcdefghijk")
    }

    @Test("app-language changes rotate provider scope and invalidate cursors")
    func localeChangesInvalidateCursor() async throws {
        let initial = LocaleScopedMusicCatalogProvider.Scope(
            region: "US", language: "en")
        let box = CatalogLocaleBox(initial)
        let provider = LocaleScopedMusicCatalogProvider(
            scopeProvider: { box.get() },
            factory: { LocaleCatalogFixture(scope: $0) })
        let english = try await provider.search("English", kind: nil)
        let oldCursor = try #require(english.next)
        #expect(english.language == "en")

        box.set(.init(region: "TW", language: "zh-Hant"))
        await #expect(throws: MusicCatalogError.self) {
            try await provider.next(oldCursor)
        }
        let traditional = try await provider.search("繁體", kind: nil)
        #expect(traditional.region == "TW")
        #expect(traditional.language == "zh-Hant")
        #expect(traditional.next?.language == "zh-Hant")
    }
}
