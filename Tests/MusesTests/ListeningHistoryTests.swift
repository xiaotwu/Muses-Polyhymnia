import Testing
import Foundation
import SwiftData
@testable import Muses

/// Smart Listening History acceptance:
/// - `ListeningEvent` @Model persists and its outcome/source computed properties are correct;
/// - `HistoryService` subscribes to the event bus, recording and classifying Started/Completed/Skipped/Stopped;
/// - the feature flag gates cleanly: when off, nothing is recorded but event boundaries are preserved;
/// - `PlaybackService` end to end (stub engine, avoiding the headless AVAudioPlayerNode
///   "player did not see an IO cycle" ObjC exception): skip → skipped, natural completion → completed;
/// - `HistoryQuery` filtering and `ListeningRecap` aggregation are correct.
@Suite("Listening History")
@MainActor
struct ListeningHistoryTests {

    private func makeContainer() throws -> ModelContainer {
        try makeModelContainer(inMemory: true)
    }

    private func snap(_ title: String, id: UUID = UUID(),
                      durationSec: Double = 200) -> TrackSnapshot {
        TrackSnapshot(id: id, title: title, artist: "Artist \(title)",
                      albumTitle: "Album \(title)", durationSeconds: durationSec,
                      youTubeId: "yt\(title)",
                      artworkUrl: nil,
                      sampleRate: 44100, bitDepth: 16, codec: "pcm", isLossless: false)
    }

    // MARK: - Model

    @Test("ListeningEvent persistence round trip and outcome/source computed properties")
    func eventRoundTrip() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let ev = ListeningEvent(trackId: UUID(), trackTitle: "t", artist: "a",
                                albumTitle: "al", startedAt: Date(timeIntervalSince1970: 1000),
                                endedAt: Date(timeIntervalSince1970: 1100), listenedMs: 95000,
                                completionRatio: 0.95, outcome: .completed)
        ctx.insert(ev)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ListeningEvent>()).first
        #expect(fetched?.trackTitle == "t")
        #expect(fetched?.outcome == .completed)
        #expect(fetched?.listenedMs == 95000)
        #expect(fetched?.completionRatio == 0.95)
        #expect(fetched?.endedAt != nil)
    }

    @Test("ListeningEvent table included in schema (empty query succeeds)")
    func schemaIncludesListeningEvent() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        #expect(try ctx.fetch(FetchDescriptor<ListeningEvent>()).isEmpty)
    }

    // MARK: - HistoryService event persistence

    @Test("trackStarted to trackCompleted persists one completed event")
    func completedPersists() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        let svc = HistoryService(modelContainer: container, eventBus: bus,
                                 enabledProvider: { true })
        let id = UUID()
        bus.post(.trackStarted(snap("A", id: id)))
        bus.post(.trackCompleted(snap("A", id: id), listenedMs: 200_000))
        let ctx = ModelContext(container)
        let events = try ctx.fetch(FetchDescriptor<ListeningEvent>())
        #expect(events.count == 1)
        #expect(events[0].outcome == .completed)
        #expect(events[0].trackId == id)
        #expect(events[0].listenedMs == 200_000)
        #expect(events[0].completionRatio == 1.0)  // 200000 / 200000ms
        _ = svc
    }

    @Test("trackSkipped persists skipped and trackStopped persists stopped")
    func skippedStoppedClassify() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        let svc = HistoryService(modelContainer: container, eventBus: bus, enabledProvider: { true })
        let a = UUID(), b = UUID()
        bus.post(.trackStarted(snap("A", id: a)))
        bus.post(.trackSkipped(snap("A", id: a), listenedMs: 5_000))
        bus.post(.trackStarted(snap("B", id: b)))
        bus.post(.trackStopped(snap("B", id: b), listenedMs: 180_000))
        let ctx = ModelContext(container)
        let events = try ctx.fetch(FetchDescriptor<ListeningEvent>())
        #expect(events.count == 2)
        #expect(events.contains { $0.outcome == .skipped && $0.trackId == a && $0.listenedMs == 5_000 })
        #expect(events.contains { $0.outcome == .stopped && $0.trackId == b && $0.listenedMs == 180_000 })
        _ = svc
    }

    @Test("New trackStarted overwrites unfinalized event falling back to interrupted")
    func interruptedFallback() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        let svc = HistoryService(modelContainer: container, eventBus: bus, enabledProvider: { true })
        bus.post(.trackStarted(snap("A")))
        // No terminal event; a new track starts directly
        bus.post(.trackStarted(snap("B")))
        let ctx = ModelContext(container)
        let events = try ctx.fetch(FetchDescriptor<ListeningEvent>())
        #expect(events.count == 1)
        #expect(events[0].outcome == .interrupted)
        #expect(events[0].listenedMs == 0)
        _ = svc
    }

    @Test("Does not persist when feature disabled; persists when enabled")
    func featureFlagGating() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        // Reference-type flag, avoiding the ambiguity of closures capturing a local `var`.
        let flag = HistoryFlag17()
        let svc = HistoryService(modelContainer: container, eventBus: bus,
                                 enabledProvider: { flag.on })
        let a = UUID(), b = UUID()
        bus.post(.trackStarted(snap("A", id: a)))
        bus.post(.trackCompleted(snap("A", id: a), listenedMs: 200_000))
        #expect((try ModelContext(container).fetch(FetchDescriptor<ListeningEvent>())).isEmpty)

        flag.on = true
        bus.post(.trackStarted(snap("B", id: b)))
        bus.post(.trackSkipped(snap("B", id: b), listenedMs: 3_000))
        #expect((try ModelContext(container).fetch(FetchDescriptor<ListeningEvent>())).count == 1)
        _ = svc
    }

    @Test("pause/resume/seek/queueChanged do not generate event rows")
    func nonFinalizingEventsNoRow() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        let svc = HistoryService(modelContainer: container, eventBus: bus, enabledProvider: { true })
        let s = snap("A")
        bus.post(.trackStarted(s))
        bus.post(.trackPaused(s))
        bus.post(.trackResumed(s))
        bus.post(.trackSeeked(trackId: s.id, toMs: 10000))
        bus.post(.queueChanged)
        #expect((try ModelContext(container).fetch(FetchDescriptor<ListeningEvent>())).isEmpty)
        _ = svc
    }

    // MARK: - End to end (PlaybackService → event bus → HistoryService, stub engine)

    @Test("Play then skip to next: HistoryService records skipped")
    func endToEndSkipRecords() async throws {
        let container = try makeContainer()
        let library = LibraryService(modelContainer: container)
        let queue = QueueService()
        let engine = StubPlayerEngine17()
        let playback = PlaybackService(youtubeEngine: engine, queue: queue, library: library)
        let svc = HistoryService(modelContainer: container, eventBus: playback.eventBus,
                                 enabledProvider: { true })

        let a = snap("A", durationSec: 200)
        let b = snap("B", durationSec: 200)
        playback.playTrack(a, context: [a, b], from: .songs)
        try await Task.sleep(for: .milliseconds(120))   // wait for the async load + trackStarted
        // The stub engine never advances position → listenedMs = 0 < threshold → skipped
        playback.next()
        try await Task.sleep(for: .milliseconds(120))

        let events = try ModelContext(container).fetch(FetchDescriptor<ListeningEvent>())
        #expect(events.contains { $0.outcome == .skipped && $0.trackTitle == "A" })
        _ = svc
    }

    @Test("Engine natural completion callback: HistoryService records completed")
    func endToEndCompletionRecords() async throws {
        let container = try makeContainer()
        let library = LibraryService(modelContainer: container)
        let queue = QueueService()
        let engine = StubPlayerEngine17()
        let playback = PlaybackService(youtubeEngine: engine, queue: queue, library: library)
        let svc = HistoryService(modelContainer: container, eventBus: playback.eventBus,
                                 enabledProvider: { true })

        let a = snap("A", durationSec: 200)
        playback.playTrack(a, context: [a], from: .songs)
        try await Task.sleep(for: .milliseconds(120))
        // Simulate natural completion: fire the onCompletion callback (PlaybackService takes over as the completed path).
        engine.fireCompletion()
        try await Task.sleep(for: .milliseconds(120))

        let events = try ModelContext(container).fetch(FetchDescriptor<ListeningEvent>())
        // A completion marks the media position as complete, while listening
        // time reflects the short interval actually played by this test.
        #expect(events.contains { $0.outcome == .completed && $0.trackTitle == "A"
            && $0.listenedMs > 0 && $0.listenedMs < 5_000 && $0.completionRatio == 1 })
        _ = svc
    }

    @Test("seek and pause do not inflate listening time or suppress a skip")
    func seekPauseListeningTime() async throws {
        let container = try makeContainer()
        let queue = QueueService()
        let engine = StubPlayerEngine17()
        var uptime = 1_000.0
        let playback = PlaybackService(engine: engine, queue: queue,
                                       uptimeProvider: { uptime })
        let history = HistoryService(modelContainer: container,
                                     eventBus: playback.eventBus,
                                     enabledProvider: { true })
        let track = snap("A", durationSec: 200)
        playback.playTrack(track, context: [track], from: .songs)
        for _ in 0..<100 where engine.state.track?.id != track.id {
            try await Task.sleep(for: .milliseconds(5))
        }
        playback.seek(to: 180)
        uptime += 3
        playback.pause()
        uptime += 100
        playback.play()
        uptime += 2
        playback.next()

        let event = try #require(ModelContext(container)
            .fetch(FetchDescriptor<ListeningEvent>()).first)
        #expect(event.outcome == .skipped)
        #expect(event.listenedMs == 5_000)
        #expect(event.completionRatio == 0.9)
        withExtendedLifetime(history) {}
    }

    // MARK: - Query and aggregation

    @Test("HistoryQuery filters by outcome and text")
    func queryFilters() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        let svc = HistoryService(modelContainer: container, eventBus: bus, enabledProvider: { true })
        let solar = UUID(), lunar = UUID()
        bus.post(.trackStarted(snap("Solar", id: solar)))
        bus.post(.trackCompleted(snap("Solar", id: solar), listenedMs: 200_000))
        bus.post(.trackStarted(snap("Lunar", id: lunar)))
        bus.post(.trackSkipped(snap("Lunar", id: lunar), listenedMs: 4_000))

        #expect(svc.events(matching: HistoryQuery(outcome: .skipped)).count == 1)
        #expect(svc.events(matching: HistoryQuery(outcome: .completed)).count == 1)
        #expect(svc.events(matching: HistoryQuery(titleContains: "Lun")).count == 1)
        #expect(svc.events(matching: HistoryQuery(artistContains: "Solar")).count == 1)
        _ = svc
    }

    @Test("recap aggregates total time, counts, unique items, and top tracks")
    func recapAggregation() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        let svc = HistoryService(modelContainer: container, eventBus: bus, enabledProvider: { true })
        let solar = UUID(), lunar = UUID()
        // The same Solar track played to completion twice
        bus.post(.trackStarted(snap("Solar", id: solar)))
        bus.post(.trackCompleted(snap("Solar", id: solar), listenedMs: 200_000))
        bus.post(.trackStarted(snap("Solar", id: solar)))
        bus.post(.trackCompleted(snap("Solar", id: solar), listenedMs: 200_000))
        bus.post(.trackStarted(snap("Lunar", id: lunar)))
        bus.post(.trackSkipped(snap("Lunar", id: lunar), listenedMs: 4_000))

        let recap = svc.recap(range: .allTime)
        #expect(recap.eventCount == 3)
        #expect(recap.completedCount == 2)
        #expect(recap.skippedCount == 1)
        #expect(recap.uniqueTracks == 2)
        #expect(recap.totalListenedMs == 404_000)
        #expect(recap.topTracks.first?.title == "Solar")
        #expect(recap.topTracks.first?.plays == 2)
        #expect(recap.topArtists.first?.name == "Artist Solar")
        let heatmap = try svc.dashboard(range: .allTime).heatmap
        #expect(heatmap.rows.count == 7)
        #expect(heatmap.rows.flatMap(\.cells).count == 168)
        #expect(heatmap.totalMs == 404_000)
        _ = svc
    }

    @Test("History display repairs exact owner credits without rewriting historical truth")
    func dashboardDisplayCreditsPreserveHistory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let library = LibraryService(modelContainer: container)
        let service = HistoryService(modelContainer: container, eventBus: PlaybackEventBus(),
                                     enabledProvider: { true })
        let cache = SongCreditCache()
        let ownerTrack = Track(title: "Same title", artist: "Playlist owner", youTubeId: "historyA001")
        let verifiedTrack = Track(title: "Verified", artist: "Verified performer", youTubeId: "historyB001")
        let otherTrack = Track(title: "Same title", artist: "Playlist owner", youTubeId: "historyC001")
        let editedTrack = Track(title: "Edited today", artist: "Today's edit", youTubeId: "historyD001")
        for track in [ownerTrack, verifiedTrack, otherTrack, editedTrack] { context.insert(track) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let storedCredits: [(UUID, String)] = [
            (ownerTrack.id, "Playlist owner"), (verifiedTrack.id, "Verified performer"),
            (otherTrack.id, "Playlist owner"), (editedTrack.id, "Historical manual credit"),
            (UUID(), "Deleted song credit")
        ]
        for (index, credit) in storedCredits.enumerated() {
            context.insert(ListeningEvent(
                trackId: credit.0, trackTitle: "Historical title \(index)", artist: credit.1,
                startedAt: now.addingTimeInterval(-600 + Double(index) * 60),
                endedAt: now.addingTimeInterval(-590 + Double(index) * 60),
                listenedMs: 10_000, completionRatio: 0.5, outcome: .stopped))
        }
        try context.save()
        cache.recordOwner("Playlist owner", videoID: ownerTrack.youTubeId)
        cache.recordOwner("Playlist owner", videoID: otherTrack.youTubeId)
        let raw = try service.dashboard(range: .allTime, now: now)
        func displayed() throws -> ListeningHistoryDashboard {
            try service.dashboard(range: .allTime, now: now) { trackID, storedArtist in
                guard let track = library.track(by: trackID) else { return storedArtist }
                return cache.historicalArtist(videoID: track.youTubeId, storedArtist: storedArtist)
            }
        }
        let beforeMetadata = try displayed()
        #expect(beforeMetadata.recap.topTracks.first(where: { $0.id == ownerTrack.id })?.artist
                == tr("Artist unavailable", "艺人信息暂缺"))
        #expect(beforeMetadata.recap.topTracks.first(where: { $0.id == verifiedTrack.id })?.artist
                == "Verified performer")
        #expect(beforeMetadata.recap.uniqueArtists == 3)
        #expect(beforeMetadata.recap.topArtists.allSatisfy {
            !SongDisplayInformation.isMissingCredit($0.name)
        })
        #expect(beforeMetadata.recap.totalListenedMs == raw.recap.totalListenedMs)
        #expect(beforeMetadata.heatmap.nonzeroCells.allSatisfy { cell in
            cell.artistCount == Set(cell.slices.filter {
                !SongDisplayInformation.isMissingCredit($0.artist)
            }.map(\.artist)).count
        })
        cache.store(.init(id: editedTrack.youTubeId, title: "Edited today", artist: "Current verified performer"))
        cache.store(.init(id: ownerTrack.youTubeId, title: "Same title", uploader: "Publisher A",
                          artist: "Verified performer"))
        cache.store(.init(id: otherTrack.youTubeId, title: "Same title", uploader: "Publisher C",
                          artist: "Different performer"))
        let resolved = try displayed()
        #expect(resolved.recap.topArtists.first(where: { $0.name == "Verified performer" })?.plays == 2)
        #expect(resolved.recap.topArtists.first(where: { $0.name == "Verified performer" })?.listenedMs == 20_000)
        #expect(resolved.recap.topTracks.first(where: { $0.id == otherTrack.id })?.artist == "Different performer")
        #expect(resolved.recap.topTracks.first(where: { $0.id == editedTrack.id })?.artist == "Historical manual credit")
        #expect(resolved.recap.topArtists.contains { $0.name == "Deleted song credit" })
        #expect(resolved.recap.uniqueArtists == 4)
        #expect(resolved.recap.eventCount == raw.recap.eventCount)
        #expect(resolved.recap.uniqueTracks == raw.recap.uniqueTracks)
        #expect(resolved.recap.totalListenedMs == raw.recap.totalListenedMs)
        #expect(resolved.heatmap.totalMs == raw.heatmap.totalMs)
        #expect(resolved.heatmap.nonzeroCells.flatMap(\.slices).contains {
            $0.trackId == ownerTrack.id && $0.artist == "Verified performer"
        })
        #expect(resolved.recent == raw.recent)
        let reloadedRaw = try service.dashboard(range: .allTime, now: now)
        // Equal-count rankings do not promise an ordering; compare stable identities.
        #expect(reloadedRaw.recap.topTracks.sorted { $0.id.uuidString < $1.id.uuidString }
                == raw.recap.topTracks.sorted { $0.id.uuidString < $1.id.uuidString })
        #expect(reloadedRaw.recap.topArtists.sorted { $0.id < $1.id }
                == raw.recap.topArtists.sorted { $0.id < $1.id })
        #expect(reloadedRaw.recap.totalListenedMs == raw.recap.totalListenedMs)
        #expect(reloadedRaw.recap.eventCount == raw.recap.eventCount)
        #expect(reloadedRaw.heatmap == raw.heatmap)
        #expect(reloadedRaw.recent == raw.recent)
        let persisted = try ModelContext(container).fetch(FetchDescriptor<ListeningEvent>())
        #expect(Dictionary(uniqueKeysWithValues: persisted.map { ($0.trackId, $0.artist) })
                == Dictionary(uniqueKeysWithValues: storedCredits))
        #expect(library.track(by: ownerTrack.id)?.artist == "Playlist owner")
        #expect(library.track(by: editedTrack.id)?.artist == "Today's edit")
    }

    @Test("dashboard keeps timeline inside the selected calendar range")
    func dashboardScopesRecentActivityToSelectedRange() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldStart = now.addingTimeInterval(-3 * 86_400)
        context.insert(ListeningEvent(
            trackId: UUID(), trackTitle: "Earlier", artist: "Artist Earlier",
            albumTitle: nil, startedAt: oldStart, endedAt: oldStart.addingTimeInterval(120),
            listenedMs: 120_000, completionRatio: 1, outcome: .completed
        ))
        try context.save()

        let service = HistoryService(modelContainer: container, eventBus: PlaybackEventBus(),
                                     enabledProvider: { true })
        let dashboard = try service.dashboard(range: .day, now: now)
        #expect(dashboard.totalEventCount == 1)
        #expect(dashboard.recap.eventCount == 0)
        #expect(dashboard.recent.isEmpty)
    }

    @Test("dashboard exposes stored completion without inventing a duration")
    func dashboardStoredCompletion() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_800_003_600)
        for (title, ratio) in [("Known", Optional(0.37)), ("Unknown", nil)] {
            context.insert(ListeningEvent(
                trackId: UUID(), trackTitle: title, artist: "Artist", albumTitle: nil,
                startedAt: now.addingTimeInterval(-60), endedAt: now.addingTimeInterval(-10),
                listenedMs: 37_000, completionRatio: ratio, outcome: .stopped
            ))
        }
        try context.save()
        let service = HistoryService(modelContainer: container, eventBus: PlaybackEventBus(),
                                     enabledProvider: { true })
        let rows = try service.dashboard(range: .day, now: now).recent
        #expect(rows.first(where: { $0.title == "Known" })?.completionRatio == 0.37)
        #expect(rows.contains { $0.title == "Unknown" && $0.completionRatio == nil })
    }

    @Test("clearAll clears all events and bumps revision")
    func clearAll() throws {
        let container = try makeContainer()
        let bus = PlaybackEventBus()
        let svc = HistoryService(modelContainer: container, eventBus: bus, enabledProvider: { true })
        bus.post(.trackStarted(snap("A")))
        bus.post(.trackCompleted(snap("A"), listenedMs: 100_000))
        #expect(svc.eventCount() == 1)
        let rev = svc.historyRevision
        svc.clearAll()
        #expect(svc.eventCount() == 0)
        #expect(svc.historyRevision > rev)
        _ = svc
    }
}

/// Stub engine for these tests: load/play never throw and AVAudioEngine is never touched
/// (avoids the "player did not see an IO cycle" ObjC exception under headless CI).
/// position never advances on its own, keeping the skip verdict predictable (listenedMs = 0).
@MainActor
private final class StubPlayerEngine17: PlayerEngine {
    let state = PlayerState()
    var onCompletion: (@MainActor () -> Void)?

    func load(_ track: TrackSnapshot) async throws {
        state.track = track
        state.duration = track.durationSeconds
        state.position = 0
        state.isPlaying = true
    }
    func prepare(_ track: TrackSnapshot) async {}
    @discardableResult
    func playPrepared(expectedTrackID: UUID) -> Bool { false }
    func play() { state.isPlaying = true }
    func pause() { state.isPlaying = false }
    func toggle() { state.isPlaying.toggle() }
    func seek(to time: Double) { state.position = time }
    func setVolume(_ v: Float) {}
    func setEQ(_ bands: [EQBand]) {}
    func installSpectrumTap(_ handler: @escaping (SpectrumFrame) -> Void) {}
    func removeSpectrumTap() {}

    /// Test hook for "natural completion": calls the onCompletion installed by PlaybackService.
    func fireCompletion() {
        state.position = state.duration
        state.isPlaying = false
        onCompletion?()
    }
}

/// Stub bridge for these tests (never called; exists only to satisfy the YouTubeStreamEngine initializer signature).
@MainActor
private final class StubYTDlpBridge17: YTDlpBridgeProtocol {
    func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL {
        URL(string: "https://example.invalid/\(videoId)")!
    }
    func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] { [] }
    func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] { [] }
    func version() async -> String? { "stub17" }
}

/// Reference-type flag: injected as `enabledProvider` for `featureFlagGating`, so enable/disable toggles stay visible to closures.
@MainActor
private final class HistoryFlag17 {
    var on: Bool = false
}
