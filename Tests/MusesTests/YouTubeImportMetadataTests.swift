import Testing
import Foundation
import SwiftData
@testable import Muses

/// YouTube oEmbed playlist metadata integration tests.
/// Verifies that importPlaylist / resync fetch real titles/channels/artwork via the oEmbed API,
/// and fall back to placeholder values when oEmbed fails.
@MainActor
@Suite("YouTubeImportMetadata", .serialized)
struct YouTubeImportMetadataTests {

    @Test("imports retain cover URLs without downloading unused duplicate hash files", arguments: [false, true])
    func noUnusedArtworkWarmWrite(video: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "muses-cover-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let artwork = ArtworkCache(directory: directory)
        let legacy = directory.appending(path: "legacy-owned-cover.jpg")
        try Data("unique-existing-cover".utf8).write(to: legacy)
        let requests = ArtworkWarmWriteRequests()
        YouTubeImportMetadataStub.reset()
        let stub = YouTubeImportMetadataStub()
        stub.respond(forHostContaining: "youtube.com") { request in
            requests.append((request.url?.host ?? "") + (request.url?.path ?? ""))
            if request.url?.path == "/oembed" {
                return StubResponse(statusCode: 200, body: Data("""
                {"title":"Title","author_name":"Artist","thumbnail_url":"https://i.ytimg.com/vi/abcdefghijk/cover.jpg"}
                """.utf8), headers: ["Content-Type": "application/json"])
            }
            return StubResponse(statusCode: 404, body: Data())
        }
        stub.respond(forHostContaining: "i.ytimg.com") { request in
            requests.append((request.url?.host ?? "") + (request.url?.path ?? ""))
            return StubResponse(statusCode: 200, body: Data(repeating: 0xAB, count: 64),
                headers: ["Content-Type": "image/jpeg"])
        }
        let session = URLSession(configuration: YouTubeImportMetadataStub.makeConfig())
        defer { session.invalidateAndCancel() }
        let container = try makeModelContainer(inMemory: true)
        let bridge = MockImportBridge()
        bridge.entries = [.init(id: "abcdefghijk", title: "Track")]
        let service = YouTubeImportService(bridge: bridge, modelContainer: container,
            artworkCache: artwork, session: session)
        let savedID: UUID
        if video { savedID = try await service.importVideo(url: "https://www.youtube.com/watch?v=abcdefghijk") }
        else { savedID = try await service.importPlaylist(url: "https://www.youtube.com/playlist?list=PLcover") }
        #expect(requests.snapshot().contains("www.youtube.com/oembed"))
        #expect(!requests.snapshot().contains { $0.hasPrefix("i.ytimg.com/") })
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == [legacy.lastPathComponent])
        #expect(try Data(contentsOf: legacy) == Data("unique-existing-cover".utf8))
        // Retain the read context through property access. A temporary context
        // may be released after fetch while its returned models still need it.
        let verificationContext = ModelContext(container)
        let savedArtwork: String? = try withExtendedLifetime(verificationContext) {
            if video {
                let row = try #require(try verificationContext.fetch(FetchDescriptor<Track>())
                    .first { $0.id == savedID })
                return row.artworkUrl
            }
            let row = try #require(try verificationContext.fetch(FetchDescriptor<YouTubeImport>())
                .first { $0.id == savedID })
            return row.artworkUrl
        }
        #expect(savedArtwork == "https://i.ytimg.com/vi/abcdefghijk/cover.jpg")
    }

    // MARK: - oEmbed success

    @Test("importPlaylist with successful oEmbed populates title, channel, and artwork")
    func oEmbedSuccessPopulatesMetadata() async throws {
        let container = try makeModelContainer(inMemory: true)
        let bridge = MockImportBridge()
        bridge.entries = [
            YTDlpBridge.YTDlpPlaylistEntry(
                id: "oembed00001", title: "Song A", uploader: "Some Channel", duration: 200),
        ]

        YouTubeImportMetadataStub.reset()
        let stub = YouTubeImportMetadataStub()
        // oEmbed request: host contains "youtube.com" and path contains "/oembed"
        stub.respond(forHostContaining: "youtube.com") { req in
            if req.url?.path.contains("/oembed") == true {
                let json = """
                {"title":"My Awesome Playlist","author_name":"Awesome Creator","thumbnail_url":"https://i.ytimg.com/vi/playlist/thumb.jpg"}
                """.data(using: .utf8)!
                return StubResponse(statusCode: 200, body: json,
                                    headers: ["Content-Type": "application/json"])
            }
            // Other requests (artwork downloads etc.) → 404; do not block
            return StubResponse(statusCode: 404, body: Data())
        }
        let session = URLSession(configuration: YouTubeImportMetadataStub.makeConfig())
        let artworkCache = ArtworkCache(
            directory: FileManager.default.temporaryDirectory
                .appending(path: "muses-oembed-\(UUID().uuidString)"))
        let service = YouTubeImportService(
            bridge: bridge, modelContainer: container,
            artworkCache: artworkCache, session: session)

        let importId = try await service.importPlaylist(
            url: "https://www.youtube.com/playlist?list=PLtestOembed")

        let ctx = ModelContext(container)
        let imps = try ctx.fetch(FetchDescriptor<YouTubeImport>())
        #expect(imps.count == 1)
        let imp = try #require(imps.first)
        #expect(imp.id == importId)
        #expect(imp.title == "My Awesome Playlist", "oEmbed title should be populated")
        #expect(imp.channel == "Awesome Creator", "oEmbed channel should be populated")
        #expect(imp.artworkUrl == "https://i.ytimg.com/vi/playlist/thumb.jpg",
                "oEmbed artwork URL should be populated")
    }

    // MARK: - oEmbed failure fallback

    @Test("importPlaylist with oEmbed 404 falls back to placeholder title and channel")
    func oEmbedFailureFallsBack() async throws {
        let container = try makeModelContainer(inMemory: true)
        let bridge = MockImportBridge()
        bridge.entries = [
            YTDlpBridge.YTDlpPlaylistEntry(
                id: "oembed00001", title: "Song A", uploader: "Fallback Channel", duration: 200),
        ]

        YouTubeImportMetadataStub.reset()
        let stub = YouTubeImportMetadataStub()
        // Every request returns 404 (oEmbed + artwork all fail)
        stub.respond(forHostContaining: "") { _ in
            StubResponse(statusCode: 404, body: Data())
        }
        let session = URLSession(configuration: YouTubeImportMetadataStub.makeConfig())
        let artworkCache = ArtworkCache(
            directory: FileManager.default.temporaryDirectory
                .appending(path: "muses-oembed-fallback-\(UUID().uuidString)"))
        let service = YouTubeImportService(
            bridge: bridge, modelContainer: container,
            artworkCache: artworkCache, session: session)

        _ = try await service.importPlaylist(
            url: "https://www.youtube.com/playlist?list=PLtestFallback")

        let ctx = ModelContext(container)
        let imp = try #require(try ctx.fetch(FetchDescriptor<YouTubeImport>()).first)
        // Fallback: placeholder title, channel taken from the first entry's uploader.
        #expect(imp.title == "YouTube Playlist", "Failed oEmbed should fall back to placeholder title")
        #expect(imp.channel == "Fallback Channel", "Failed oEmbed should fall back to first entry's uploader")
        // Fallback artwork: the first video's hqdefault.
        #expect(imp.artworkUrl == "https://i.ytimg.com/vi/oembed00001/hqdefault.jpg")
    }
}
private final class ArtworkWarmWriteRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var hosts: [String] = []
    func append(_ host: String) { lock.withLock { hosts.append(host) } }
    func snapshot() -> [String] { lock.withLock { hosts } }
}
final class YouTubeImportMetadataStub: StubURLProtocolBase, @unchecked Sendable {
    nonisolated(unsafe) private static var _rules: [StubRule] = []
    private static let _lock = NSLock()
    override class var rules: [StubRule] {
        get { _rules } set { _rules = newValue }
    }
    override class var lock: NSLock { _lock }
}
