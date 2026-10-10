import Foundation
import SwiftData
import Testing
@testable import Muses

@Suite("Global search request state", .serialized)
@MainActor
struct GlobalSearchStateTests {
    private func library() throws -> LibraryService {
        LibraryService(modelContainer: try makeModelContainer(inMemory: true))
    }

    @Test("Online scopes delegate empty and failure states to their own sources")
    func sourceScopedEmptyStates() async throws {
        let service = GlobalSearchService(library: try library(), debounceMs: 60_000)
        for scope in [GlobalSearchScope.all, .youtube] {
            service.scope = scope
            #expect(!service.showsLibraryEmptyState)
            await service.performSearch(query: "missing")
            #expect(service.youtubeError != nil)
            #expect(service.additionalResultsStatus != nil)
            #expect(!service.showsLibraryEmptyState)
            service.cancelSearch()
            #expect(!service.showsLibraryEmptyState)
        }
        service.scope = .library
        await service.performSearch(query: "missing")
        #expect(service.showsLibraryEmptyState)
        #expect(service.additionalResultsStatus == nil)
        service.reset()
    }

    @Test("Supplemental retry preserves successful and stale structured results")
    func retryPreservesCatalog() async throws {
        for stale in [false, true] {
            let browser = MusicCatalogBrowser(provider: SearchStatusCatalogFixture(stale: stale))
            var attempts = 0
            let service = GlobalSearchService(library: try library(), debounceMs: 60_000,
                                              musicCatalog: browser, remoteSearch: { _, _ in
                attempts += 1
                if attempts == 1 { throw MusicCatalogError.unavailable }
                return []
            })
            service.query = "song"
            await service.performSearch(query: "song")
            browser.search("song")
            for _ in 0..<500 where browser.loading { await Task.yield() }
            #expect(browser.items.count == 1)
            #expect(browser.isStale == stale)
            #expect(!service.showsLibraryEmptyState)
            service.retrySearch()
            #expect(browser.items.count == 1)
            for _ in 0..<500 where attempts < 2 { await Task.yield() }
            #expect(attempts == 2)
            #expect(service.youtubeError == nil)
            #expect(browser.items.count == 1)
            #expect(browser.isStale == stale)
            service.reset()
        }
    }

    @Test("Changing query immediately removes stale selectable results")
    func queryClearsResults() async throws {
        let service = GlobalSearchService(library: try library(), debounceMs: 60_000,
                                          remoteSearch: { _, _ in [.init(id: "abcdefghijk", title: "Old")] })
        service.scope = .youtube
        await service.performSearch(query: "old")
        #expect(service.youtubeResults.count == 1)
        service.query = "new"
        #expect(service.youtubeResults.isEmpty)
        #expect(service.isSearchingYouTube)
        service.cancelSearch()
    }

    @Test("Cancelled noncooperative response cannot repopulate results")
    func cancellationRejectsResponse() async throws {
        var continuation: CheckedContinuation<[YTDlpBridge.YTDlpPlaylistEntry], Never>?
        let service = GlobalSearchService(library: try library(), remoteSearch: { _, _ in
            await withCheckedContinuation { continuation = $0 }
        })
        service.scope = .youtube
        let request = Task { await service.performSearch(query: "old") }
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        let pending = try #require(continuation)
        service.cancelSearch()
        pending.resume(returning: [.init(id: "abcdefghijk", title: "Old")])
        await request.value
        #expect(service.youtubeResults.isEmpty)
        #expect(service.wasCancelled)
        #expect(!service.isSearchingYouTube)
    }

    @Test("Loading more merges changing ranked prefixes without duplicates or losing prior rows")
    func loadMoreResults() async throws {
        let service = GlobalSearchService(library: try library(), remoteSearch: { _, limit in
            (0..<limit).map { index in
                .init(id: String(format: "%011d", index + (limit > 20 ? 5 : 0)), title: "Song")
            }
        })
        service.scope = .youtube
        await service.performSearch(query: "song")
        #expect(service.youtubeResults.count == 20)
        #expect(service.canLoadMore)
        service.loadMore()
        for _ in 0..<100 where service.isSearchingYouTube { await Task.yield() }
        #expect(service.youtubeResults.count == 45)
        #expect(service.youtubeResults.first?.id == "00000000000")
        #expect(Set(service.youtubeResults.map(\.id)).count == 45)
        service.cancelSearch()
    }

    @Test("A queued load-more task cannot revive a query after input changes")
    func supersededLoadMore() async throws {
        let service = GlobalSearchService(library: try library(), debounceMs: 60_000, remoteSearch: { _, limit in
            (0..<limit).map { .init(id: String(format: "%011d", $0), title: "Old") }
        })
        service.scope = .youtube
        await service.performSearch(query: "old")
        service.loadMore()
        service.query = "new"
        for _ in 0..<20 { await Task.yield() }
        #expect(service.youtubeResults.isEmpty)
        #expect(service.query == "new")
        service.cancelSearch()
    }

    @Test("Unavailable remote search is distinguished from an empty result")
    func unavailableSearch() async throws {
        let service = GlobalSearchService(library: try library())
        service.scope = .youtube
        await service.performSearch(query: "song")
        #expect(service.youtubeError != nil)
        #expect(!service.isSearchingYouTube)
        service.scope = .library
        await service.performSearch(query: "song")
        #expect(service.youtubeError == nil)
        #expect(!service.wasCancelled)
    }

    @Test("Suspending for a catalog detail retains the query, source and results for Back and Forward")
    func localDetailReturnRetainsSearch() async throws {
        let container = try makeModelContainer(inMemory: true)
        let library = LibraryService(modelContainer: container)
        let resolver = YouTubeSearchService(bridge: MockImportBridge(), modelContainer: container)
        let snapshot = try await resolver.resolveTrack(entry: .init(id: "abcdefghijk", title: "Return Song"),
                                                        saveToLibrary: true)
        var remoteCalls = 0
        let service = GlobalSearchService(library: library, debounceMs: 60_000,
            remoteSearch: { _, _ in remoteCalls += 1; return [] })
        service.scope = .library
        service.query = "Return"
        await service.performSearch(query: service.query)
        var history = BrowseNavigationHistory(initial: .section(.search))
        history.visit(.release("browse:detail"))
        service.cancelSearch()
        #expect(service.query == "Return")
        #expect(service.scope == .library)
        #expect(service.trackResults.map(\.id) == [snapshot.id])
        #expect(history.back() == .section(.search))
        service.retrySearch()
        for _ in 0..<100 where service.wasCancelled { await Task.yield() }
        #expect(!service.wasCancelled)
        #expect(service.query == "Return")
        #expect(service.scope == .library)
        #expect(service.trackResults.map(\.id) == [snapshot.id])
        #expect(history.forward() == .release("browse:detail"))
        #expect(remoteCalls == 0)
        service.cancelSearch()
    }

    @Test("Retained-query refresh reflects note and metadata edits without changing remote state")
    func localEditsRefreshWithoutRemoteRestart() async throws {
        let container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let first = Track(title: "Needle original", artist: "Artist", youTubeId: "abcdefghijk")
        let second = Track(title: "Other", artist: "Artist", youTubeId: "track_b0000")
        context.insert(first); context.insert(second)
        try context.save()
        let library = LibraryService(modelContainer: container)
        let notes = NotesService(modelContainer: container, enabledProvider: { true })
        #expect(notes.setTrackNote(trackId: first.id, content: "Needle old note"))
        var remoteCalls = 0
        let browser = MusicCatalogBrowser(provider: SearchStatusCatalogFixture(stale: false))
        let service = GlobalSearchService(library: library, notes: notes, debounceMs: 60_000,
            musicCatalog: browser, remoteSearch: { _, limit in
                remoteCalls += 1
                return (0..<limit).map { .init(id: String(format: "remote%05d", $0), title: "Remote") }
            })
        defer { service.cancelSearch() }
        service.query = "Needle"
        await service.performSearch(query: service.query)
        #expect(service.trackResults.map(\.id) == [first.id])
        #expect(service.noteResults.map(\.ownerId) == [first.id])
        let remote = service.youtubeResults
        #expect(remote.count == 20)
        let detail = MusicCatalogItem(id: "browse:retained", kind: .album, title: "Retained",
            subtitle: "", artwork: nil, artists: [], releases: [], channels: [])
        browser.open(detail)
        #expect(service.canLoadMore)
        #expect(library.updateTrack(id: first.id, title: "Removed match", artist: "Artist", albumTitle: nil,
            albumArtist: nil, trackNo: nil, discNo: nil, year: nil, genre: nil, lyrics: nil))
        #expect(library.updateTrack(id: second.id, title: "Needle added", artist: "Artist", albumTitle: nil,
            albumArtist: nil, trackNo: nil, discNo: nil, year: nil, genre: nil, lyrics: nil))
        #expect(notes.saveDraft(trackId: first.id, content: "", bookmarks: [],
            originalContent: "Needle old note", originalBookmarks: []))
        #expect(notes.saveDraft(trackId: second.id, content: "Needle fresh note", bookmarks: [],
            originalContent: "", originalBookmarks: []))
        service.refreshLibraryResults()
        #expect(service.trackResults.map(\.id) == [second.id])
        #expect(service.trackResults.first?.title == "Needle added")
        #expect(service.noteResults.map(\.ownerId) == [second.id])
        #expect(service.noteResults.first?.snippet == "Needle fresh note")
        #expect(service.query == "Needle" && service.scope == .all)
        #expect(remoteCalls == 1 && service.youtubeResults == remote)
        #expect(service.canLoadMore && !service.isSearchingYouTube)
        #expect(browser.detail == detail)
        service.loadMore()
        for _ in 0..<100 where service.isSearchingYouTube { await Task.yield() }
        #expect(remoteCalls == 2 && service.youtubeResults.count == 40)
        #expect(service.youtubeResults.prefix(20).map(\.id) == remote.map(\.id))
        #expect(browser.detail == detail)
        service.scope = .youtube
        service.refreshLibraryResults()
        #expect(service.trackResults.isEmpty && service.noteResults.isEmpty)
    }

    @Test("Saving a transient search result emits the established save invalidation and preserves its identity")
    func savedResultProjectionInvalidates() async throws {
        let container = try makeModelContainer(inMemory: true)
        let library = LibraryService(modelContainer: container)
        let resolver = YouTubeSearchService(bridge: MockImportBridge(), modelContainer: container)
        let entry = YTDlpBridge.YTDlpPlaylistEntry(id: "abcdefghijk", title: "Save Song")
        let preview = try await resolver.resolveTrack(entry: entry)
        #expect(library.allTracks().isEmpty)
        let projection = SavedSearchProjectionProbe()
        let token = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil,
                                                           queue: .main) { _ in
            MainActor.assumeIsolated {
                projection.ids = Set(library.allTracks().map(\.youTubeId))
                projection.notifications += 1
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }
        let saved = try await resolver.resolveTrack(entry: entry, saveToLibrary: true)
        #expect(saved.id == preview.id)
        #expect(projection.notifications > 0)
        #expect(projection.ids == [entry.id])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Track>()) == 1)
    }
}

@MainActor
private final class SavedSearchProjectionProbe {
    var ids = Set<String>()
    var notifications = 0
}

private actor SearchStatusCatalogFixture: MusicCatalogProviding {
    let stale: Bool
    init(stale: Bool) { self.stale = stale }
    func search(_ query: String, kind: MusicCatalogKind?) async throws -> MusicCatalogPage {
        .init(items: [.init(id: "video:abcdefghijk", kind: .song, title: "Song", subtitle: "",
                           artwork: nil, artists: [], releases: [], channels: [])],
              filters: [], next: nil, fetchedAt: Date(), region: "US",
              isStale: stale, refreshFailed: stale)
    }
    func browse(_ id: String) async throws -> MusicCatalogPage { try await search(id, kind: nil) }
    func next(_ cursor: MusicCatalogCursor) async throws -> MusicCatalogPage { throw MusicCatalogError.unavailable }
    func reset() {}
}
