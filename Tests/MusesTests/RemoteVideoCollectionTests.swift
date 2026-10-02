import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Remote video collection selection", .serialized)
struct RemoteVideoCollectionTests {
    @Test("Snapshot video preserves canonical order and originating collection", arguments: [QueueSource.songs, .playlist, .import, .recently, .album, .artist, .search])
    func snapshotCollection(source: QueueSource) throws {
        let queue = QueueService()
        let playback = PlaybackService(engine: RecordingEngine(), queue: queue)
        let selected = snapshot("video00000b")
        let canonical = [snapshot("video00000c"), selected, snapshot("video00000a")]
        let session = try #require(PlaybackPresentation.prepareVideo(selected,
            context: canonical, source: source, playback: playback))

        #expect(queue.items.map(\.track.id) == canonical.map(\.id))
        #expect(queue.items.map(\.track.youTubeId) == ["video00000c", "video00000b", "video00000a"])
        #expect(queue.currentIndex == 1)
        #expect(queue.items.allSatisfy { $0.fromContext == source })
        #expect(session.videoId == selected.youTubeId)
        playback.pause()
    }

    @Test("Video selection retains repeated source occurrence and podcast resume before readiness")
    func selectsOccurrenceWithResume() throws {
        let queue = QueueService()
        let playback = PlaybackService(engine: RecordingEngine(), queue: queue)
        let selected = snapshot("video00000b", kind: .podcastEpisode)
        let entries = ["video00000b", "video00000a", "video00000b", "video00000c"].map {
            YTDlpBridge.YTDlpPlaylistEntry(id: $0, title: $0)
        }
        let context = TrackSnapshot.playbackContext(playing: selected,
            youTubeEntries: entries, selectedIndex: 2, mediaKind: .podcastEpisode)
        let session = try #require(PlaybackPresentation.prepareVideo(selected,
            context: context, source: .podcast, resumeAtMs: 45_000, playback: playback))

        #expect(queue.items.map(\.track.youTubeId) == entries.map(\.id))
        #expect(queue.currentIndex == 2)
        #expect(queue.current()?.track.id == selected.id)
        #expect(queue.items.allSatisfy { $0.fromContext == .podcast && $0.track.mediaKind == .podcastEpisode })
        #expect(session.videoId == selected.youTubeId)
        #expect(session.state.position == 45)
        #expect(!session.ready)
        var initialPosition: Double?
        session.sendCommand = { command, _ in
            if command == "initialize" { initialPosition = session.state.position }
        }
        session.didBecomeReady()
        #expect(initialPosition == 45)
        session.sendCommand = nil
        playback.pause()
    }

    @Test("Opening current video preserves existing collection and Up Next instead of replacing them")
    func currentVideoPreservesQueue() throws {
        let engine = RecordingEngine()
        let queue = QueueService()
        let playback = PlaybackService(engine: engine, queue: queue)
        let selected = snapshot("video00000b")
        let original = [snapshot("video00000a"), selected, snapshot("video00000c")]
        queue.play(selected, context: original, from: .playlist)
        queue.playNext(snapshot("video00000d"))
        engine.state.track = selected
        engine.state.position = 78
        let originalIDs = queue.items.map(\.id)
        let upNextIDs = queue.upNext.map(\.id)

        let session = try #require(PlaybackPresentation.prepareVideo(selected,
            context: [selected], source: .search, resumeAtMs: 12_000, playback: playback))
        #expect(queue.items.map(\.id) == originalIDs)
        #expect(queue.upNext.map(\.id) == upNextIDs)
        #expect(queue.current()?.fromContext == .playlist)
        #expect(session.state.position == 78)
        #expect(engine.loadCallCount == 0)
        #expect(PlaybackPresentation.prepareVideo(selected, context: [], source: .search,
                                                playback: playback) === session)
        playback.pause()
    }

    private func snapshot(_ id: String, kind: TrackMediaKind = .song) -> TrackSnapshot {
        .init(id: UUID(), title: id, artist: "Publisher", albumTitle: nil,
              durationSeconds: 300, youTubeId: id, artworkUrl: nil,
              sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false, mediaKind: kind)
    }
}
