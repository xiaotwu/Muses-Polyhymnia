import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Recording-aware lyrics queries", .serialized)
struct LyricsSearchPreparationTests {
    @Test("automatic lookup uses verified recording fields instead of video title and publisher",
          arguments: [false, true])
    func verifiedRecordingReachesActualHTTP(useLoad: Bool) async throws {
        let fixture = try LyricsPreparationFixture()
        defer { fixture.close() }
        let track = fixture.track()
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: track.title,
            uploader: "Publisher", track: "Recording Song", artist: "Performer"))
        let displayed = SongDisplayInformation(row: CollectionTrackRow(snapshot: track, canonicalIndex: 0))
        #expect(displayed.title == "Recording Song")
        #expect(displayed.artist == "Performer")
        let result = useLoad ? await fixture.lyrics.load(track: track) : await fixture.lyrics.fetch(track: track)
        #expect(result?.plainLyrics == "Synthetic recording lyrics")
        let request = try #require(LyricsPreparationProtocol.requests.first {
            $0.host == "lrclib.net" && $0.path == "/api/get"
        })
        let fields = URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(fields.first { $0.name == "track_name" }?.value == "Recording Song")
        #expect(fields.first { $0.name == "artist_name" }?.value == "Performer")
        #expect(track.title == "Video title (Official Video)")
        #expect(track.artist == "Publisher")
    }

    @Test("pipe-suffix recording versions cannot automatically accept a studio candidate",
          arguments: ["Live", "Cover", "Acoustic"])
    func pipeVersionDoesNotBecomeStudio(version: String) async throws {
        let fixture = try LyricsPreparationFixture()
        defer { fixture.close() }
        let track = fixture.track(title: "Performer - Recording Song | " + version)
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: track.title,
            uploader: "Publisher", track: "Recording Song", artist: "Performer"))
        let result = await fixture.lyrics.fetch(track: track)
        #expect(result == nil)
        try #require(LyricsPreparationProtocol.requests.contains { $0.host == "lrclib.net" })
        let title = fixture.lyrics.cachedSearchPreparation(for: track).title
        #expect(LyricsMatchPolicy.versions(title).contains(version.lowercased()))
    }

    @Test("custom and raw query misses do not poison the prepared recording's candidate cache")
    func priorMissUsesDifferentQueryIdentity() async throws {
        let fixture = try LyricsPreparationFixture()
        defer { fixture.close() }
        let track = fixture.track()
        let custom = LyricsSearchQuery(title: "751013170405", artist: "").applying(to: track)
        #expect(await fixture.lyrics.findCandidates(track: custom, refresh: true, source: "lrclib").isEmpty)
        #expect(await fixture.lyrics.fetch(track: track) == nil)
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: track.title,
            uploader: "Publisher", track: "Recording Song", artist: "Performer"))
        LyricsPreparationProtocol.requests = []
        #expect(await fixture.lyrics.fetch(track: track)?.plainLyrics == "Synthetic recording lyrics")
        #expect(LyricsPreparationProtocol.requests.contains { queryField("track_name", in: $0) == "Recording Song" })
        #expect(fixture.lyrics.fetchCached(track: track)?.plainLyrics == "Synthetic recording lyrics")
        #expect(fixture.lyrics.fetchCached(track: custom) == nil)
    }

    @Test("publisher and retained owner evidence leave the actual lyric artist query empty", arguments: [false, true])
    func publisherIsNotPerformer(owner: Bool) async throws {
        let fixture = try LyricsPreparationFixture()
        defer { fixture.close() }
        let track = fixture.track(artist: owner ? "Retained owner" : "Publisher")
        if owner { SongCreditCache.shared.recordOwner(track.artist, videoID: track.youTubeId) }
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: track.title,
            uploader: "Publisher", track: "Recording Song"))
        #expect(await fixture.lyrics.fetch(track: track) == nil)
        let requests = LyricsPreparationProtocol.requests.filter { $0.host == "lrclib.net" }
        #expect(!requests.isEmpty)
        #expect(requests.allSatisfy { (queryField("artist_name", in: $0) ?? "").isEmpty })
        let prepared = fixture.lyrics.cachedSearchPreparation(for: track)
        let candidates = await fixture.lyrics.findCandidates(track: prepared.query.applying(to: track),
            refresh: true, source: "lrclib")
        #expect(candidates.first?.artistName == "Performer")
        #expect(LyricsMatchPolicy.automatic(candidates, track: prepared.query.applying(to: track)) == nil)
    }

    @Test("defaults wait for real metadata, then reach the same candidate HTTP used by the sheet")
    func delayedDefaultsReachHTTP() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let preparation = LyricsSearchPreparation()
        let task = Task { await preparation.prepare(track: track, initialQuery: "", using: fixture.lyrics) }
        defer { task.cancel() }
        try await bridge.waitForRequest(track.youTubeId)
        #expect(preparation.isPreparing)
        #expect(!preparation.isReady)
        #expect(preparation.searchTrack(for: track) == nil)
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
        bridge.finish(track.youTubeId)
        await task.value
        #expect(!preparation.isPreparing)
        #expect(preparation.titleQuery == "Recording Song")
        #expect(preparation.artistQuery == "Performer")
        let lookup = try #require(preparation.searchTrack(for: track))
        #expect(lookup.id == track.id && lookup.youTubeId == track.youTubeId)
        let candidates = await fixture.lyrics.findCandidates(track: lookup, refresh: true, source: "lrclib")
        #expect(LyricsMatchPolicy.automatic(candidates, track: lookup)?.id == 901)
        #expect(queryField("artist_name", in: try #require(LyricsPreparationProtocol.lyricRequests.first)) == "Performer")
    }

    @Test("late metadata preserves drafts, explicit intent text and submitted query/results", arguments: LyricsDraftAction.allCases)
    func lateMetadataDoesNotSubmitOrOverwrite(action: LyricsDraftAction) async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let preparation = LyricsSearchPreparation()
        let initial = action == .explicitIntent ? "751013170405" : ""
        let task = Task { await preparation.prepare(track: track, initialQuery: initial, using: fixture.lyrics) }
        defer { task.cancel() }
        try await bridge.waitForRequest(track.youTubeId)
        if action != .explicitIntent {
            preparation.titleQuery = "Recording Song"
            preparation.artistQuery = "Performer"
        }
        if action == .submitted || action == .sourceChange { #expect(preparation.submit()) }
        if action == .restore { preparation.restoreDefaults(for: track, using: fixture.lyrics) }
        let revision = preparation.searchRevision
        let title = preparation.titleQuery
        let artist = preparation.artistQuery
        var candidateID: Int?
        if let query = preparation.searchTrack(for: track) {
            let candidates = await fixture.lyrics.findCandidates(track: query, refresh: true, source: "lrclib")
            candidateID = LyricsMatchPolicy.automatic(candidates, track: query)?.id
        }
        let requestCount = LyricsPreparationProtocol.lyricRequests.count
        bridge.finish(track.youTubeId, song: "Different metadata song", artist: "Different metadata artist")
        await task.value
        #expect(preparation.titleQuery == title)
        #expect(preparation.artistQuery == artist)
        #expect(preparation.searchRevision == revision)
        #expect(LyricsPreparationProtocol.lyricRequests.count == requestCount)
        if action == .unsubmittedDraft {
            #expect(preparation.hasUnsubmittedEdits)
            #expect(!preparation.isReady)
            #expect(preparation.searchTrack(for: track) == nil)
            #expect(requestCount == 0)
        } else {
            #expect(preparation.isReady)
            if action == .submitted || action == .sourceChange { #expect(candidateID == 901) }
        }
    }

    @Test("a cancelled preparation cannot publish late recording fields")
    func cancelledPreparation() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let preparation = LyricsSearchPreparation()
        let task = Task { await preparation.prepare(track: track, initialQuery: "", using: fixture.lyrics) }
        try await bridge.waitForRequest(track.youTubeId)
        task.cancel()
        preparation.invalidate()
        bridge.finish(track.youTubeId)
        await task.value
        #expect(preparation.recordingID == nil)
        #expect(!preparation.isReady)
        #expect(preparation.searchTrack(for: track) == nil)
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
    }

    @Test("an older same-video preparation cannot change the new recording UUID's edited credits")
    func recordingChangeRejectsLateDefaults() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let first = fixture.track()
        let second = fixture.track(title: "My corrected title", artist: "My corrected performer")
        let preparation = LyricsSearchPreparation()
        let oldTask = Task { await preparation.prepare(track: first, initialQuery: "", using: fixture.lyrics) }
        defer { oldTask.cancel() }
        try await bridge.waitForRequest(first.youTubeId)
        let newTask = Task { await preparation.prepare(track: second, initialQuery: "", using: fixture.lyrics) }
        defer { newTask.cancel() }
        for _ in 0..<20 { await Task.yield() }
        try #require(preparation.recordingID == second.id)
        bridge.finish(first.youTubeId)
        await oldTask.value
        await newTask.value
        #expect(bridge.calls == 1)
        #expect(preparation.recordingID == second.id)
        #expect(preparation.titleQuery == "My corrected title")
        #expect(preparation.artistQuery == "My corrected performer")
        #expect(preparation.searchTrack(for: first) == nil)
        #expect(preparation.searchTrack(for: second)?.id == second.id)
    }

    @Test("manual choice wins while metadata is suspended and keeps the original document association")
    func manualChoiceWinsBeforeMetadata() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let task = Task { await fixture.lyrics.fetch(track: track) }
        defer { task.cancel() }
        try await bridge.waitForRequest(track.youTubeId)
        fixture.lyrics.choose(manualCandidate, for: track)
        bridge.finish(track.youTubeId)
        #expect(await task.value?.plainLyrics == "Manual choice")
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
        #expect(fixture.lyrics.fetchCached(track: track)?.plainLyrics == "Manual choice")
        #expect(await fixture.cache.read(key: LyricsDocumentIdentity.key(for: track))?.plainLyrics == "Manual choice")
        let preparedTrack = fixture.lyrics.cachedSearchPreparation(for: track).query.applying(to: track)
        #expect(LyricsDocumentIdentity.key(for: preparedTrack) != LyricsDocumentIdentity.key(for: track))
        #expect(await fixture.cache.read(key: LyricsDocumentIdentity.key(for: preparedTrack)) == nil)
    }

    @Test("saved or manually selected synchronized lyrics return without asking for metadata", arguments: [false, true])
    func synchronizedCacheDoesNotWait(manual: Bool) async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        if manual { fixture.lyrics.choose(manualCandidate, for: track) }
        else {
            await fixture.cache.write(LyricsResult(plainLyrics: "Manual choice", syncedLyrics: "[00:01]Manual choice", source: .lrclib),
                key: LyricsDocumentIdentity.key(for: track))
        }
        var completed = false
        let task = Task { let value = await fixture.lyrics.load(track: track); completed = true; return value }
        defer { task.cancel() }
        for _ in 0..<100 where !completed { try await Task.sleep(for: .milliseconds(2)) }
        #expect(completed)
        #expect(bridge.calls == 0)
        bridge.finishAll()
        #expect(await task.value?.syncedLyrics == "[00:01]Manual choice")
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
    }

    @Test("cancelled automatic lookup does not issue lyrics HTTP after shared metadata finishes")
    func automaticCancellationBeforeHTTP() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let task = Task { await fixture.lyrics.fetch(track: track) }
        try await bridge.waitForRequest(track.youTubeId)
        task.cancel()
        bridge.finish(track.youTubeId)
        #expect(await task.value == nil)
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
        #expect(fixture.lyrics.fetchCached(track: track) == nil)
    }

    @Test("real numeric titles survive while explicit production placeholders use verified names",
          arguments: ["1999", "505", "YouTube Video", "Unknown Title", "identity"])
    func numericAndPlaceholderQueries(title: String) async throws {
        let fixture = try LyricsPreparationFixture()
        defer { fixture.close() }
        let track = fixture.track(title: title == "identity" ? fixture.videoID : title)
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: "Video title (Official Video)",
            uploader: "Publisher", track: "Recording Song", artist: "Performer"))
        _ = await fixture.lyrics.fetch(track: track)
        let expected = ["1999", "505"].contains(title) ? title : "Recording Song"
        #expect(queryField("track_name", in: try #require(LyricsPreparationProtocol.lyricRequests.first)) == expected)
        #expect(track.title == (title == "identity" ? fixture.videoID : title))
    }

    @Test("plain saved lyrics upgrade with available verified fields and never await fresh metadata")
    func plainCacheUsesPreparedTimingFields() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: track.title,
            uploader: "Publisher", track: "Recording Song", artist: "Performer"))
        await fixture.cache.write(LyricsResult(plainLyrics: "Synthetic recording lyrics", syncedLyrics: nil, source: .lrclib),
            key: LyricsDocumentIdentity.key(for: track))
        #expect(await fixture.lyrics.load(track: track)?.syncedLyrics == "[00:01]Synthetic recording lyrics")
        #expect(bridge.calls == 0)
        #expect(queryField("artist_name", in: try #require(LyricsPreparationProtocol.lyricRequests.first)) == "Performer")
        #expect(await fixture.cache.read(key: LyricsDocumentIdentity.key(for: track))?.syncedLyrics != nil)
    }

    @Test("plain cache stays immediate with unknown performer and can upgrade after verified fields arrive")
    func plainCacheDoesNotWaitForUnknownPerformer() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: track.title, uploader: "Publisher"))
        await fixture.cache.write(LyricsResult(plainLyrics: "Synthetic recording lyrics", syncedLyrics: nil, source: .lrclib),
            key: LyricsDocumentIdentity.key(for: track))
        let plain = await fixture.lyrics.load(track: track)
        #expect(plain?.plainLyrics == "Synthetic recording lyrics")
        #expect(plain?.syncedLyrics == nil)
        #expect(bridge.calls == 0)
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
        SongCreditCache.shared.store(.init(id: track.youTubeId, title: track.title,
            uploader: "Publisher", track: "Recording Song", artist: "Performer"))
        #expect(await fixture.lyrics.load(track: track)?.syncedLyrics == "[00:01]Synthetic recording lyrics")
        #expect(bridge.calls == 0)
    }

    @Test("unavailable detailed metadata uses the verified video title and an empty performer field")
    func metadataUnavailableHasHonestDefaults() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let preparation = LyricsSearchPreparation()
        let task = Task { await preparation.prepare(track: track, initialQuery: "", using: fixture.lyrics) }
        defer { task.cancel() }
        try await bridge.waitForRequest(track.youTubeId)
        bridge.finishAll()
        await task.value
        #expect(!preparation.isPreparing && preparation.isReady)
        #expect(preparation.titleQuery == "Video title")
        #expect(preparation.artistQuery.isEmpty)
        #expect(preparation.searchTrack(for: track)?.id == track.id)
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
    }

    @Test("shared importer evidence repairs the query without changing a retained recording's user fields")
    func retainedOwnerQueryPreservesRecordingTruth() async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let container = try #require(fixture.modelContainer)
        let context = ModelContext(container)
        let stored = Track(title: "Video title (Official Video)", artist: "Retained owner",
            durationMs: 180_000, youTubeId: fixture.videoID, playCount: 7, liked: true)
        stored.genre = "User genre"
        let imported = YouTubeImport(playlistId: "PL_retained", url: "old", title: "Retained collection", channel: "Retained owner")
        imported.deletedAt = Date()
        let item = YouTubeImportItem(youTubeId: fixture.videoID, title: stored.title, artist: "Retained owner")
        item.import_ = imported
        item.track = stored
        imported.items = [item]
        context.insert(stored)
        context.insert(imported)
        try context.save()
        let recording = TrackSnapshot(from: stored)
        let task = Task { await fixture.lyrics.load(track: recording) }
        defer { task.cancel() }
        try await bridge.waitForRequest(recording.youTubeId)
        bridge.finish(recording.youTubeId)
        #expect(await task.value?.plainLyrics == "Synthetic recording lyrics")
        let saved = try #require(ModelContext(container).fetch(FetchDescriptor<Track>()).first)
        #expect(saved.id == recording.id && saved.title == recording.title && saved.artist == recording.artist)
        #expect(saved.liked && saved.playCount == 7 && saved.genre == "User genre")
        #expect(saved.lyrics == "[00:01]Synthetic recording lyrics")
        #expect(await fixture.cache.read(key: LyricsDocumentIdentity.key(for: recording))?.source == .lrclib)
        let query = fixture.lyrics.cachedSearchPreparation(for: recording).query.applying(to: recording)
        #expect(await fixture.cache.read(key: LyricsDocumentIdentity.key(for: query)) == nil)
    }

    @Test("same-value field writebacks preserve default preparation and submitted search readiness",
          arguments: LyricsWritebackPhase.allCases, LyricsWritebackField.allCases)
    func sameValueWritebacksAreNotEdits(phase: LyricsWritebackPhase, field: LyricsWritebackField) async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let preparation = LyricsSearchPreparation()
        let initial = phase == .explicitPending ? "751013170405" : ""
        let task = Task { await preparation.prepare(track: track, initialQuery: initial, using: fixture.lyrics) }
        defer { task.cancel() }
        try await bridge.waitForRequest(track.youTubeId)
        if phase == .readyDefault || phase == .submittedDefault {
            bridge.finish(track.youTubeId)
            await task.value
        }
        if phase == .submittedDefault { #expect(preparation.submit()) }
        let title = preparation.titleQuery
        let artist = preparation.artistQuery
        let wasReady = preparation.isReady
        let revision = preparation.searchRevision
        if field != .artist { preparation.titleQuery = title }
        if field != .title { preparation.artistQuery = artist }
        #expect(!preparation.hasUnsubmittedEdits)
        #expect(preparation.isReady == wasReady)
        #expect(preparation.searchRevision == revision)
        if phase == .pendingDefault || phase == .explicitPending {
            bridge.finish(track.youTubeId)
            await task.value
        }
        #expect(preparation.isReady)
        #expect(!preparation.hasUnsubmittedEdits)
        #expect(preparation.titleQuery == (initial.isEmpty ? "Recording Song" : initial))
        #expect(preparation.artistQuery == (initial.isEmpty ? "Performer" : ""))
        let query = try #require(preparation.searchTrack(for: track))
        let found = await fixture.lyrics.findCandidates(track: query, refresh: true, source: "lrclib")
        if initial.isEmpty {
            #expect(LyricsMatchPolicy.automatic(found, track: query)?.id == 901)
            #expect(queryField("artist_name", in: try #require(LyricsPreparationProtocol.lyricRequests.first)) == "Performer")
        } else {
            #expect(queryField("track_name", in: try #require(LyricsPreparationProtocol.lyricRequests.first)) == initial)
        }
    }

    @Test("editing a field and restoring its original text still protects an unsubmitted draft",
          arguments: [false, true])
    func realEditThenRevertStaysProtected(artistField: Bool) async throws {
        let bridge = LyricsPreparationBridge()
        let fixture = try LyricsPreparationFixture(bridge: bridge)
        defer { fixture.close() }
        let track = fixture.track()
        let preparation = LyricsSearchPreparation()
        let task = Task { await preparation.prepare(track: track, initialQuery: "", using: fixture.lyrics) }
        defer { task.cancel() }
        try await bridge.waitForRequest(track.youTubeId)
        let title = preparation.titleQuery
        let artist = preparation.artistQuery
        if artistField {
            preparation.artistQuery = "A real artist edit"
            preparation.artistQuery = artist
        } else {
            preparation.titleQuery = "A real title edit"
            preparation.titleQuery = title
        }
        bridge.finish(track.youTubeId)
        await task.value
        #expect(preparation.titleQuery == title && preparation.artistQuery == artist)
        #expect(preparation.hasUnsubmittedEdits)
        #expect(!preparation.isReady)
        #expect(preparation.searchTrack(for: track) == nil)
        #expect(LyricsPreparationProtocol.lyricRequests.isEmpty)
        #expect(preparation.submit())
        #expect(preparation.isReady && !preparation.hasUnsubmittedEdits)
    }

    private var manualCandidate: LyricsCandidate {
        LyricsCandidate(id: 999, trackName: "Recording Song", artistName: "Performer", albumName: nil,
            duration: 180, instrumental: false, plainLyrics: "Manual choice", syncedLyrics: "[00:01]Manual choice")
    }
}

enum LyricsDraftAction: String, CaseIterable, Sendable {
    case unsubmittedDraft, submitted, explicitIntent, sourceChange, restore
}

enum LyricsWritebackPhase: String, CaseIterable, Sendable {
    case pendingDefault, readyDefault, submittedDefault, explicitPending
}

enum LyricsWritebackField: String, CaseIterable, Sendable {
    case title, artist, both
}

@MainActor
private final class LyricsPreparationFixture {
    let directory = isolatedHomeTestDirectory("muses-lyrics-preparation-")
    let suite = "muses-lyrics-preparation-" + UUID().uuidString
    let videoID = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(11))
    let defaults: UserDefaults
    let session: URLSession
    let cache: LyricsDocumentCache
    let lyrics: LyricsService
    let bridge: LyricsPreparationBridge?
    let modelContainer: ModelContainer?

    init(bridge: LyricsPreparationBridge? = nil) throws {
        self.bridge = bridge
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set("lrclib", forKey: PrefKey.lyricsSource)
        defaults.set(false, forKey: PrefKey.lyricsIntelligence)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LyricsPreparationProtocol.self]
        session = URLSession(configuration: configuration)
        cache = LyricsDocumentCache(directory: directory)
        let importer: YouTubeImportService?
        if let bridge {
            let container = try makeModelContainer(inMemory: true)
            modelContainer = container
            importer = YouTubeImportService(bridge: bridge, modelContainer: container,
                artworkCache: ArtworkCache(directory: directory.appendingPathComponent("artwork")), session: session)
        } else { importer = nil; modelContainer = nil }
        lyrics = LyricsService(session: session, modelContainer: modelContainer,
            documentCache: cache, offsetDefaults: defaults, importService: importer)
        LyricsPreparationProtocol.requests = []
    }

    func track(title: String = "Video title (Official Video)", artist: String = "Publisher") -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: title, artist: artist, albumTitle: nil,
            durationSeconds: 180, youTubeId: videoID, artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
    }

    func close() {
        bridge?.finishAll()
        session.invalidateAndCancel()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class LyricsPreparationProtocol: URLProtocol, @unchecked Sendable {
    private static let recorder = LyricsRequestRecorder()
    static var requests: [URL] {
        get { recorder.read() }
        set { recorder.replace(newValue) }
    }
    static var lyricRequests: [URL] { requests.filter { $0.host == "lrclib.net" } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        Self.recorder.append(url)
            let fields = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let title = fields.first { $0.name == "track_name" }?.value
            let artist = fields.first { $0.name == "artist_name" }?.value
            let candidate = #"{"id":901,"trackName":"Recording Song","artistName":"Performer","duration":180,"plainLyrics":"Synthetic recording lyrics","syncedLyrics":"[00:01]Synthetic recording lyrics"}"#
            let matches = title == "Recording Song" && (artist == "Performer" || (url.path == "/api/search" && artist == nil))
            let body: String
            let status: Int
            if url.host == "lrclib.net" {
                body = url.path == "/api/get" ? (matches ? candidate : "{}") : (matches ? "[" + candidate + "]" : "[]")
                status = 200
            } else if url.host == "www.youtube.com", url.path == "/oembed" {
                body = #"{"title":"Video title (Official Video)","author_name":"Publisher"}"#
                status = 200
            } else {
                body = "{}"
                status = 404
            }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status,
                httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
private final class LyricsPreparationBridge: YTDlpBridgeProtocol {
    private var pending: [String: CheckedContinuation<YTDlpBridge.YTDlpPlaylistEntry?, Never>] = [:]
    private(set) var calls = 0
    func fetchSongMetadata(videoId: String, timeout: TimeInterval) async throws -> YTDlpBridge.YTDlpPlaylistEntry? {
        calls += 1
        return await withCheckedContinuation { pending[videoId] = $0 }
    }
    func waitForRequest(_ id: String) async throws {
        for _ in 0..<100 where pending[id] == nil { try await Task.sleep(for: .milliseconds(5)) }
        try #require(pending[id] != nil)
    }
    func finish(_ id: String, song: String = "Recording Song", artist: String = "Performer") {
        pending.removeValue(forKey: id)?.resume(returning: .init(id: id,
            title: "Video title (Official Video)", uploader: "Publisher", track: song, artist: artist))
    }
    func finishAll() {
        let values = Array(pending.values)
        pending.removeAll()
        values.forEach { $0.resume(returning: nil) }
    }
    func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL { throw URLError(.unsupportedURL) }
    func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] { throw URLError(.unsupportedURL) }
    func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] { throw URLError(.unsupportedURL) }
    func version() async -> String? { "test" }
}

private func queryField(_ name: String, in url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
}

private final class LyricsRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    func read() -> [URL] { lock.lock(); defer { lock.unlock() }; return urls }
    func replace(_ value: [URL]) { lock.lock(); defer { lock.unlock() }; urls = value }
    func append(_ value: URL) { lock.lock(); defer { lock.unlock() }; urls.append(value) }
}
