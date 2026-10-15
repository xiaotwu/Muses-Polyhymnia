import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Manual lyrics search modes", .serialized)
struct LyricsSearchModeTests {
    @Test("Exact LRCLIB lookup sends one complete structured query")
    func exactRequestPreservesCompleteFields() async throws {
        let title = "Ａｒｔｉｓｔ – Café 「夜」 (Session 2) [Official Video]"
        let artist = "Studio Artist - Topic"
        let fixture = try LyricsModeFixture(candidates: [.init(id: 1, title: title, artist: artist)])
        defer { fixture.close() }
        let recording = modeTrack(title: "  " + title + "\n", artist: "\t" + artist + "  ")

        let found = await fixture.service.findCandidates(track: recording, source: "lrclib", mode: .exact)

        #expect(found.map(\.id) == [1])
        let requests = LyricsModeProtocol.requests
        #expect(requests.count == 1)
        let url = try #require(requests.first)
        #expect(url.host == "lrclib.net")
        #expect(url.path == "/api/search")
        #expect(modeQuery("track_name", in: url) == title)
        #expect(modeQuery("artist_name", in: url) == artist)
        #expect(modeQuery("q", in: url) == nil)
    }

    @Test("Exact results require the full title and artist, including unfamiliar version text")
    func exactFiltersProviderMetadata() async throws {
        let fixture = try LyricsModeFixture(candidates: [
            .init(id: 1, title: "Night River (Session 2)", artist: "Artist One"),
            .init(id: 2, title: "Night River", artist: "Artist One"),
            .init(id: 3, title: "Night River (Session 3)", artist: "Artist One"),
            .init(id: 4, title: "River Night (Session 2)", artist: "Artist One"),
            .init(id: 5, title: "Night River Session 2", artist: "Artist One"),
            .init(id: 6, title: "Night River (Session 2) Extended", artist: "Artist One"),
            .init(id: 7, title: "River", artist: "Artist One"),
            .init(id: 8, title: "Night River (Session 2)", artist: "Artist One Ensemble"),
            .init(id: 9, title: "Night River (Session 2)", artist: "One Artist"),
            .init(id: 10, title: "Night River (Session 2)", artist: "Artist One - Topic"),
            .init(id: 11, title: "Night River (Session 2)", artist: ""),
            .init(id: 12, title: "Night River (Session 2)", artist: "Artist One", lyrics: nil)
        ])
        defer { fixture.close() }
        let recording = modeTrack(title: "Night River (Session 2)", artist: "Artist One")

        let found = await fixture.service.findCandidates(track: recording, source: "lrclib", mode: .exact)

        #expect(found.map(\.id) == [1])
        #expect(LyricsModeProtocol.requests.count == 1)
    }

    @Test("Exact matching accepts canonical Unicode, case, width and whitespace without deleting accents")
    func exactAcceptsEquivalentSpelling() async throws {
        let fixture = try LyricsModeFixture(candidates: [
            .init(id: 1, title: "cafe\u{301}\u{00a0}night (session 2)", artist: "artist\u{00a0}one"),
            .init(id: 2, title: "cafe night (session 2)", artist: "artist one"),
            .init(id: 3, title: "café night (session 2)", artist: "artist-one")
        ])
        defer { fixture.close() }
        let recording = modeTrack(title: "  ＣＡＦÉ\t Night  (Session 2)  ", artist: " ＡＲＴＩＳＴ\nOne ")

        let found = await fixture.service.findCandidates(track: recording, source: "lrclib", mode: .exact)

        #expect(found.map(\.id) == [1])
    }

    @Test("An empty exact-search artist leaves artist identity unconstrained")
    func exactWithBlankArtist() async throws {
        let fixture = try LyricsModeFixture(candidates: [
            .init(id: 1, title: "Night River", artist: "Artist One"),
            .init(id: 2, title: "Night River", artist: "Another Artist"),
            .init(id: 3, title: "Night River Extended", artist: "Another Artist")
        ])
        defer { fixture.close() }

        let found = await fixture.service.findCandidates(
            track: modeTrack(title: "Night River", artist: " \n\t"), source: "lrclib", mode: .exact)

        #expect(Set(found.map(\.id)) == [1, 2])
        let requests = LyricsModeProtocol.requests
        #expect(requests.count == 1)
        let url = try #require(requests.first)
        #expect(modeQuery("track_name", in: url) == "Night River")
        #expect(modeQuery("artist_name", in: url) == nil)
        #expect(modeQuery("q", in: url) == nil)
    }

    @Test("Default search keeps broad keyword discovery and conservative automatic selection")
    func fuzzyRemainsTheDefault() async throws {
        let fixture = try LyricsModeFixture(candidates: [
            .init(id: 41, title: "Night River", artist: "Different Performer")
        ], keywordOnly: true)
        defer { fixture.close() }
        let recording = modeTrack(title: "Night River (Official Video)", artist: "Publisher - Topic")

        let found = await fixture.service.findCandidates(track: recording, source: "lrclib")

        #expect(found.map(\.id) == [41])
        #expect(LyricsMatchPolicy.automatic(found, track: recording) == nil)
        let requests = LyricsModeProtocol.requests
        #expect(requests.contains { modeQuery("q", in: $0) != nil })
        #expect(requests.contains { modeQuery("track_name", in: $0) != nil && modeQuery("artist_name", in: $0) == nil })
        #expect(requests.contains { modeQuery("track_name", in: $0) != nil && modeQuery("artist_name", in: $0) != nil })
    }

    @Test("Exact lookup neither reads nor overwrites the same service's populated fuzzy cache")
    func exactDoesNotReuseOrReplaceFuzzyCache() async throws {
        let fixture = try LyricsModeFixture(candidates: modeCacheCandidates)
        defer { fixture.close() }
        let recording = modeTrack(title: "Night River", artist: "Artist One")
        let first = await fixture.service.findCandidates(track: recording, source: "lrclib")
        #expect(Set(first.map(\.id)) == [1, 2])
        let beforeExact = LyricsModeProtocol.requests.count

        let exact = await fixture.service.findCandidates(track: recording, source: "lrclib", mode: .exact)

        #expect(exact.map(\.id) == [1])
        #expect(LyricsModeProtocol.requests.count == beforeExact + 1)
        let beforeCached = LyricsModeProtocol.requests.count
        let again = await fixture.service.findCandidates(track: recording, source: "lrclib")
        #expect(Set(again.map(\.id)) == [1, 2])
        #expect(LyricsModeProtocol.requests.count == beforeCached)
    }

    @Test("An exact-first lookup cannot seed the fuzzy candidate cache")
    func fuzzyAfterExactStillDiscoversBroadCandidates() async throws {
        let fixture = try LyricsModeFixture(candidates: modeCacheCandidates)
        defer { fixture.close() }
        let recording = modeTrack(title: "Night River", artist: "Artist One")

        let exact = await fixture.service.findCandidates(track: recording, source: "lrclib", mode: .exact)
        #expect(exact.map(\.id) == [1])
        #expect(LyricsModeProtocol.requests.count == 1)
        let fuzzy = await fixture.service.findCandidates(track: recording, source: "lrclib")

        #expect(Set(fuzzy.map(\.id)) == [1, 2])
        #expect(LyricsModeProtocol.requests.count > 1)
        #expect(LyricsModeProtocol.requests.contains { modeQuery("q", in: $0) != nil })
    }

    @Test("Explicit exact OVH search is unsupported without issuing any HTTP request")
    func exactOVHDoesNotRequest() async throws {
        let fixture = try LyricsModeFixture(candidates: [])
        defer { fixture.close() }

        let found = await fixture.service.findCandidates(
            track: modeTrack(), source: "lyricsOVH", mode: .exact)

        #expect(found.isEmpty)
        #expect(LyricsModeProtocol.requests.isEmpty)
    }

    @Test("Automatic exact search skips OVH and does not broaden its LRCLIB query")
    func automaticExactSkipsUnsupportedSource() async throws {
        let fixture = try LyricsModeFixture(candidates: [])
        defer { fixture.close() }

        let found = await fixture.service.findCandidates(track: modeTrack(), source: "auto", mode: .exact)

        #expect(found.isEmpty)
        let requests = LyricsModeProtocol.requests
        #expect(!requests.contains { $0.host == "api.lyrics.ovh" })
        #expect(requests.filter { $0.host == "lrclib.net" }.count == 1)
        #expect(requests.contains { $0.path.hasSuffix("track.search") })
        #expect(!requests.contains { modeQuery("q", in: $0) != nil })
    }

    @Test("Exact Musixmatch checks returned metadata before downloading lyrics")
    func exactMusixmatchRejectsReorderedProviderTitle() async throws {
        let fixture = try LyricsModeFixture(musixmatch: [
            .init(id: 71, title: "River Night", artist: "Artist One")
        ])
        defer { fixture.close() }
        let recording = modeTrack(title: "Night River", artist: "Artist One")

        let exact = await fixture.service.findCandidates(track: recording, source: "musixmatch", mode: .exact)

        #expect(exact.isEmpty)
        #expect(LyricsModeProtocol.requests.count == 1)
        #expect(LyricsModeProtocol.requests.allSatisfy { $0.path.hasSuffix("track.search") })
        let fuzzy = await fixture.service.findCandidates(track: recording, source: "musixmatch")
        #expect(fuzzy.count == 1)
        #expect(fuzzy.first?.source == .musixmatch)
        #expect(LyricsModeProtocol.requests.contains { $0.path.hasSuffix("track.subtitle.get") })
    }

    @Test("Exact Musixmatch accepts equivalent returned metadata and retains source provenance")
    func exactMusixmatchAcceptsEquivalentMetadata() async throws {
        let fixture = try LyricsModeFixture(musixmatch: [
            .init(id: 72, title: "ＮＩＧＨＴ  river", artist: "artist\tONE")
        ])
        defer { fixture.close() }

        let found = await fixture.service.findCandidates(
            track: modeTrack(), source: "musixmatch", mode: .exact)

        #expect(found.count == 1)
        #expect(found.first?.source == .musixmatch)
        #expect(found.first?.syncedLyrics == "[00:01]Synthetic mode fixture lyrics")
        #expect(LyricsModeProtocol.requests.count == 2)
        #expect(LyricsModeProtocol.requests.contains { modeQuery("track_id", in: $0) == "72" })
    }

    @Test("Exact Musixmatch metadata does not bypass the existing duration safety check")
    func exactMusixmatchRetainsAutomaticSafety() async throws {
        let fixture = try LyricsModeFixture(musixmatch: [
            .init(id: 73, title: "Night River", artist: "Artist One", duration: 600)
        ])
        defer { fixture.close() }

        let found = await fixture.service.findCandidates(
            track: modeTrack(), source: "musixmatch", mode: .exact)

        #expect(found.isEmpty)
        #expect(LyricsModeProtocol.requests.count == 1)
        #expect(LyricsModeProtocol.requests.allSatisfy { $0.path.hasSuffix("track.search") })
    }
}

// All recordings and provider payloads below are synthetic fixtures. Every URL
// is intercepted, including unexpected hosts, so these tests never query providers.
private func modeTrack(title: String = "Night River", artist: String = "Artist One") -> TrackSnapshot {
    .init(id: UUID(), title: title, artist: artist, albumTitle: nil, durationSeconds: 180,
          youTubeId: "modetest001", artworkUrl: nil, sampleRate: nil, bitDepth: nil,
          codec: nil, isLossless: false)
}

private let modeCacheCandidates: [SyntheticModeCandidate] = [
    .init(id: 1, title: "Night River", artist: "Artist One"),
    .init(id: 2, title: "Night River Extended", artist: "Another Artist")
]

private struct SyntheticModeCandidate: Encodable, Sendable {
    let id: Int
    let trackName: String
    let artistName: String
    let duration: Double
    let plainLyrics: String?
    let instrumental = false

    init(id: Int, title: String, artist: String, duration: Double = 180,
         lyrics: String? = "Synthetic mode fixture lyrics") {
        self.id = id
        trackName = title
        artistName = artist
        self.duration = duration
        plainLyrics = lyrics
    }
}

@MainActor
private final class LyricsModeFixture {
    let service: LyricsService
    private let session: URLSession
    private let preferences: UserDefaults
    private let suite: String
    private let directory: URL

    init(candidates: [SyntheticModeCandidate] = [], keywordOnly: Bool = false,
         musixmatch: [SyntheticModeCandidate] = []) throws {
        let suite = "MusesTests.lyricsModes." + UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lyrics-modes-" + UUID().uuidString)
        let preferences = try #require(UserDefaults(suiteName: suite))
        self.suite = suite
        self.directory = directory
        self.preferences = preferences
        preferences.set(false, forKey: PrefKey.lyricsIntelligence)
        let search = ["message": ["body": ["track_list": musixmatch.map { candidate in
            ["track": ["track_id": candidate.id, "track_name": candidate.trackName,
                       "artist_name": candidate.artistName, "track_length": candidate.duration] as [String: Any]]
        }]]]
        LyricsModeProtocol.state.configure(lrclib: try JSONEncoder().encode(candidates),
            keywordOnly: keywordOnly, musixmatch: try JSONSerialization.data(withJSONObject: search))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LyricsModeProtocol.self]
        let session = URLSession(configuration: configuration)
        self.session = session
        service = LyricsService(session: session, documentCache: LyricsDocumentCache(directory: directory),
                                offsetDefaults: preferences)
    }

    func close() {
        session.invalidateAndCancel()
        preferences.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class LyricsModeProtocol: URLProtocol, @unchecked Sendable {
    static let state = LyricsModeHTTPState()
    static var requests: [URL] { state.requests() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let reply = Self.state.reply(to: url)
        let response = HTTPURLResponse(url: url, statusCode: reply.status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class LyricsModeHTTPState: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var lrclib = Data("[]".utf8)
    private var keywordOnly = false
    private var musixmatch = Data("{}".utf8)

    func configure(lrclib: Data, keywordOnly: Bool, musixmatch: Data) {
        lock.lock()
        defer { lock.unlock() }
        urls = []
        self.lrclib = lrclib
        self.keywordOnly = keywordOnly
        self.musixmatch = musixmatch
    }

    func requests() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func reply(to url: URL) -> (status: Int, body: Data) {
        lock.lock()
        defer { lock.unlock() }
        urls.append(url)
        if url.host == "lrclib.net", url.path == "/api/search" {
            return (200, keywordOnly && modeQuery("q", in: url) == nil ? Data("[]".utf8) : lrclib)
        }
        if url.host == "api.musixmatch.com" {
            if url.path.hasSuffix("track.search") { return (200, musixmatch) }
            if url.path.hasSuffix("track.subtitle.get") {
                return (200, Data(#"{"message":{"body":{"subtitle":{"subtitle_body":"[00:01]Synthetic mode fixture lyrics"}}}}"#.utf8))
            }
        }
        return (404, Data("{}".utf8))
    }
}

private func modeQuery(_ name: String, in url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
}
