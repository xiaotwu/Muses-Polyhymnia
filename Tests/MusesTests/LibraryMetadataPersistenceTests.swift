import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Metadata save and collection refresh")
struct LibraryMetadataPersistenceTests {
    @Test("Failed metadata save emits no revision; same-service retry reprojects stable playlist occurrences")
    func failedSaveThenRefresh() throws {
        let container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let track = Track(title: "Original", artist: "Artist", youTubeId: "abcdefghijk", liked: true)
        let other = Track(title: "Other", artist: "Artist", youTubeId: "track_b0000")
        context.insert(track); context.insert(other)
        let playlists = PlaylistService(modelContainer: container)
        try context.save()
        let playlist = try #require(playlists.create(name: "Test", initialTrack: track))
        #expect(playlists.addTrack(playlist, track: other))
        let before = CollectionTrackRow.playlist(from: playlists.fetchItems(in: playlist.id))
        enum Failure: Error { case save }
        var attempts = 0
        var failedContext: ModelContext?
        let library = LibraryService(modelContainer: container, saveMetadataContext: { context in
            attempts += 1
            if attempts == 1 { failedContext = context; throw Failure.save }
            try context.save()
        })
        func save() -> Bool {
            library.updateTrack(id: track.id, title: "Updated", artist: "Edited artist",
                albumTitle: "Album", albumArtist: nil, trackNo: 3, discNo: 1,
                year: 2026, genre: "Genre", lyrics: "Lyrics")
        }
        #expect(!save())
        #expect(library.metadataRevision == 0)
        #expect(failedContext?.hasChanges == false && failedContext?.autosaveEnabled == false)
        #expect(CollectionTrackRow.playlist(from: playlists.fetchItems(in: playlist.id)) == before)
        #expect(library.track(by: track.id)?.title == "Original")
        #expect(save())
        #expect(attempts == 2 && library.metadataRevision == 1)
        let after = CollectionTrackRow.playlist(from: playlists.fetchItems(in: playlist.id))
        #expect(after.map(\.id) == before.map(\.id))
        #expect(after.map(\.canonicalIndex) == before.map(\.canonicalIndex))
        #expect(after.map(\.snapshot.id) == before.map(\.snapshot.id))
        #expect(after.first?.title == "Updated" && after.first?.snapshot.artist == "Edited artist")
        #expect(after.first?.year == 2026 && after.first?.genre == "Genre")
        #expect(after.last == before.last)
        let saved = try #require(library.track(by: track.id))
        #expect(saved.liked && saved.youTubeId == "abcdefghijk" && saved.isInLibrary)
        #expect(saved.artistCatalogID == nil && saved.releaseCatalogID == nil)
        #expect(saved.lyrics == "Lyrics" && saved.trackNo == 3 && saved.discNo == 1)
    }
}
