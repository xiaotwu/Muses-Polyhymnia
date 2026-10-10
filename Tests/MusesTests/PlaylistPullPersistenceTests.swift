import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Pull persistence boundary", .serialized)
struct PlaylistPullPersistenceTests {
    enum Failure: Error { case save }

    @Test("Pull stages revision pruning and Local/Base in one save")
    func oneCommitIncludesPruning() throws {
        let (container, preview, oldIDs) = try fixture()
        var saves = 0
        let service = makeService(container) { context in
            saves += 1
            if saves > 1 { throw Failure.save }
            try context.save()
        }
        try service.applyPull(preview)
        #expect(saves == 1)
        let context = ModelContext(container)
        let stored = try #require(context.fetch(FetchDescriptor<YouTubeImport>()).first)
        #expect(stored.baseRevisionID != preview.baseRevisionID)
        #expect(YouTubePlaylistSyncService.localSnapshot(stored).items.map(\.videoID) == ["new-video"])
        let remaining = try context.fetch(FetchDescriptor<YouTubePlaylistRevision>())
        #expect(remaining.count == 50)
        #expect(Set(remaining.map(\.id)).intersection(oldIDs).count < oldIDs.count)
    }

    @Test("Failed Pull rolls back all staged rows and remains retryable on the same service")
    func failedCommitThenRetry() throws {
        let (container, preview, _) = try fixture()
        var saves = 0
        var failedContext: ModelContext?
        let service = makeService(container) { context in
            saves += 1
            if saves == 1 { failedContext = context; throw Failure.save }
            try context.save()
        }
        nonisolated(unsafe) var notifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .musesPlaylistsChanged, object: nil, queue: .main
        ) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        #expect(throws: Failure.self) { try service.applyPull(preview) }
        #expect(failedContext?.hasChanges == false)
        #expect(failedContext?.autosaveEnabled == false)
        #expect(notifications == 0)
        let beforeRetry = ModelContext(container)
        let original = try #require(beforeRetry.fetch(FetchDescriptor<YouTubeImport>()).first)
        #expect(original.baseRevisionID == preview.baseRevisionID)
        #expect(original.lastSyncedAt == nil)
        #expect(YouTubePlaylistSyncService.localSnapshot(original).items.map(\.videoID) == ["old-video"])
        #expect(try beforeRetry.fetchCount(FetchDescriptor<YouTubePlaylistRevision>()) == 63)
        #expect(try beforeRetry.fetchCount(FetchDescriptor<Track>()) == 0)
        try service.applyPull(preview)
        #expect(saves == 2)
        #expect(notifications == 1)
        let afterRetry = ModelContext(container)
        let changed = try #require(afterRetry.fetch(FetchDescriptor<YouTubeImport>()).first)
        #expect(changed.baseRevisionID != preview.baseRevisionID)
        #expect(YouTubePlaylistSyncService.localSnapshot(changed).items.map(\.videoID) == ["new-video"])
        #expect(try afterRetry.fetchCount(FetchDescriptor<YouTubePlaylistRevision>()) == 50)
    }

    private func makeService(_ container: ModelContainer,
                             save: @escaping (ModelContext) throws -> Void) -> YouTubePlaylistSyncService {
        YouTubePlaylistSyncService(modelContainer: container,
            account: YouTubeAccountService(session: GoogleOAuthSession(keychain: InMemoryKeychain())),
            accountImportPreferences: nil, savePullContext: save)
    }

    private func fixture() throws -> (ModelContainer, YouTubePullPreview, Set<UUID>) {
        let container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let imported = YouTubeImport(playlistId: "PL-pull-persistence", url: "", title: "Test", channel: "Owner")
        let old = YouTubeImportItem(youTubeId: "old-video", title: "Old", artist: "Artist", order: 0)
        old.import_ = imported; imported.items = [old]
        context.insert(imported); context.insert(old)
        let local = YouTubePlaylistSyncService.localSnapshot(imported)
        var remote = local
        remote.items = [.init(id: UUID(), playlistItemID: "pi-new", videoID: "new-video",
            title: "New", artist: "Artist", durationMs: 1, order: 0, availability: .available)]
        remote.pagination = .init(completeness: .complete, pageCount: 1, nextPageToken: nil, itemCount: 1)
        func revision(_ kind: YouTubePlaylistRevisionKind, _ value: YouTubePlaylistSnapshot,
                      createdAt: Date = .init()) throws -> YouTubePlaylistRevision {
            let result = YouTubePlaylistRevision(importID: imported.id, accountChannelID: nil,
                kind: kind, createdAt: createdAt, snapshotData: try JSONEncoder().encode(value),
                fingerprint: value.fingerprint)
            context.insert(result)
            return result
        }
        let base = try revision(.base, local)
        let draft = try revision(.local, local)
        let shadow = try revision(.remoteShadow, remote)
        var oldIDs = Set<UUID>()
        for index in 0..<60 {
            oldIDs.insert(try revision(.local, local,
                createdAt: Date(timeIntervalSince1970: Double(index))).id)
        }
        imported.baseRevisionID = base.id; imported.remoteShadowRevisionID = shadow.id
        try context.save()
        let preview = YouTubePullPreview(importID: imported.id, baseRevisionID: base.id,
            localRevisionID: draft.id, remoteRevisionID: shadow.id, base: local, local: local,
            remote: remote, automaticResult: remote,
            mergePlan: YouTubePlaylistThreeWayMerge.plan(base: local, local: local, remote: remote))
        return (container, preview, oldIDs)
    }
}
