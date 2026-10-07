import Testing
import Foundation
import SwiftData
@testable import Muses

/// Playlist service CRUD + ordering tests.
@MainActor
@Suite("PlaylistService")
struct PlaylistServiceTests {

    @Test("Failed playlist mutations roll back membership and canonical order; atomic create retains no orphan")
    func mutationFailures() throws {
        let container = try makeContainer()
        let first = makeTrack(in: container, title: "First")
        let second = makeTrack(in: container, title: "Second")
        let working = PlaylistService(modelContainer: container)
        let playlist = try #require(working.create(name: "Original", initialTrack: first))
        #expect(working.addTrack(playlist, track: second))
        let items = working.fetchItems(in: playlist.id)
        let firstID = try #require(items.first?.id)
        let context = ModelContext(container)
        let outsider = Track(title: "Unchanged", artist: "Manual credit", youTubeId: "abcdefghijk", isInLibrary: false)
        context.insert(outsider)
        try context.save()
        enum Failure: Error { case diskFull }
        var attempts = 0
        let failing = PlaylistService(modelContainer: container, saveContext: { _ in
            attempts += 1; throw Failure.diskFull
        })
        #expect(failing.create(name: "Unsaved", initialTrack: outsider) == nil)
        #expect(!failing.addTrack(playlist, track: outsider))
        #expect(!failing.rename(playlist, to: "Unsaved name"))
        #expect(!failing.togglePin(playlist))
        #expect(!failing.moveItem(in: playlist, from: 0, to: 2))
        #expect(!failing.removeItem(id: firstID))
        #expect(failing.deleteWithUndoSnapshot(playlist) == nil)
        #expect(!failing.delete(playlist))
        #expect(attempts == 8)
        #expect(failing.lastError != nil)
        #expect(!failing.moveItem(in: playlist, from: -1, to: 0))
        #expect(!failing.moveItem(in: playlist, from: 0, to: -1))
        #expect(attempts == 8)
        let fresh = ModelContext(container)
        let persisted = try #require(fresh.fetch(FetchDescriptor<Playlist>()).first)
        #expect(try fresh.fetch(FetchDescriptor<Playlist>()).count == 1)
        #expect(persisted.name == "Original" && !persisted.pinned)
        #expect(working.fetchItems(in: playlist.id).map(\.id) == items.map(\.id))
        #expect(working.fetchItems(in: playlist.id).map(\.order) == [0, 1])
        let outsiderID = outsider.id
        let preserved = try #require(fresh.fetch(FetchDescriptor<Track>(predicate: #Predicate { $0.id == outsiderID })).first)
        #expect(!preserved.isInLibrary && preserved.artist == "Manual credit")
        failing.clearError()
        #expect(failing.lastError == nil)
        #expect(working.rename(playlist, to: "Retried"))
        #expect(working.removeItem(id: firstID))
        #expect(working.fetchItems(in: playlist.id).map(\.order) == [0])
    }

    private func makeContainer() throws -> ModelContainer {
        try makeModelContainer(inMemory: true)
    }

    private func makeTrack(in container: ModelContainer, title: String = "Test Track") -> Track {
        let ctx = ModelContext(container)
        let track = Track(title: title, artist: "Artist", durationMs: 200000, youTubeId: "test-video")
        ctx.insert(track)
        try? ctx.save()
        return track
    }

    @Test("create creates empty playlist")
    func createPlaylist() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)

        let playlist = try #require(service.create(name: "My Playlist"))
        #expect(playlist.name == "My Playlist")
        #expect(playlist.items == nil || playlist.items?.isEmpty == true)

        // Verify persistence
        let ctx = ModelContext(container)
        let playlists = try ctx.fetch(FetchDescriptor<Playlist>())
        #expect(playlists.count == 1)
        #expect(playlists.first?.name == "My Playlist")
    }

    @Test("addTrack appends track and deduplicates")
    func addTrackAndDedup() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)
        let track = makeTrack(in: container, title: "Song A")

        let playlist = try #require(service.create(name: "P1"))
        service.addTrack(playlist, track: track)

        // Verify there is 1 item
        let ctx = ModelContext(container)
        let p = try #require(try ctx.fetch(FetchDescriptor<Playlist>()).first)
        let items = (p.items ?? []).sorted { $0.order < $1.order }
        #expect(items.count == 1)
        #expect(items[0].order == 0)
        #expect(items[0].track?.title == "Song A")

        // Adding the same track again → deduped
        service.addTrack(playlist, track: track)
        let items2 = (p.items ?? [])
        #expect(items2.count == 1, "Deduplication: duplicate track should not be added")
    }

    @Test("open playlist membership refreshes after add and remove")
    func membershipChangesNotifyAndRefetch() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)
        let track = makeTrack(in: container, title: "First")
        let secondTrack = makeTrack(in: container, title: "Second")
        let thirdTrack = makeTrack(in: container, title: "Third")
        let playlist = try #require(service.create(name: "Visible playlist"))
        nonisolated(unsafe) var notifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .musesPlaylistsChanged, object: nil, queue: .main
        ) { _ in
            notifications += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        #expect(service.fetchItems(in: playlist.id).isEmpty)
        service.addTrack(playlist, track: track)
        let item = try #require(service.fetchItems(in: playlist.id).first)
        #expect(item.track?.id == track.id)
        #expect(notifications == 1)

        service.addTrack(playlist, track: secondTrack)
        service.addTrack(playlist, track: thirdTrack)
        #expect(service.fetchItems(in: playlist.id).map(\.track?.title) == ["First", "Second", "Third"])
        #expect(notifications == 3)

        let secondItem = try #require(service.fetchItems(in: playlist.id).first { $0.track?.id == secondTrack.id })
        service.removeItem(id: secondItem.id)
        let remaining = service.fetchItems(in: playlist.id)
        #expect(remaining.map(\.track?.title) == ["First", "Third"])
        #expect(remaining.map(\.order) == [0, 1])
        #expect(notifications == 4)

        service.removeItem(id: item.id)
        #expect(service.fetchItems(in: playlist.id).map(\.track?.title) == ["Third"])
        #expect(notifications == 5)
    }

    @Test("moveItem reorders items")
    func moveItemReorders() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)
        let t1 = makeTrack(in: container, title: "A")
        let t2 = makeTrack(in: container, title: "B")
        let t3 = makeTrack(in: container, title: "C")

        let playlist = try #require(service.create(name: "P2"))
        service.addTrack(playlist, track: t1)
        service.addTrack(playlist, track: t2)
        service.addTrack(playlist, track: t3)

        // Verify the initial order A B C
        let ctx = ModelContext(container)
        let p = try #require(try ctx.fetch(FetchDescriptor<Playlist>()).first)
        var items = (p.items ?? []).sorted { $0.order < $1.order }
        #expect(items.map { $0.track?.title } == ["A", "B", "C"])
        let originalIDs = items.map(\.id)

        // Move C (index 2) to index 0
        #expect(service.moveItem(in: p, from: 2, to: 0))
        // Mutation crosses a fresh context; active views re-fetch on notification.
        items = service.fetchItems(in: p.id)
        #expect(items.map(\.id) == [originalIDs[2], originalIDs[0], originalIDs[1]])
        #expect(items.map { $0.track?.title } == ["C", "A", "B"])
        #expect(items.map { $0.order } == [0, 1, 2])
    }

    @Test("Relative ordering targets current item identity despite sorted and stale rows")
    func relativeOrderingUsesIdentity() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)
        let playlist = try #require(service.create(name: "Ordered"))
        for title in ["Z", "A", "M"] {
            #expect(service.addTrack(playlist, track: makeTrack(in: container, title: title)))
        }
        let original = service.fetchItems(in: playlist.id)
        let ids = original.map(\.id)
        let trackIDs = original.map(\.track?.id)
        let rows = CollectionTrackRow.playlist(from: original)
        let sorted = CollectionTrackSort.presentationRows(rows, using: [
            KeyPathComparator(\.title, comparator: .localizedStandard)
        ])
        let selected = try #require(sorted.first)
        #expect(selected.collectionItemID == ids[1])
        #expect(service.moveItem(id: ids[1], in: playlist.id, by: 1))
        #expect(service.fetchItems(in: playlist.id).map(\.id) == [ids[0], ids[2], ids[1]])
        // Reuse the original presentation after a concurrent reorder. The
        // occurrence moves from its current position, not its old index.
        #expect(service.moveItem(id: ids[1], in: playlist.id, by: -1))
        #expect(service.fetchItems(in: playlist.id).map(\.id) == ids)
        #expect(service.fetchItems(in: playlist.id).map(\.track?.id) == trackIDs)
        #expect(service.fetchItems(in: playlist.id).map(\.order) == [0, 1, 2])
        let other = try #require(service.create(name: "Other"))
        #expect(!service.moveItem(id: ids[1], in: other.id, by: -1))
        #expect(!service.moveItem(id: ids[0], in: playlist.id, by: -1))
        #expect(!service.moveItem(id: ids[2], in: playlist.id, by: 1))
        #expect(!service.moveItem(id: ids[1], in: playlist.id, by: Int.max))
        #expect(service.removeItem(id: ids[1]))
        #expect(!service.moveItem(id: ids[1], in: playlist.id, by: -1))
        #expect(service.fetchItems(in: playlist.id).map(\.id) == [ids[0], ids[2]])
        #expect(service.fetchItems(in: other.id).isEmpty)
    }

    @Test("Failed relative movement retains canonical membership and can be retried")
    func relativeOrderingRollsBack() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)
        let playlist = try #require(service.create(name: "Preserved"))
        for title in ["A", "B", "C"] {
            #expect(service.addTrack(playlist, track: makeTrack(in: container, title: title)))
        }
        #expect(service.togglePin(playlist))
        let original = service.fetchItems(in: playlist.id)
        let ids = original.map(\.id)
        let tracks = original.map(\.track?.id)
        enum Failure: Error { case diskFull }
        var attempts = 0
        let failing = PlaylistService(modelContainer: container, saveContext: { _ in
            attempts += 1
            throw Failure.diskFull
        })
        #expect(!failing.moveItem(id: ids[1], in: playlist.id, by: -1))
        #expect(attempts == 1 && failing.lastError != nil)
        #expect(service.fetchItems(in: playlist.id).map(\.id) == ids)
        #expect(service.fetchItems(in: playlist.id).map(\.track?.id) == tracks)
        #expect(service.fetchItems(in: playlist.id).map(\.order) == [0, 1, 2])
        let persisted = try #require(ModelContext(container).fetch(FetchDescriptor<Playlist>()).first)
        #expect(persisted.id == playlist.id && persisted.name == "Preserved" && persisted.pinned)
        #expect(persisted.createdAt == playlist.createdAt)
        #expect(service.moveItem(id: ids[1], in: playlist.id, by: -1))
        #expect(service.fetchItems(in: playlist.id).map(\.id) == [ids[1], ids[0], ids[2]])
        #expect(service.fetchItems(in: playlist.id).map(\.order) == [0, 1, 2])
    }

    @Test("delete cascades playlist items")
    func deleteCascadesItems() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)
        let track = makeTrack(in: container, title: "Doomed Song")

        let playlist = try #require(service.create(name: "To Delete"))
        service.addTrack(playlist, track: track)

        // Verify there is 1 item
        let ctx = ModelContext(container)
        #expect(try ctx.fetch(FetchDescriptor<PlaylistItem>()).count == 1)

        // Delete the playlist
        service.delete(playlist)

        // Playlist + items must disappear; the Track survives (nullify)
        #expect(try ctx.fetch(FetchDescriptor<Playlist>()).count == 0)
        #expect(try ctx.fetch(FetchDescriptor<PlaylistItem>()).count == 0)
        #expect(try ctx.fetch(FetchDescriptor<Track>()).count == 1, "Track should be preserved (nullify)")
    }

    @Test("deleteWithUndoSnapshot restores order and pinned state")
    func deleteAndUndoRestoresPlaylist() throws {
        let container = try makeContainer()
        let service = PlaylistService(modelContainer: container)
        let a = makeTrack(in: container, title: "A")
        let b = makeTrack(in: container, title: "B")
        let playlist = try #require(service.create(name: "Recover me"))
        service.addTrack(playlist, track: a)
        service.addTrack(playlist, track: b)
        service.togglePin(playlist)

        let snapshot = try #require(service.deleteWithUndoSnapshot(playlist))
        #expect(try ModelContext(container).fetch(FetchDescriptor<Playlist>()).isEmpty)
        let restored = try #require(service.restore(snapshot))
        #expect(restored.name == "Recover me")
        #expect(restored.pinned)
        #expect((restored.items ?? []).sorted { $0.order < $1.order }
            .compactMap { $0.track?.title } == ["A", "B"])
    }
}
