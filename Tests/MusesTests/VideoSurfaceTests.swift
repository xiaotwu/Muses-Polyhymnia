import AppKit
import Testing
@testable import Muses

@MainActor
@Suite("Video surface ownership", .serialized)
struct VideoSurfaceTests {
    @Test("Unavailable player stays hidden across repeat attachment and host moves without stopping")
    func unavailablePlayerPresentation() {
        let playback = PlaybackService(engine: RecordingEngine(), queue: QueueService())
        let session = playback.beginVideoSession(videoId: "video00000a")
        let player = NSView(), overlay = NSView(), floating = NSView()
        var stopCount = 0
        let surface = VideoSurface(session: session, playback: playback, resume: false,
            playerView: player, presentsWindow: false) { _ in stopCount += 1 }
        session.surface = surface
        surface.attach(to: overlay, floating: false)
        #expect(!player.isHidden)
        session.fail()
        surface.attach(to: overlay, floating: false, unavailable: true)
        #expect(player.isHidden)
        #expect(player.superview === overlay)
        surface.attach(to: overlay, floating: false, unavailable: true)
        #expect(player.isHidden)
        surface.float()
        surface.attach(to: floating, floating: true, unavailable: true)
        surface.attach(to: overlay, floating: false, unavailable: false)
        #expect(player.isHidden)
        #expect(player.superview === floating)
        surface.dock()
        surface.attach(to: overlay, floating: false, unavailable: true)
        #expect(player.isHidden)
        #expect(player.superview === overlay)
        // Exercise visibility restoration without navigating or creating another player.
        session.state.error = nil
        surface.attach(to: overlay, floating: false, unavailable: false)
        #expect(!player.isHidden)
        #expect(player.superview === overlay)
        #expect(playback.videoSession === session)
        #expect(stopCount == 0)
        surface.close()
        #expect(stopCount == 1)
        playback.finishVideoSession(session, resume: false)
    }

    @Test("Moving between hosts keeps one player and ignores old host updates")
    func movesSamePlayer() {
        let engine = RecordingEngine()
        let playback = PlaybackService(engine: engine, queue: QueueService())
        let session = playback.beginVideoSession(videoId: "video00000a")
        let player = NSView(), overlay = NSView(), floating = NSView()
        var stopCount = 0
        var acknowledge: (() -> Void)?
        let surface = VideoSurface(session: session, playback: playback, resume: true,
                                   playerView: player, presentsWindow: false) { completion in
            stopCount += 1
            acknowledge = completion
        }
        session.surface = surface
        surface.attach(to: overlay, floating: false)
        #expect(player.superview === overlay)
        surface.float()
        surface.attach(to: floating, floating: true)
        surface.attach(to: overlay, floating: false)
        YouTubeWKEmbed.dismantleNSView(overlay, coordinator: ())
        #expect(player.superview === floating)
        #expect(playback.videoSession === session)
        #expect(stopCount == 0)
        surface.dock()
        surface.attach(to: overlay, floating: false)
        YouTubeWKEmbed.dismantleNSView(floating, coordinator: ())
        #expect(player.superview === overlay)
        #expect(stopCount == 0)
        surface.close()
        surface.close()
        surface.float()
        #expect(stopCount == 1)
        #expect(player.superview == nil)
        #expect(playback.videoSession === session)
        acknowledge?()
        #expect(playback.videoSession == nil)
        #expect(session.surface == nil)
    }

    @Test("A floating close waits for media stop before resuming native audio")
    func closeAwaitsMediaStop() {
        let engine = RecordingEngine()
        let playback = PlaybackService(engine: engine, queue: QueueService())
        engine.state.track = TrackSnapshot(id: UUID(), title: "Video", artist: "Artist",
            albumTitle: nil, durationSeconds: 120, youTubeId: "video00000a", artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
        playback.play()
        let session = playback.beginVideoSession(videoId: "video00000a")
        var acknowledge: (() -> Void)?
        let surface = VideoSurface(session: session, playback: playback, resume: true,
                                   playerView: NSView(), presentsWindow: false) { acknowledge = $0 }
        session.surface = surface
        session.didBecomeReady()
        session.receive(position: 42, duration: 120, playerState: 1)
        surface.float()
        #expect(!engine.state.isPlaying)
        surface.close()
        #expect(!engine.state.isPlaying)
        acknowledge?()
        #expect(engine.state.isPlaying)
        #expect(engine.state.position == 42)
        playback.pause()
    }
}
