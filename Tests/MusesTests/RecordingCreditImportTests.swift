import Foundation
import SwiftData
import Testing
@testable import Muses

@Suite("Recording credits after account import and reimport", .serialized)
@MainActor
struct RecordingCreditImportTests {
    @Test("cold account import reuses Track truth but resolves the retained old owner from exact video facts",
          arguments: [true, false])
    func coldOwnerCredit(verifiedArtist: Bool) async throws {
        let root = isolatedHomeTestDirectory("muses-recording-credit-")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let videoID = freshVideoID()
        let store = root.appendingPathComponent("library.sqlite")
        let ids = try seedDisk(store: store, videoID: videoID)
        let container = try makeModelContainer(storeURL: store)
        let sync = YouTubePlaylistSyncService(modelContainer: container, account: YouTubeAccountService(
            session: GoogleOAuthSession(keychain: InMemoryKeychain())), accountImportPreferences: nil)
        let channel = YouTubeChannel(id: "UC_B", title: "New account B", thumbnailURL: nil)
        let playlist = YouTubePlaylist(id: "PL_new_B", title: "New collection", thumbnailURL: nil, itemCount: 1)
        let remote = YouTubePlaylistSyncService.remoteSnapshot(
            playlistID: playlist.id, accountChannelID: channel.id, title: playlist.title,
            values: [.init(playlistItemId: "new-occurrence", videoId: videoID, title: "Remote title",
                           channelTitle: "Video publisher", thumbnailURL: nil)],
            pagination: .init(completeness: .complete, pageCount: 1, nextPageToken: nil, itemCount: 1))
        try sync.saveAccountPlaylist(playlist, channel: channel, snapshot: remote)
        let bridge = RecordingCreditBridge(videoID: videoID)
        bridge.metadataArtist = verifiedArtist ? "Verified performer" : nil
        let importer = service(bridge, container: container, root: root)
        let context = ModelContext(container)
        let active = try #require(context.fetch(FetchDescriptor<YouTubeImport>()).first { $0.deletedAt == nil })
        let item = try #require(active.items?.first)
        #expect(item.artist == "Video publisher")
        #expect(item.track?.id == ids.track)
        let track = try #require(item.track)
        let snapshot = TrackSnapshot(from: track)
        let metadata = await importer.songMetadata(videoID: videoID)
        let expectedArtist = verifiedArtist ? "Verified performer" : "Video publisher"
        #expect(SongCreditCache.shared.isCollectionOwner("Old account A", videoID: videoID))
        #expect(SongCreditCache.shared.artist(snapshot: snapshot, owner: active.channel) == expectedArtist)
        let row = try #require(importer.collectionSnapshot(importID: active.id)?.rows.first)
        #expect(SongDisplayInformation(row: row, metadata: metadata).artist == expectedArtist)
        let presentation = importer.songPresentationRow(for: snapshot)
        #expect(presentation.collectionOwner == "Old account A" && presentation.collectionTitle == nil)
        #expect(SongCreditCache.shared.historicalArtist(videoID: videoID, storedArtist: "Old account A") == expectedArtist)
        let saved = try #require(ModelContext(container).fetch(FetchDescriptor<Track>()).first)
        #expect(saved.id == ids.track && saved.artist == "Old account A" && saved.title == "Stored song")
        #expect(saved.liked && saved.playCount == 7 && saved.genre == "User genre" && saved.lyrics == "User lyrics")
        #expect(try context.fetch(FetchDescriptor<ListeningEvent>()).map(\.id) == [ids.event])
        #expect(try context.fetch(FetchDescriptor<YouTubeImport>()).first { $0.id == ids.importID }?.deletedAt != nil)
    }

    @Test("cached metadata and a shared in-flight request refresh newly committed owner context",
          arguments: [false, true])
    func ownerContextOnReuse(sharedFlight: Bool) async throws {
        let root = isolatedHomeTestDirectory("muses-recording-reuse-")
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try makeModelContainer(inMemory: true)
        let videoID = freshVideoID()
        let bridge = RecordingCreditBridge(videoID: videoID)
        bridge.holdMetadata = sharedFlight
        let importer = service(bridge, container: container, root: root)
        let first = Task { await importer.songMetadata(videoID: videoID) }
        if sharedFlight { try await bridge.waitUntilSuspended() }
        else { _ = await first.value }
        try seedRelations(container: container, videoID: videoID)
        let second = Task { await importer.songMetadata(videoID: videoID) }
        // The second caller must register facts before awaiting the shared request.
        for _ in 0..<20 { await Task.yield() }
        if sharedFlight { bridge.finishMetadata() }
        _ = await first.value
        _ = await second.value
        #expect(bridge.metadataCalls == 1)
        #expect(SongCreditCache.shared.isCollectionOwner("Old account A", videoID: videoID))
        let track = try #require(ModelContext(container).fetch(FetchDescriptor<Track>()).first)
        #expect(SongCreditCache.shared.artist(snapshot: TrackSnapshot(from: track)) == "Verified performer")
        #expect(track.artist == "Old account A")
    }

    @Test("an in-flight first caller refreshes owner relationships committed after its request began")
    func lateOwnerContext() async throws {
        let root = isolatedHomeTestDirectory("muses-recording-late-owner-")
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try makeModelContainer(inMemory: true)
        let videoID = freshVideoID()
        let bridge = RecordingCreditBridge(videoID: videoID)
        bridge.holdMetadata = true
        let importer = service(bridge, container: container, root: root)
        let request = Task { await importer.songMetadata(videoID: videoID) }
        try await bridge.waitUntilSuspended()
        try seedRelations(container: container, videoID: videoID)
        bridge.finishMetadata()
        _ = await request.value
        #expect(SongCreditCache.shared.isCollectionOwner("Old account A", videoID: videoID))
        let track = try #require(ModelContext(container).fetch(FetchDescriptor<Track>()).first)
        #expect(SongCreditCache.shared.artist(snapshot: TrackSnapshot(from: track)) == "Verified performer")
        #expect(bridge.metadataCalls == 1 && track.artist == "Old account A")
    }

    @Test("explicit URL reimport reads fresh source while preserving its tombstone and Track edits")
    func urlReimportDoesNotReturnTombstone() async throws {
        let root = isolatedHomeTestDirectory("muses-recording-reimport-")
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try makeModelContainer(inMemory: true)
        let videoID = freshVideoID()
        let ids = try seedRelations(container: container, videoID: videoID,
                                    playlistID: "PL_reimport", artist: "Hand edited performer")
        let bridge = RecordingCreditBridge(videoID: videoID)
        bridge.playlistEntries = [.init(id: videoID, title: "Fresh source title",
                                       uploader: "Video publisher", duration: 123, artist: "Verified performer")]
        let importer = service(bridge, container: container, root: root)
        let importedID = try await importer.importPlaylist(url: "https://music.youtube.com/playlist?list=PL_reimport")
        #expect(bridge.playlistCalls == 1)
        #expect(importedID != ids.importID)
        let context = ModelContext(container)
        let imports = try context.fetch(FetchDescriptor<YouTubeImport>())
        #expect(imports.count == 2)
        let old = try #require(imports.first { $0.id == ids.importID })
        let fresh = try #require(imports.first { $0.id == importedID })
        #expect(old.deletedAt != nil && fresh.deletedAt == nil)
        #expect(old.items?.first?.title == "Old source title" && old.items?.first?.order == 0)
        #expect(fresh.channel == "Actual playlist owner")
        #expect(fresh.items?.first?.track?.id == ids.track)
        #expect(fresh.items?.first?.artist == "Verified performer")
        let saved = try #require(context.fetch(FetchDescriptor<Track>()).first)
        #expect(saved.id == ids.track && saved.artist == "Hand edited performer" && saved.title == "Stored song")
        #expect(saved.liked && saved.playCount == 7 && saved.lyrics == "User lyrics")
        #expect(saved.durationMs == 240_000 && saved.albumTitle == "User album" && saved.albumArtist == "User album artist")
        // An already active import keeps the existing no-implicit-refresh behavior.
        #expect(try await importer.importPlaylist(url: "https://music.youtube.com/playlist?list=PL_reimport") == importedID)
        #expect(bridge.playlistCalls == 1)
    }

    @Test("authenticated reimport does not mistake a tombstone for the active account playlist")
    func accountReimportDoesNotSkipTombstone() throws {
        let container = try makeModelContainer(inMemory: true)
        let videoID = freshVideoID()
        let ids = try seedRelations(container: container, videoID: videoID, playlistID: "PL_reimport")
        let sync = YouTubePlaylistSyncService(modelContainer: container, account: YouTubeAccountService(
            session: GoogleOAuthSession(keychain: InMemoryKeychain())), accountImportPreferences: nil)
        let channel = YouTubeChannel(id: "UC_B", title: "New account B", thumbnailURL: nil)
        let playlist = YouTubePlaylist(id: "PL_reimport", title: "Fresh playlist", thumbnailURL: nil, itemCount: 1)
        let remote = YouTubePlaylistSyncService.remoteSnapshot(
            playlistID: playlist.id, accountChannelID: channel.id, title: playlist.title,
            values: [.init(playlistItemId: "fresh-item", videoId: videoID, title: "Fresh title",
                           channelTitle: "Video publisher", thumbnailURL: nil)],
            pagination: .init(completeness: .complete, pageCount: 1, nextPageToken: nil, itemCount: 1))
        try sync.saveAccountPlaylist(playlist, channel: channel, snapshot: remote)
        let context = ModelContext(container)
        let imports = try context.fetch(FetchDescriptor<YouTubeImport>())
        #expect(imports.count == 2)
        let fresh = try #require(imports.first { $0.deletedAt == nil })
        #expect(fresh.id != ids.importID && fresh.accountChannelID == "UC_B")
        #expect(fresh.items?.first?.track?.id == ids.track)
        #expect(fresh.items?.first?.artist == "Video publisher")
        #expect(imports.first { $0.id == ids.importID }?.deletedAt != nil)
        #expect(try context.fetch(FetchDescriptor<Track>()).first?.artist == "Old account A")
        try sync.saveAccountPlaylist(playlist, channel: channel, snapshot: remote)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<YouTubeImport>()) == 2)
    }

    @Test("account-local playlist identifiers distinguish known channels but keep unknown scope conservative",
          arguments: ["LL", "WL", "PL_global"])
    func accountLocalIdentity(playlistID: String) throws {
        let container = try makeModelContainer(inMemory: true)
        let ids = try seedRelations(container: container, videoID: freshVideoID(), playlistID: playlistID)
        let context = ModelContext(container)
        let existing = try #require(context.fetch(FetchDescriptor<YouTubeImport>()).first)
        existing.deletedAt = nil
        try context.save()
        let channel = YouTubeChannel(id: "UC_B", title: "New account B", thumbnailURL: nil)
        let playlist = YouTubePlaylist(id: playlistID, title: "Account collection", thumbnailURL: nil, itemCount: 0)
        let remote = YouTubePlaylistSyncService.remoteSnapshot(
            playlistID: playlistID, accountChannelID: channel.id, title: playlist.title, values: [],
            pagination: .init(completeness: .complete, pageCount: 1, nextPageToken: nil, itemCount: 0))
        let sync = syncService(container)
        try sync.saveAccountPlaylist(playlist, channel: channel, snapshot: remote)
        let expected = playlistID == "PL_global" ? 1 : 2
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<YouTubeImport>()) == expected)
        // Repeating the same channel read creates no alias; global IDs remain shared.
        try sync.saveAccountPlaylist(playlist, channel: channel, snapshot: remote)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<YouTubeImport>()) == expected)
        #expect(try ModelContext(container).fetch(FetchDescriptor<Track>()).first?.id == ids.track)

        // A public/legacy import has no proven channel scope: do not adopt it to B.
        let unknownContainer = try makeModelContainer(inMemory: true)
        let unknownContext = ModelContext(unknownContainer)
        let unknown = YouTubeImport(playlistId: playlistID, url: "public", title: "Unknown scope", channel: "Actual owner")
        unknownContext.insert(unknown)
        try unknownContext.save()
        try syncService(unknownContainer).saveAccountPlaylist(playlist, channel: channel, snapshot: remote)
        let saved = try #require(ModelContext(unknownContainer).fetch(FetchDescriptor<YouTubeImport>()).first)
        #expect(try ModelContext(unknownContainer).fetchCount(FetchDescriptor<YouTubeImport>()) == 1)
        #expect(saved.accountChannelID == nil && saved.channel == "Actual owner")
    }

    @Test("restoring a deleted source cannot alias its active reimport; distinct proven LL scopes can restore",
          arguments: [RestoreScope.global, .sameAccountLikes, .otherAccountLikes, .unknownLikes])
    func restoreCollision(scope: RestoreScope) throws {
        let container = try makeModelContainer(inMemory: true)
        let ids = try seedRelations(container: container, videoID: freshVideoID(), playlistID: scope.playlistID)
        let context = ModelContext(container)
        let old = try #require(context.fetch(FetchDescriptor<YouTubeImport>()).first)
        let snapshot = YouTubePlaylistSyncService.localSnapshot(old)
        let revision = YouTubePlaylistRevision(importID: old.id, accountChannelID: old.accountChannelID,
            kind: .beforeDelete, snapshotData: try JSONEncoder().encode(snapshot), fingerprint: snapshot.fingerprint)
        context.insert(revision)
        let active = YouTubeImport(playlistId: scope.playlistID, url: "new", title: "Active reimport",
            channel: "Active owner", accountChannelID: scope.activeChannelID)
        context.insert(active)
        try context.save()
        let sync = syncService(container)
        var caught: YouTubePlaylistSyncError?
        do { try sync.restore(revisionID: revision.id) }
        catch { caught = error as? YouTubePlaylistSyncError }
        let verify = ModelContext(container)
        let imports = try verify.fetch(FetchDescriptor<YouTubeImport>())
        let restored = try #require(imports.first { $0.id == ids.importID })
        let shouldBlock = scope != .otherAccountLikes
        #expect((caught != nil) == shouldBlock)
        #expect((restored.deletedAt != nil) == shouldBlock)
        #expect(restored.accountChannelID == "UC_A")
        #expect(imports.first { $0.id == active.id }?.accountChannelID == scope.activeChannelID)
        #expect(imports.count == 2)
        let kinds = try verify.fetch(FetchDescriptor<YouTubePlaylistRevision>()).map(\.kind)
        #expect(kinds.count == (shouldBlock ? 1 : 3))
        #expect(try verify.fetch(FetchDescriptor<YouTubeSyncBatch>()).isEmpty)
        #expect(try verify.fetch(FetchDescriptor<YouTubeSyncOperation>()).isEmpty)
        #expect(try verify.fetch(FetchDescriptor<Track>()).first?.id == ids.track)
        let copyID = try sync.restoreAsCopy(revisionID: revision.id, name: "Recovery copy")
        let copy = try #require(ModelContext(container).fetch(FetchDescriptor<Playlist>()).first { $0.id == copyID })
        #expect(copy.items?.first?.track?.id == ids.track)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<YouTubeImport>()) == 2)
    }

    @Test("exact retained owner facts never replace independent edits or unproven old strings")
    func unprovenCreditsStayIntact() {
        let cache = SongCreditCache()
        let videoID = freshVideoID()
        cache.recordOwner("Old account A", videoID: videoID)
        cache.store(.init(id: videoID, title: "Source title", uploader: "Video publisher", artist: "Verified performer"))
        let manual = TrackSnapshot(from: Track(title: "Edited title", artist: "My edited performer", youTubeId: videoID))
        #expect(cache.artist(snapshot: manual) == "My edited performer")
        #expect(cache.historicalArtist(videoID: videoID, storedArtist: "My edited performer") == "My edited performer")
        let otherVideoID = freshVideoID()
        cache.store(.init(id: otherVideoID, title: "Another title", uploader: "Video publisher", artist: "Verified performer"))
        let unproven = TrackSnapshot(from: Track(title: "Another title", artist: "Old account A", youTubeId: otherVideoID))
        #expect(cache.artist(snapshot: unproven) == "Old account A")
        #expect(!cache.isCollectionOwner("Old account A", videoID: otherVideoID))
    }

    @Test("retained owner credit facts do not displace an active collection's presentation title")
    func activePresentationContextWins() throws {
        let root = isolatedHomeTestDirectory("muses-recording-active-context-")
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try makeModelContainer(inMemory: true)
        let videoID = freshVideoID()
        let ids = try seedRelations(container: container, videoID: videoID)
        let context = ModelContext(container)
        let track = try #require(context.fetch(FetchDescriptor<Track>()).first)
        let active = YouTubeImport(playlistId: "PL_active", url: "active", title: "Current collection", channel: "Old account A")
        let activeItem = YouTubeImportItem(youTubeId: videoID, title: "Current source title", artist: "Video publisher", order: 0)
        activeItem.import_ = active
        activeItem.track = track
        active.items = [activeItem]
        context.insert(active)
        try context.save()
        let row = service(RecordingCreditBridge(videoID: videoID), container: container, root: root)
            .songPresentationRow(for: TrackSnapshot(from: track))
        #expect(row.collectionOwner == "Old account A" && row.collectionTitle == "Current collection")
        #expect(try ModelContext(container).fetch(FetchDescriptor<YouTubeImport>()).first { $0.id == ids.importID }?.deletedAt != nil)
    }

    private func syncService(_ container: ModelContainer) -> YouTubePlaylistSyncService {
        YouTubePlaylistSyncService(modelContainer: container, account: YouTubeAccountService(
            session: GoogleOAuthSession(keychain: InMemoryKeychain())), accountImportPreferences: nil)
    }

    private func freshVideoID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(11))
    }

    private func service(_ bridge: RecordingCreditBridge, container: ModelContainer, root: URL) -> YouTubeImportService {
        RecordingCreditProtocol.reset()
        RecordingCreditProtocol.install(RecordingCreditProtocol.response(for:))
        return YouTubeImportService(bridge: bridge, modelContainer: container,
            artworkCache: ArtworkCache(directory: root.appendingPathComponent("artwork")),
            session: URLSession(configuration: RecordingCreditProtocol.makeConfig()))
    }

    private func seedDisk(store: URL, videoID: String) throws -> CreditSeedIDs {
        let container = try makeModelContainer(storeURL: store)
        return try seedRelations(container: container, videoID: videoID)
    }

    @discardableResult
    private func seedRelations(container: ModelContainer, videoID: String,
                               playlistID: String = "PL_old_A", artist: String = "Old account A") throws -> CreditSeedIDs {
        let context = ModelContext(container)
        let track = Track(title: "Stored song", artist: artist, youTubeId: videoID,
                          lyrics: "User lyrics", playCount: 7, liked: true)
        track.genre = "User genre"
        track.durationMs = 240_000
        track.albumTitle = "User album"
        track.albumArtist = "User album artist"
        let old = YouTubeImport(playlistId: playlistID, url: "old", title: "Old collection",
                               channel: "Old account A", accountChannelID: "UC_A")
        old.deletedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let item = YouTubeImportItem(youTubeId: videoID, title: "Old source title", artist: "Old account A", order: 0)
        item.import_ = old
        item.track = track
        old.items = [item]
        let event = ListeningEvent(trackId: track.id, trackTitle: track.title,
            artist: track.artist, albumTitle: nil, startedAt: .init(), listenedMs: 1234, outcome: .completed)
        context.insert(track)
        context.insert(old)
        context.insert(event)
        try context.save()
        return .init(track: track.id, importID: old.id, event: event.id)
    }
}

enum RestoreScope: Sendable, Equatable {
    case global, sameAccountLikes, otherAccountLikes, unknownLikes
    var playlistID: String { self == .global ? "PL_reimport" : "LL" }
    var activeChannelID: String? {
        switch self {
        case .global, .otherAccountLikes: "UC_B"
        case .sameAccountLikes: "UC_A"
        case .unknownLikes: nil
        }
    }
}

private struct CreditSeedIDs {
    let track: UUID
    let importID: UUID
    let event: UUID
}

@MainActor
private final class RecordingCreditBridge: YTDlpBridgeProtocol {
    let videoID: String
    var metadataCalls = 0
    var playlistCalls = 0
    var holdMetadata = false
    var metadataArtist: String? = "Verified performer"
    var playlistEntries: [YTDlpBridge.YTDlpPlaylistEntry] = []
    private var continuation: CheckedContinuation<Void, Never>?
    init(videoID: String) { self.videoID = videoID }
    func fetchSongMetadata(videoId: String, timeout: TimeInterval) async throws -> YTDlpBridge.YTDlpPlaylistEntry? {
        metadataCalls += 1
        if holdMetadata { await withCheckedContinuation { continuation = $0 } }
        return .init(id: videoId, title: "Stored song", uploader: "Video publisher", artist: metadataArtist)
    }
    func waitUntilSuspended() async throws {
        for _ in 0..<100 where continuation == nil { try await Task.sleep(for: .milliseconds(10)) }
        try #require(continuation != nil)
    }
    func finishMetadata() { let held = continuation; continuation = nil; held?.resume() }
    func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] {
        playlistCalls += 1
        return playlistEntries
    }
    func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL {
        URL(string: "https://example.com/stream")!
    }
    func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] { [] }
    func version() async -> String? { "fixture" }
}

private final class RecordingCreditProtocol: StubURLProtocolBase, @unchecked Sendable {
    nonisolated(unsafe) private static var storedRules: [StubRule] = []
    private static let storedLock = NSLock()
    override class var rules: [StubRule] {
        get { storedRules } set { storedRules = newValue }
    }
    override class var lock: NSLock { storedLock }
    override class func canInit(with request: URLRequest) -> Bool { request.url != nil }
    static func install(_ response: @escaping (URLRequest) -> StubResponse) {
        storedLock.lock()
        defer { storedLock.unlock() }
        storedRules = [StubRule(matches: { _ in true }, respond: response)]
    }
    nonisolated static func response(for request: URLRequest) -> StubResponse {
        if request.url?.path == "/oembed" {
            let url = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "url" }?.value ?? ""
            let publisher = url.contains("playlist") ? "Actual playlist owner" : "Video publisher"
            let json = #"{"title":"Fresh source title","author_name":""# + publisher + #""}"#
            return StubResponse(statusCode: 200, body: Data(json.utf8))
        }
        return StubResponse(statusCode: 404, body: Data())
    }
}
