import Foundation
import SwiftData
import Observation

/// Complete local-only information needed to undo a playlist deletion during
/// the current session. It deliberately stores identifiers rather than model
/// objects so restoration can use a fresh SwiftData context.
struct PlaylistDeletionSnapshot: Sendable, Equatable {
    struct Item: Sendable, Equatable {
        let order: Int
        let trackID: UUID?
    }

    let name: String
    let createdAt: Date
    let pinned: Bool
    let items: [Item]
}

/// Playlist CRUD + ordering service.
///
/// Mirrors the `YouTubeImportService` pattern: `@MainActor @Observable`, a fresh `ModelContext` per operation,
/// and atomic saves that preserve existing truth on failure.
@Observable
@MainActor
final class PlaylistService {
    private let modelContainer: ModelContainer
    private let log = AppLog.for("PlaylistService")
    private let saveContext: (ModelContext) throws -> Void
    private(set) var loadState: LoadState<[Playlist]> = .idle
    private(set) var lastError: String?

    init(modelContainer: ModelContainer, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.modelContainer = modelContainer
        self.saveContext = saveContext
    }

    func clearError() { lastError = nil }

    private func editingContext() -> ModelContext {
        lastError = nil
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        return context
    }

    private func failed() -> Bool {
        lastError = tr("Playlist changes could not be saved. Your existing playlist is unchanged; try again.",
                       "无法保存歌单更改，原有歌单未改变，请重试。")
        return false
    }

    private func commit(_ context: ModelContext) -> Bool {
        do { try saveContext(context); notifyPlaylistsChanged(); return true }
        catch { context.rollback(); return failed() }
    }

    // MARK: - Playlist CRUD

    /// Creates a playlist and returns the new `Playlist`.
    @discardableResult
    func create(name: String, initialTrack: Track? = nil) -> Playlist? {
        let ctx = editingContext()
        let playlist = Playlist(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !playlist.name.isEmpty else { _ = failed(); return nil }
        ctx.insert(playlist)
        if let initialTrack {
            let id = initialTrack.id
            guard let track = try? ctx.fetch(FetchDescriptor<Track>(predicate: #Predicate { $0.id == id })).first else {
                ctx.rollback(); _ = failed(); return nil
            }
            track.libraryMember = true
            let item = PlaylistItem(order: 0, playlist: playlist, track: track)
            ctx.insert(item)
            playlist.items = [item]
        }
        guard commit(ctx) else { return nil }
        return playlist
    }

    /// Renames a playlist.
    @discardableResult
    func rename(_ playlist: Playlist, to newName: String) -> Bool {
        let ctx = editingContext()
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = playlist.id
        guard !trimmed.isEmpty, let stored = try? ctx.fetch(FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == id })).first else { return failed() }
        stored.name = trimmed
        return commit(ctx)
    }

    /// Deletes a playlist (cascades to its items).
    @discardableResult
    func delete(_ playlist: Playlist) -> Bool {
        // Materialize the occurrence snapshot before cascading deletion,
        // including retries after a rolled-back delete.
        deleteWithUndoSnapshot(playlist) != nil
    }

    /// Deletes a local playlist and returns a one-session restore capsule.
    /// The playlist's tracks remain untouched; detached item rows are restored
    /// as such if their track was removed in the meantime.
    func deleteWithUndoSnapshot(_ playlist: Playlist) -> PlaylistDeletionSnapshot? {
        let ctx = editingContext()
        let id = playlist.id
        let descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == id })
        guard let stored = try? ctx.fetch(descriptor).first else { _ = failed(); return nil }

        let snapshot = PlaylistDeletionSnapshot(
            name: stored.name,
            createdAt: stored.createdAt,
            pinned: stored.pinned,
            items: (stored.items ?? []).sorted { $0.order < $1.order }.map {
                .init(order: $0.order, trackID: $0.track?.id)
            }
        )
        ctx.delete(stored)
        return commit(ctx) ? snapshot : nil
    }

    /// Restores a deletion capsule once. Missing tracks remain represented by
    /// a detached playlist item, matching the model's existing nullify rule.
    @discardableResult
    func restore(_ snapshot: PlaylistDeletionSnapshot) -> Playlist? {
        let ctx = editingContext()
        let restored = Playlist(name: snapshot.name, createdAt: snapshot.createdAt,
                                pinned: snapshot.pinned)
        ctx.insert(restored)
        var restoredItems: [PlaylistItem] = []
        for item in snapshot.items {
            let track: Track?
            if let id = item.trackID {
                track = try? ctx.fetch(FetchDescriptor<Track>(
                    predicate: #Predicate { $0.id == id }
                )).first
            } else {
                track = nil
            }
            let restoredItem = PlaylistItem(order: item.order, playlist: restored, track: track)
            ctx.insert(restoredItem)
            restoredItems.append(restoredItem)
        }
        restored.items = restoredItems
        return commit(ctx) ? restored : nil
    }

    private func notifyPlaylistsChanged() {
        NotificationCenter.default.post(name: .musesPlaylistsChanged, object: nil)
    }

    /// Fetches all playlists (newest first by creation time).
    func fetchAll() -> [Playlist] {
        let previous = loadState.value
        loadState = .loading(previous: previous)
        let ctx = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        do {
            let values = try ctx.fetch(descriptor)
            loadState = values.isEmpty ? .empty : .content(values)
            return values
        } catch {
            loadState = .failure(message: error.localizedDescription,
                                 staleValue: previous)
            return previous ?? []
        }
    }

    /// Loads current membership from a fresh context so an open detail view
    /// can observe edits made through another surface.
    func fetchItems(in playlistID: UUID) -> [PlaylistItem] {
        let ctx = ModelContext(modelContainer)
        guard let playlist = try? ctx.fetch(FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.id == playlistID }
        )).first else { return [] }
        return (playlist.items ?? []).sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    // MARK: - Item management

    /// Appends a track to a playlist (order = max + 1).
    @discardableResult
    func addTrack(_ playlist: Playlist, track: Track) -> Bool {
        let ctx = editingContext()
        let playlistId = playlist.id
        let trackId = track.id

        // Fetch persistent references for playlist + track in the new context
        guard let p = try? ctx.fetch(FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.id == playlistId }
        )).first else { return failed() }
        guard let t = try? ctx.fetch(FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == trackId }
        )).first else { return failed() }

        // Deduplicate: skip if the same track is already in the playlist
        let existingTrackIds = (p.items ?? []).compactMap { $0.track?.id }
        if existingTrackIds.contains(trackId) { return true }

        t.libraryMember = true
        let nextOrder = (p.items ?? []).map { $0.order }.max() ?? -1
        let item = PlaylistItem(order: nextOrder + 1, playlist: p, track: t)
        ctx.insert(item)
        if var items = p.items {
            items.append(item)
            p.items = items
        } else {
            p.items = [item]
        }
        return commit(ctx)
    }

    /// Removes an item from a playlist (deletes it and renumbers the remaining order).
    @discardableResult
    func removeItem(_ item: PlaylistItem) -> Bool {
        removeItem(id: item.id)
    }

    @discardableResult
    func removeItem(id itemId: UUID) -> Bool {
        let ctx = editingContext()
        guard let i = try? ctx.fetch(FetchDescriptor<PlaylistItem>(
            predicate: #Predicate { $0.id == itemId }
        )).first else { return failed() }
        let playlist = i.playlist
        if let playlist {
            let items = (playlist.items ?? []).filter { $0.id != itemId }.sorted { $0.order < $1.order }
            for (idx, item) in items.enumerated() {
                item.order = idx
            }
            playlist.items = items
        }
        ctx.delete(i)
        return commit(ctx)
    }

    /// Moves the entry at `from` to `to` and renumbers order.
    @discardableResult
    func moveItem(in playlist: Playlist, from: Int, to: Int) -> Bool {
        let ctx = editingContext()
        let id = playlist.id
        guard let stored = try? ctx.fetch(FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == id })).first,
              var items = stored.items?.sorted(by: { $0.order < $1.order }),
              from >= 0, from < items.count, to >= 0, to <= items.count else { return failed() }
        let item = items.remove(at: from)
        items.insert(item, at: min(to, items.count))
        for (idx, item) in items.enumerated() {
            item.order = idx
        }
        stored.items = items
        return commit(ctx)
    }

    /// Resolves the selected occurrence against current membership before a
    /// relative move; a sorted or stale presentation index is never authority.
    @discardableResult
    func moveItem(id itemID: UUID, in playlistID: UUID, by offset: Int) -> Bool {
        let ctx = editingContext()
        guard offset == -1 || offset == 1,
              let stored = try? ctx.fetch(FetchDescriptor<Playlist>(
                predicate: #Predicate { $0.id == playlistID }
              )).first else { return failed() }
        var items = (stored.items ?? []).sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
        guard let from = items.firstIndex(where: { $0.id == itemID }),
              items.indices.contains(from + offset) else { return failed() }
        let item = items.remove(at: from)
        items.insert(item, at: from + offset)
        for (index, entry) in items.enumerated() { entry.order = index }
        stored.items = items
        return commit(ctx)
    }

    // MARK: - Pins

    /// Toggles a playlist's pinned state.
    @discardableResult
    func togglePin(_ playlist: Playlist) -> Bool {
        let ctx = editingContext()
        let id = playlist.id
        guard let p = try? ctx.fetch(FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.id == id }
        )).first else { return failed() }
        p.pinned.toggle()
        return commit(ctx)
    }

    /// Fetches pinned playlists (sorted by name).
    func pinnedPlaylists() -> [Playlist] {
        let ctx = ModelContext(modelContainer)
        let desc = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.pinned == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? ctx.fetch(desc)) ?? []
    }

}
