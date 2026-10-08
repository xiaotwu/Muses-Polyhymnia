import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Exhausted playback replay", .serialized)
struct ExhaustedPlaybackReplayTests {
    @Test("replay gets a new completion lifecycle and preserves a selected offset", arguments: [false, true])
    func replayAfterNaturalCompletion(seekBeforeReplay: Bool) async throws {
        let suite = "com.muses.test.exhausted-replay-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = RecordingEngine()
        let queue = QueueService()
        queue.setRepeat(.off)
        var uptime: TimeInterval = 0
        let playback = PlaybackService(engine: engine, queue: queue, volumeDefaults: defaults,
                                       uptimeProvider: { uptime })
        let track = TrackSnapshot(id: UUID(), title: "Episode", artist: "Artist", albumTitle: nil,
            durationSeconds: 120, youTubeId: "abcdefghijk", artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
        var completions = 0
        var listened: [Double] = []
        let token = playback.eventBus.subscribe { event in
            if case .trackCompleted(_, let milliseconds, _) = event {
                completions += 1
                listened.append(milliseconds)
            }
        }
        defer { playback.pause(); playback.eventBus.unsubscribe(token) }
        playback.playTrack(track, context: [track], from: .search)
        for _ in 0..<200 where engine.onCompletion == nil { await Task.yield() }
        let previousCompletion = try #require(engine.onCompletion)
        let occurrenceID = try #require(queue.current()?.id)
        engine.state.position = 120
        engine.state.isPlaying = false
        uptime = 2
        previousCompletion()
        #expect(completions == 1)
        #expect(playback.primaryAction == .play)

        if seekBeforeReplay { playback.seek(to: 30) }
        queue.setRepeat(.all)
        uptime = 3
        playback.play()
        for _ in 0..<200 where engine.loadCallCount < 2 { await Task.yield() }
        #expect(engine.loadCallCount == 2)
        #expect(engine.state.position == (seekBeforeReplay ? 30 : 0))
        #expect(queue.current()?.id == occurrenceID)

        // A delayed callback from the exhausted engine lifecycle cannot consume the replay.
        engine.state.isPlaying = false
        previousCompletion()
        #expect(completions == 1)
        engine.state.position = 120
        uptime = 5
        engine.onCompletion?()
        #expect(completions == 2)
        #expect(listened == [2_000, 2_000])
        for _ in 0..<200 where engine.loadCallCount < 3 { await Task.yield() }
        #expect(engine.loadCallCount == 3)
        #expect(engine.state.position == 0)
        #expect(queue.current()?.id == occurrenceID)
        #expect(queue.history.count == 1)
    }

    @Test("automatic same-occurrence loops count only their own listening interval", arguments: [false, true])
    func naturalLoopListeningIntervals(repeatAll: Bool) async throws {
        let suite = "com.muses.test.completed-loop-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = RecordingEngine()
        let queue = QueueService()
        queue.setRepeat(repeatAll ? .all : .one)
        var uptime: TimeInterval = 0
        let playback = PlaybackService(engine: engine, queue: queue, volumeDefaults: defaults,
                                       uptimeProvider: { uptime })
        let track = TrackSnapshot(id: UUID(), title: "Song", artist: "Artist", albumTitle: nil,
            durationSeconds: 120, youTubeId: "abcdefghijk", artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
        var listened: [Double] = []
        var starts = 0
        let token = playback.eventBus.subscribe { event in
            if case .trackCompleted(_, let milliseconds, _) = event { listened.append(milliseconds) }
            if case .trackStarted = event { starts += 1 }
        }
        defer { playback.pause(); playback.eventBus.unsubscribe(token) }
        playback.playTrack(track, context: [track], from: .search)
        for _ in 0..<200 where engine.onCompletion == nil { await Task.yield() }
        let occurrenceID = try #require(queue.current()?.id)
        for (cycle, endTime) in [2.0, 5.0].enumerated() {
            uptime = endTime
            engine.state.position = 120
            engine.state.isPlaying = false
            engine.onCompletion?()
            for _ in 0..<200 where engine.loadCallCount < cycle + 2 { await Task.yield() }
        }
        #expect(listened == [2_000, 3_000])
        #expect(starts == 3)
        #expect(engine.loadCallCount == 3)
        #expect(queue.current()?.id == occurrenceID)
        #expect(queue.history.count == 2)
        #expect(Set(queue.history.compactMap(\.historyRecordID)).count == 2)
    }
}
