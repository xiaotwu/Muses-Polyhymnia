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

private actor InterruptedDetailCatalogFixture: MusicCatalogProviding {
    private(set) var browseCount = 0
    private(set) var searchCount = 0
    private var first: CheckedContinuation<MusicCatalogPage, Never>?
    let failsFirst: Bool

    init(failsFirst: Bool = false) { self.failsFirst = failsFirst }

    func search(_ query: String, kind: MusicCatalogKind?) async throws -> MusicCatalogPage {
        searchCount += 1
        return page(query)
    }
    func browse(_ id: String) async throws -> MusicCatalogPage {
        browseCount += 1
        if browseCount == 1 {
            if failsFirst { throw MusicCatalogError.unavailable }
            return await withCheckedContinuation { first = $0 }
        }
        return page("resumed")
    }
    func releaseFirst() { first?.resume(returning: page("late")); first = nil }
    func next(_ cursor: MusicCatalogCursor) async throws -> MusicCatalogPage { page("next") }
    func reset() {}
    private func page(_ id: String) -> MusicCatalogPage {
        .init(items: [.init(id: id, kind: .song, title: id, subtitle: "", artwork: nil,
                           artists: [], releases: [], channels: [])],
              filters: [], next: nil, fetchedAt: Date(), region: "US",
              metadata: .init(title: id, subtitle: "Album", artists: []))
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

private actor CatalogLocaleTransitionFixture: MusicCatalogProviding {
    let locale: CatalogLocaleBox
    let session = UUID()
    private(set) var browseLanguages: [String] = []
    private(set) var nextLanguages: [String] = []
    private var shouldFailBrowse = false
    private var shouldHoldBrowse = false
    private var held: (LocaleScopedMusicCatalogProvider.Scope,
                       CheckedContinuation<MusicCatalogPage, Never>)?
    var hasHeldBrowse: Bool { held != nil }

    init(locale: CatalogLocaleBox) { self.locale = locale }
    func failNextBrowse() { shouldFailBrowse = true }
    func holdNextBrowse() { shouldHoldBrowse = true }
    func releaseHeldBrowse() {
        guard let (scope, continuation) = held else { return }
        held = nil
        continuation.resume(returning: page(scope: scope))
    }
    func search(_ query: String, kind: MusicCatalogKind?) async throws -> MusicCatalogPage {
        page(scope: locale.get())
    }
    func browse(_ id: String) async throws -> MusicCatalogPage {
        let scope = locale.get()
        browseLanguages.append(scope.language)
        if shouldFailBrowse {
            shouldFailBrowse = false
            throw MusicCatalogError.unavailable
        }
        if shouldHoldBrowse {
            shouldHoldBrowse = false
            return await withCheckedContinuation { held = (scope, $0) }
        }
        return page(scope: scope)
    }
    func next(_ cursor: MusicCatalogCursor) async throws -> MusicCatalogPage {
        nextLanguages.append(cursor.language)
        let scope = locale.get()
        guard cursor.region == scope.region, cursor.language == scope.language else {
            throw MusicCatalogError.expiredCursor
        }
        return page(scope: scope, next: false)
    }
    func reset() {}
    private func page(scope: LocaleScopedMusicCatalogProvider.Scope,
                      next: Bool = true) -> MusicCatalogPage {
        .init(items: [.init(id: next ? "video:first000001" : "video:second00001",
                           kind: .song, title: scope.language, subtitle: "", artwork: nil,
                           artists: [], releases: [], channels: [])],
              filters: [], next: next ? .init(session: session, endpoint: "browse", token: "fixture",
                                              region: scope.region, language: scope.language) : nil,
              fetchedAt: Date(), region: scope.region, language: scope.language,
              metadata: .init(title: scope.language, subtitle: "Album", artists: []))
    }
}

@Suite("Structured catalog browser state") @MainActor
struct MusicCatalogBrowserTests {
    @Test(arguments: ["resume", "more", "retry"])
    func localeChangeReloadsSameDetailAndReplacesItsCursor(entryPoint: String) async {
        let locale = CatalogLocaleBox(.init(region: "US", language: "en"))
        let provider = CatalogLocaleTransitionFixture(locale: locale)
        let browser = MusicCatalogBrowser(provider: provider, localeKeyProvider: {
            let scope = locale.get()
            return scope.region + "|" + scope.language
        })
        let detail = MusicCatalogItem(id: "browse:album", kind: .album, title: "Album",
            subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.search("album", kind: .album)
        await settle(browser)
        browser.open(detail)
        await settle(browser)
        #expect(browser.nextCursor?.language == "en")

        locale.set(.init(region: "TW", language: "zh-Hant"))
        switch entryPoint {
        case "more": browser.more()
        case "retry": browser.retry()
        default: browser.resumeIfNeeded()
        }
        #expect(browser.detail == detail && browser.kind == .album && browser.canGoBack)
        #expect(browser.items.isEmpty && browser.nextCursor == nil && browser.loading)
        await settle(browser)
        #expect(browser.items.map(\.title) == ["zh-Hant"])
        #expect(browser.metadata?.title == "zh-Hant")
        #expect(browser.region == "TW" && browser.language == "zh-Hant")
        #expect(browser.nextCursor?.region == "TW" && browser.nextCursor?.language == "zh-Hant")
        #expect(await provider.browseLanguages == ["en", "zh-Hant"])
        #expect(await provider.nextLanguages.isEmpty)

        browser.cancel()
        browser.resumeIfNeeded()
        #expect(!browser.loading)
        #expect(await provider.browseLanguages == ["en", "zh-Hant"])
        browser.more()
        await settle(browser)
        #expect(!browser.failed && browser.items.count == 2 && browser.nextCursor == nil)
        #expect(await provider.nextLanguages == ["zh-Hant"])
        #expect(browser.detail == detail && browser.canGoBack)
    }

    @Test func changedLocaleFailureRequiresExplicitRetryAndKeepsDetailHistory() async {
        let locale = CatalogLocaleBox(.init(region: "US", language: "en"))
        let provider = CatalogLocaleTransitionFixture(locale: locale)
        let browser = MusicCatalogBrowser(provider: provider, localeKeyProvider: { locale.get().language })
        let detail = MusicCatalogItem(id: "browse:album", kind: .album, title: "Album",
            subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.search("album", kind: .album)
        await settle(browser)
        browser.open(detail)
        await settle(browser)
        locale.set(.init(region: "TW", language: "zh-Hant"))
        await provider.failNextBrowse()
        browser.resumeIfNeeded()
        await settle(browser)
        #expect(browser.failed && browser.items.isEmpty && browser.nextCursor == nil)
        #expect(browser.detail == detail && browser.kind == .album && browser.canGoBack)

        browser.cancel()
        browser.resumeIfNeeded()
        #expect(browser.failed && !browser.loading)
        #expect(await provider.browseLanguages == ["en", "zh-Hant"])
        browser.retry()
        await settle(browser)
        #expect(!browser.failed && browser.items.map(\.title) == ["zh-Hant"])
        #expect(browser.nextCursor?.language == "zh-Hant")
        #expect(await provider.browseLanguages == ["en", "zh-Hant", "zh-Hant"])
        browser.back()
        await settle(browser)
        #expect(browser.detail == nil && browser.kind == .album && browser.canGoForward)
        #expect(browser.items.map(\.title) == ["zh-Hant"])
    }

    @Test func oldLocaleDetailResponseCannotReplaceReloadedDestination() async {
        let locale = CatalogLocaleBox(.init(region: "US", language: "en"))
        let provider = CatalogLocaleTransitionFixture(locale: locale)
        let browser = MusicCatalogBrowser(provider: provider, localeKeyProvider: { locale.get().language })
        let detail = MusicCatalogItem(id: "browse:album", kind: .album, title: "Album",
            subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        await provider.holdNextBrowse()
        browser.browse(detail)
        for _ in 0..<500 where !(await provider.hasHeldBrowse) { await Task.yield() }
        #expect(await provider.hasHeldBrowse)
        locale.set(.init(region: "TW", language: "zh-Hant"))
        browser.resumeIfNeeded()
        await settle(browser)
        #expect(browser.items.map(\.title) == ["zh-Hant"])
        await provider.releaseHeldBrowse()
        for _ in 0..<20 { await Task.yield() }
        #expect(!browser.loading && !browser.failed && browser.detail == detail)
        #expect(browser.items.map(\.title) == ["zh-Hant"])
        #expect(browser.metadata?.title == "zh-Hant")
        #expect(browser.nextCursor?.language == "zh-Hant")
        #expect(!browser.canGoBack && !browser.canGoForward)
        #expect(await provider.browseLanguages == ["en", "zh-Hant"])
    }

    @Test(arguments: [false, true])
    func reentryResumesInterruptedDetailWithoutReplacingItsIdentity(savedBrowse: Bool) async {
        let provider = InterruptedDetailCatalogFixture()
        let browser = MusicCatalogBrowser(provider: provider)
        let detail = MusicCatalogItem(id: "browse:album", kind: .album, title: "Album",
            subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        if savedBrowse { browser.browse(detail) }
        else {
            browser.search("first", kind: .album)
            await settle(browser)
            browser.open(detail)
        }
        for _ in 0..<500 where await provider.browseCount == 0 { await Task.yield() }
        browser.cancel()
        #expect(browser.detail == detail)
        #expect(browser.items.isEmpty && browser.fetchedAt == nil)
        #expect(!browser.loading && !browser.failed)

        browser.resumeIfNeeded()
        await settle(browser)
        #expect(browser.detail == detail)
        #expect(browser.items.map(\.id) == ["resumed"])
        #expect(browser.metadata?.title == "resumed")
        #expect(browser.canGoBack == !savedBrowse)
        #expect(browser.kind == (savedBrowse ? nil : .album))
        #expect(await provider.browseCount == 2)
        #expect(await provider.searchCount == (savedBrowse ? 0 : 1))

        await provider.releaseFirst()
        for _ in 0..<20 { await Task.yield() }
        #expect(browser.detail == detail)
        #expect(browser.items.map(\.id) == ["resumed"])
        #expect(browser.metadata?.title == "resumed")
    }

    @Test func resumingLoadedDetailRetainsRowsMetadataAndCursorWithoutRefetching() async {
        let provider = CatalogBrowserFixture()
        let browser = MusicCatalogBrowser(provider: provider)
        browser.search("first", kind: .album)
        await settle(browser)
        let detail = MusicCatalogItem(id: "browse:album", kind: .album, title: "Album",
            subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.open(detail)
        await settle(browser)
        let rows = browser.items
        let cursor = browser.nextCursor
        let fetchedAt = browser.fetchedAt
        browser.cancel()
        browser.resumeIfNeeded()
        #expect(browser.detail == detail && browser.kind == .album)
        #expect(browser.items == rows)
        #expect(browser.metadata?.title == detail.id)
        #expect(browser.nextCursor?.session == cursor?.session)
        #expect(browser.nextCursor?.endpoint == cursor?.endpoint)
        #expect(browser.nextCursor?.token == cursor?.token)
        #expect(browser.fetchedAt == fetchedAt)
        #expect(!browser.loading)
        #expect(await provider.browseCount == 1)
    }

    @Test func failedInitialDetailRequiresExplicitRetryAfterReentry() async {
        let provider = InterruptedDetailCatalogFixture(failsFirst: true)
        let browser = MusicCatalogBrowser(provider: provider)
        let detail = MusicCatalogItem(id: "browse:album", kind: .album, title: "Album",
            subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.browse(detail)
        await settle(browser)
        #expect(browser.failed && browser.items.isEmpty)
        browser.cancel()
        browser.resumeIfNeeded()
        #expect(browser.failed && !browser.loading && browser.detail == detail)
        #expect(await provider.browseCount == 1)
        browser.retry()
        await settle(browser)
        #expect(!browser.failed && browser.detail == detail)
        #expect(browser.items.map(\.id) == ["resumed"])
        #expect(await provider.browseCount == 2)
    }

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
