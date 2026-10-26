import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Playlist membership and recovery UX")
struct PlaylistMembershipUXTests {
    @Test("Songs includes unplayed imports and deduplicates active playlist membership")
    func unionIncludesLazyItems() throws {
        let container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let trackAddedAt = Date(timeIntervalSince1970: 1_600_000_000)
        let track = Track(title: "Alpha", artist: "Artist", year: 2020, genre: "Jazz",
                          youTubeId: "shared", addedAt: trackAddedAt, playCount: 5)
        let orphan = Track(title: "Orphan", artist: "Artist", youTubeId: "orphan")
        let local = Playlist(name: "Local")
        context.insert(track)
        context.insert(orphan)
        context.insert(local)
        let membership = PlaylistItem(order: 0, playlist: local, track: track)
        context.insert(membership)
        local.items = [membership]
        let imported = YouTubeImport(playlistId: "PL-test", url: "https://youtube.com/playlist?list=PL-test",
                                     title: "Imported", channel: "Artist")
        context.insert(imported)
        let duplicate = YouTubeImportItem(youTubeId: "shared", title: "Alpha", artist: "Artist")
        let lazy = YouTubeImportItem(youTubeId: "lazy", title: "Zulu", artist: "Artist")
        for item in [duplicate, lazy] { context.insert(item); item.import_ = imported }
        imported.items = [duplicate, lazy]
        try context.save()
        let union = CollectionTrackRow.playlistUnion(playlists: [local], imports: [imported])
        #expect(union.map(\.snapshot.youTubeId) == ["shared", "lazy"])
        #expect(union.map(\.canonicalIndex) == [0, 1])
        #expect(union.first?.year == 2020)
        #expect(union.first?.genre == "Jazz")
        #expect(union.first?.playCount == 5)
        #expect(union.first?.addedAt == trackAddedAt)
        imported.deletedAt = .now
        #expect(CollectionTrackRow.playlistUnion(playlists: [local], imports: [imported])
            .map(\.snapshot.youTubeId) == ["shared"])
        #expect(CollectionTrackRow.playlistUnion(playlists: [], imports: [imported]).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Track>()) == 2)
        let library = LibraryService(modelContainer: container)
        let lazySnapshot = try #require(union.last?.snapshot)
        library.toggleLike(snapshot: lazySnapshot)
        #expect(library.likedSnapshotIDs(for: [lazySnapshot]) == [lazySnapshot.id])
        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<Track>()) == 3)
        #expect(try verify.fetch(FetchDescriptor<YouTubeImportItem>())
            .first(where: { $0.youTubeId == "lazy" })?.track?.liked == true)
        library.toggleLike(snapshot: lazySnapshot)
        #expect(library.likedSnapshotIDs(for: [lazySnapshot]).isEmpty)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Track>()) == 3)
    }

    @Test("Materialized import metadata survives Songs projection and visual sorting")
    func materializedImportMetadataSurvivesProjectionAndSorting() throws {
        let container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let trackAddedAt = Date(timeIntervalSince1970: 1_600_000_000)
        let importedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let alpha = Track(title: "Alpha", artist: "Artist", year: 2020, genre: "Jazz",
                          youTubeId: "alpha", addedAt: trackAddedAt, playCount: 4)
        let zulu = Track(title: "Zulu", artist: "Artist", year: 2024, genre: "Rock",
                         youTubeId: "zulu", addedAt: trackAddedAt, playCount: 11)
        let imported = YouTubeImport(playlistId: "PL-materialized",
            url: "https://youtube.com/playlist?list=PL-materialized",
            title: "Imported", channel: "Importer", importedAt: importedAt)
        context.insert(alpha)
        context.insert(zulu)
        context.insert(imported)
        let zuluItem = YouTubeImportItem(youTubeId: "zulu", title: "Import Zulu",
                                         artist: "Uploader", order: 0)
        let lazyItem = YouTubeImportItem(youTubeId: "bravo", title: "Bravo",
                                         artist: "Artist", durationMs: 180_000, order: 1)
        let alphaItem = YouTubeImportItem(youTubeId: "alpha", title: "Import Alpha",
                                          artist: "Uploader", order: 2)
        for item in [zuluItem, lazyItem, alphaItem] {
            context.insert(item)
            item.import_ = imported
        }
        zuluItem.track = zulu
        alphaItem.track = alpha
        imported.items = [zuluItem, lazyItem, alphaItem]
        try context.save()

        let projectionContext = ModelContext(container)
        let savedImport = try #require(try projectionContext.fetch(FetchDescriptor<YouTubeImport>()).first)
        let rows = CollectionTrackRow.playlistUnion(playlists: [], imports: [savedImport])
        #expect(rows.map(\.title) == ["Alpha", "Bravo", "Zulu"])
        #expect(rows.map(\.canonicalIndex) == [0, 1, 2])
        #expect(rows.map(\.snapshot.id) == [alpha.id, lazyItem.id, zulu.id])
        #expect(rows.map(\.snapshot.youTubeId) == ["alpha", "bravo", "zulu"])
        #expect(rows.map(\.year) == [2020, nil, 2024])
        #expect(rows.map(\.genre) == ["Jazz", nil, "Rock"])
        #expect(rows.map(\.playCount) == [4, 0, 11])
        #expect(rows.allSatisfy {
            $0.addedAt == importedAt && $0.collectionOwner == "Importer"
                && $0.collectionTitle == "Imported" && $0.collectionItemID == nil
        })
        let lazyRow = try #require(rows.first(where: { $0.snapshot.youTubeId == "bravo" }))
        #expect(lazyRow.snapshot.durationSeconds == 180)

        let sorted = CollectionTrackSort.rows(rows, using: [
            KeyPathComparator(\CollectionTrackRow.playCount, order: .reverse)
        ])
        #expect(sorted.map(\.title) == ["Zulu", "Alpha", "Bravo"])
        #expect(sorted.map(\.canonicalIndex) == [2, 0, 1])
        #expect(rows.map(\.title) == ["Alpha", "Bravo", "Zulu"])
        #expect(!projectionContext.hasChanges)

        let verify = ModelContext(container)
        let savedTracks = try verify.fetch(FetchDescriptor<Track>())
        #expect(savedTracks.count == 2)
        #expect(Dictionary(uniqueKeysWithValues: savedTracks.map { ($0.id, $0.playCount) })
            == [alpha.id: 4, zulu.id: 11])
        let savedItems = try verify.fetch(FetchDescriptor<YouTubeImportItem>(sortBy: [SortDescriptor(\.order)]))
        #expect(savedItems.map(\.id) == [zuluItem.id, lazyItem.id, alphaItem.id])
        #expect(savedItems.map(\.order) == [0, 1, 2])
        #expect(savedItems.map { $0.track?.id } == [zulu.id, nil, alpha.id])
    }

    @Test("Clearing deleted playlists removes recovery records while retaining tracks")
    func clearRecovery() throws {
        let container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let track = Track(title: "Keep", artist: "Artist", youTubeId: "keep")
        context.insert(track)
        let imported = YouTubeImport(playlistId: "PL-test", url: "https://youtube.com/playlist?list=PL-test",
                                     title: "Imported", channel: "Artist")
        context.insert(imported)
        let item = YouTubeImportItem(youTubeId: "keep", title: "Keep", artist: "Artist")
        context.insert(item)
        item.import_ = imported
        item.track = track
        imported.items = [item]
        try context.save()
        let id = imported.id
        let service = YouTubePlaylistSyncService(modelContainer: container,
            account: YouTubeAccountService(session: GoogleOAuthSession(keychain: InMemoryKeychain())))
        #expect(throws: YouTubePlaylistSyncError.self) {
            try service.permanentlyDeleteLocalImports(ids: [id])
        }
        try service.moveToRecentlyDeleted(importID: id)
        #expect(!(try service.revisions(importID: id)).isEmpty)
        let journalContext = ModelContext(container)
        let batch = YouTubeSyncBatch(importID: id, accountChannelID: nil,
            playlistID: "PL-test", baseRevisionID: UUID(), localRevisionID: UUID(),
            remoteRevisionID: UUID(), expectedRemoteFingerprint: "test",
            desiredSnapshotData: Data(), preRemoteSnapshotData: Data())
        batch.state = .started
        journalContext.insert(batch)
        try journalContext.save()
        #expect(throws: YouTubePlaylistSyncError.self) {
            try service.permanentlyDeleteLocalImports(ids: [id])
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<YouTubeImport>()) == 1)
        batch.state = .locallyCommitted
        try journalContext.save()
        try service.permanentlyDeleteLocalImports(ids: [id])
        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<YouTubeImport>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<YouTubeImportItem>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<YouTubePlaylistRevision>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<YouTubeSyncBatch>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<Track>()) == 1)
    }
}
