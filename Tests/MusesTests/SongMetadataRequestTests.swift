import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Song metadata requests and display ownership", .serialized)
struct SongMetadataRequestTests {
    @Test("Incomplete detailed metadata retains verified publisher and adds release fields")
    func incompleteMetadataRetainsCredits() {
        let cache = SongCreditCache()
        let id = "credit00001"
        cache.store(.init(id: id, title: "Song", uploader: "Actual uploader"))
        cache.store(.init(id: id, title: "Song", track: "Verified song", album: "Verified release", releaseYear: 2026))
        #expect(cache.entry(videoID: id)?.uploader == "Actual uploader")
        #expect(cache.entry(videoID: id)?.track == "Verified song")
        #expect(cache.entry(videoID: id)?.album == "Verified release")
        cache.store(.init(id: id, title: "Song", artist: "Verified performer"))
        #expect(cache.entry(videoID: id)?.artist == "Verified performer")
        #expect(cache.entry(videoID: id)?.uploader == "Actual uploader")
        #expect(cache.entry(videoID: id)?.releaseYear == 2026)
    }

    @Test("Visible metadata requests beyond eight finish without exceeding eight bridge calls")
    func queuedDistinctIdentities() async throws {
        let container = try makeModelContainer(inMemory: true)
        let bridge = SongMetadataRequestBridge()
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let service = makeService(bridge: bridge, container: container, session: session)
        let prefix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(5))
        let ids = (0..<16).map { prefix + String(format: "%06d", $0) }
        let entries = await withTaskGroup(of: YTDlpBridge.YTDlpPlaylistEntry?.self) { group in
            for id in ids { group.addTask { await service.songMetadata(videoID: id) } }
            var values: [YTDlpBridge.YTDlpPlaylistEntry] = []
            for await entry in group { if let entry { values.append(entry) } }
            return values
        }
        #expect(entries.count == ids.count)
        #expect(Set(entries.map(\.id)) == Set(ids))
        #expect(entries.contains { $0.id == ids[8] })
        #expect(bridge.calls.count == ids.count)
        #expect(bridge.calls.values.allSatisfy { $0 == 1 })
        #expect(bridge.peakActiveCalls <= 8)
        #expect(bridge.peakActiveCalls > 0)
        #expect(bridge.activeCalls == 0)
    }

    @Test("Simultaneous same-video consumers share one extraction and its cached result")
    func coalescesSameIdentity() async throws {
        let container = try makeModelContainer(inMemory: true)
        let bridge = SongMetadataRequestBridge()
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let service = makeService(bridge: bridge, container: container, session: session)
        let id = videoID()
        let entries = await withTaskGroup(of: YTDlpBridge.YTDlpPlaylistEntry?.self) { group in
            for _ in 0..<12 { group.addTask { await service.songMetadata(videoID: id) } }
            var values: [YTDlpBridge.YTDlpPlaylistEntry] = []
            for await entry in group { if let entry { values.append(entry) } }
            return values
        }
        #expect(entries.count == 12)
        #expect(entries.allSatisfy { $0.id == id && $0.artist == "Verified Performer" })
        #expect(bridge.calls[id] == 1)
        let cached = await service.songMetadata(videoID: id)
        #expect(cached?.id == id)
        #expect(bridge.calls[id] == 1)
    }

    @Test("Metadata records playlist owner and repairs only publisher-derived display credits")
    func ownerRegistrationDoesNotRewriteManualArtist() async throws {
        for detailed in [true, false] {
            let container = try makeModelContainer(inMemory: true)
            let context = ModelContext(container)
            let id = videoID()
            let track = Track(title: "Stored title", artist: "Playlist Publisher", youTubeId: id)
            let imported = YouTubeImport(playlistId: "PL" + id, url: "", title: "Saved playlist", channel: "Playlist Publisher")
            let item = YouTubeImportItem(youTubeId: id, title: "Stored title", artist: "Playlist Publisher")
            item.track = track
            imported.items = [item]
            context.insert(track)
            context.insert(imported)
            try context.save()
            let bridge = SongMetadataRequestBridge(returnsDetailedMetadata: detailed)
            let session = makeSession()
            defer { session.invalidateAndCancel() }
            let service = makeService(bridge: bridge, container: container, session: session)

            // Deliberately do not call songPresentationRow: metadata itself must register ownership.
            let metadata = try #require(await service.songMetadata(videoID: id))
            #expect(SongCreditCache.shared.isCollectionOwner("Playlist Publisher", videoID: id))
            #expect(metadata.uploader == "Video Publisher")
            let expectedArtist = detailed ? "Verified Performer" : "Video Publisher"
            let snapshot = TrackSnapshot(from: track)
            #expect(SongCreditCache.shared.artist(snapshot: snapshot) == expectedArtist)
            let previewRow = CollectionTrackRow(snapshot: snapshot, canonicalIndex: 0)
            #expect(previewRow.displayArtist == expectedArtist)
            let information = SongDisplayInformation(row: previewRow)
            #expect(information.artist == expectedArtist)
            #expect(information.title == "Stored title")
            let fresh = ModelContext(container)
            let stored = try #require(fresh.fetch(FetchDescriptor<Track>()).first)
            #expect(stored.artist == "Playlist Publisher")
            #expect(try fresh.fetch(FetchDescriptor<YouTubeImportItem>()).first?.artist == "Playlist Publisher")

            stored.artist = "My edited performer"
            try fresh.save()
            let edited = TrackSnapshot(from: stored)
            #expect(SongCreditCache.shared.artist(snapshot: edited) == "My edited performer")
            #expect(CollectionTrackRow(snapshot: edited, canonicalIndex: 0).displayArtist == "My edited performer")
            #expect(SongDisplayInformation(row: CollectionTrackRow(snapshot: edited, canonicalIndex: 0)).artist == "My edited performer")
            #expect(try ModelContext(container).fetch(FetchDescriptor<Track>()).first?.artist == "My edited performer")
        }
    }

    private func videoID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(11))
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SongMetadataRequestURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeService(bridge: SongMetadataRequestBridge, container: ModelContainer, session: URLSession) -> YouTubeImportService {
        YouTubeImportService(bridge: bridge, modelContainer: container,
            artworkCache: ArtworkCache(directory: FileManager.default.temporaryDirectory
                .appending(path: "muses-metadata-test-" + UUID().uuidString)), session: session)
    }
}

@MainActor
private final class SongMetadataRequestBridge: YTDlpBridgeProtocol {
    let returnsDetailedMetadata: Bool
    private(set) var calls: [String: Int] = [:]
    private(set) var activeCalls = 0
    private(set) var peakActiveCalls = 0

    init(returnsDetailedMetadata: Bool = true) { self.returnsDetailedMetadata = returnsDetailedMetadata }

    func fetchSongMetadata(videoId: String, timeout: TimeInterval) async throws -> YTDlpBridge.YTDlpPlaylistEntry? {
        calls[videoId, default: 0] += 1
        activeCalls += 1
        peakActiveCalls = max(peakActiveCalls, activeCalls)
        defer { activeCalls -= 1 }
        try await Task.sleep(for: .milliseconds(30))
        return returnsDetailedMetadata
            ? .init(id: videoId, title: "Video title", uploader: "Video Publisher", artist: "Verified Performer")
            : nil
    }

    func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL {
        throw URLError(.unsupportedURL)
    }
    func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] {
        throw URLError(.unsupportedURL)
    }
    func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] {
        throw URLError(.unsupportedURL)
    }
    func version() async -> String? { "test" }
}

/// Owns no mutable global rules and intercepts every request, including unexpected URLs.
private final class SongMetadataRequestURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, url.host == "www.youtube.com", url.path == "/oembed",
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"title":"Video title","author_name":"Video Publisher"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
