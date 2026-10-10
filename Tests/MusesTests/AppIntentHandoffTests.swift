import AppIntents
import Foundation
import Testing
@testable import Muses

/// Direct perform calls cover the in-process handoff, not Siri/Shortcuts execution.
@Suite("App Intent in-process handoff") @MainActor
struct AppIntentHandoffTests {
    @Test("video parameters reach the injected app router and its playback instance",
          arguments: ["https://youtu.be/abcdefghijk", "https://music.youtube.com/watch?v=abcdefghijk",
                      "https://www.youtube.com/shorts/abcdefghijk"])
    func videoHandoff(_ text: String) async throws {
        let engine = RecordingEngine()
        let playback = PlaybackService(engine: engine, queue: QueueService())
        defer { playback.pause() }
        let track = makeTrack("abcdefghijk")
        var received: [ExternalPlaybackRoute] = []
        let router = ExternalPlaybackRouter(playback: playback) { route in
            received.append(route)
            return track
        }
        var windowRequests = 0
        var intent = PlayYouTubeLinkIntent(playbackRouter: router) { windowRequests += 1 }
        intent.link = try #require(URL(string: text))

        let result = try await intent.perform()
        for _ in 0..<100 where engine.loadCallCount == 0 { await Task.yield() }

        #expect(received == [.video("abcdefghijk")])
        #expect(windowRequests == 1)
        #expect(playback.transportState.track?.id == track.id)
        #expect(engine.lastLoadedTrack?.id == track.id)
        #expect(playback.queue.current()?.track.id == track.id)
        try expectOrdinaryResult(result)
    }

    @Test("current track parameters resume the same collection and Up Next through the shared router")
    func libraryTrackHandoff() async throws {
        let engine = RecordingEngine()
        let queue = QueueService()
        let playback = PlaybackService(engine: engine, queue: queue)
        defer { playback.pause() }
        let first = makeTrack("first123456")
        let target = makeTrack("second12345")
        let next = makeTrack("upnext12345")
        playback.playTrack(target, context: [first, target], from: .songs)
        for _ in 0..<100 where engine.loadCallCount == 0 { await Task.yield() }
        playback.pause()
        queue.addToQueue(next)
        let collectionIDs = queue.items.map(\.id)
        let upNextIDs = queue.upNext.map(\.id)
        let initialLoads = engine.loadCallCount
        var received: ExternalPlaybackRoute?
        let router = ExternalPlaybackRouter(playback: playback) { route in
            received = route
            return target
        }
        var intent = PlayYouTubeLinkIntent(playbackRouter: router, presentMainWindow: {})
        intent.link = try #require(URL(string: "muses://play?trackId=\(target.id.uuidString)"))

        let result = try await intent.perform()
        for _ in 0..<100 where !playback.transportState.isPlaying { await Task.yield() }

        #expect(received == .track(target.id))
        #expect(queue.items.map(\.track.id) == [first.id, target.id])
        #expect(queue.items.map(\.id) == collectionIDs)
        #expect(queue.current()?.track.id == target.id)
        #expect(queue.upNext.map(\.id) == upNextIDs)
        #expect(engine.loadCallCount == initialLoads)
        #expect(playback.transportState.isPlaying)
        try expectOrdinaryResult(result)
    }

    @Test("unsupported parameters throw before window or playback handoff",
          arguments: ["https://evilyoutube.com/watch?v=abcdefghijk",
                      "https://youtube.com/watch?v=short", "https://youtube.com/playlist?list=PLtest",
                      "https://youtube.com/watch?v=abcdefghijk&v=abcdefghijl",
                      "muses://play?v=abcdefghijk&trackId=bad"])
    func rejectedHandoff(_ text: String) async throws {
        let engine = RecordingEngine()
        let playback = PlaybackService(engine: engine, queue: QueueService())
        defer { playback.pause() }
        var resolutions = 0
        let router = ExternalPlaybackRouter(playback: playback) { _ in
            resolutions += 1
            throw ExternalPlaybackRouter.RoutingError.notFound
        }
        var windowRequests = 0
        var intent = PlayYouTubeLinkIntent(playbackRouter: router) { windowRequests += 1 }
        intent.link = try #require(URL(string: text))

        await #expect(throws: (any Error).self) { _ = try await intent.perform() }

        #expect(windowRequests == 0)
        #expect(resolutions == 0)
        #expect(engine.loadCallCount == 0)
        #expect(playback.queue.items.isEmpty)
    }

    @Test("failed resolution remains an error on the same shared router")
    func resolutionFailure() async throws {
        let engine = RecordingEngine()
        let playback = PlaybackService(engine: engine, queue: QueueService())
        defer { playback.pause() }
        let router = ExternalPlaybackRouter(playback: playback) { _ in
            throw ExternalPlaybackRouter.RoutingError.notFound
        }
        var intent = PlayYouTubeLinkIntent(playbackRouter: router, presentMainWindow: {})
        intent.link = try #require(URL(string: "https://youtu.be/abcdefghijk"))

        let result = try await intent.perform()
        for _ in 0..<100 where router.errorMessage == nil { await Task.yield() }

        #expect(router.errorMessage != nil)
        #expect(engine.loadCallCount == 0)
        #expect(playback.transportState.track == nil)
        try expectOrdinaryResult(result)
    }

    @Test("lyrics handoff preserves editable text and bounds the query",
          arguments: [("", ""), (" \n\t", ""), ("  歌名 & artist? #100%+ 🎵 \n", "歌名 & artist? #100%+ 🎵"),
                      (String(repeating: "A", count: 400) + "B", String(repeating: "A", count: 400)),
                      (String(repeating: "🎵", count: 401), String(repeating: "🎵", count: 400))])
    func lyricsHandoff(_ input: String, _ expected: String) async throws {
        var received: [String] = []
        var intent = SearchLyricsIntent { received.append($0) }
        intent.query = input

        let result = try await intent.perform()

        #expect(received == [expected])
        try expectOrdinaryResult(result)
    }

    private func expectOrdinaryResult(_ result: some IntentResult) throws {
        let ordinary = try #require(result as? IntentResultContainer<Never, Never, Never, Never>)
        #expect(ordinary.opensIntent == nil)
        #expect(ordinary.dialog == nil)
    }

    private func makeTrack(_ videoID: String) -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: videoID, artist: "Artist", albumTitle: nil,
                      durationSeconds: 120, youTubeId: videoID, artworkUrl: nil,
                      sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
    }
}
