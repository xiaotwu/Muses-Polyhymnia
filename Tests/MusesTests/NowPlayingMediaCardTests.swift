import AppKit
import Foundation
import MediaPlayer
import Testing
@testable import Muses

@MainActor
@Suite("System media card roles and credits", .serialized)
struct NowPlayingMediaCardTests {
    private func track(_ videoID: String, artist: String = "Artist",
                       kind: TrackMediaKind = .song) -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: "Media", artist: artist, albumTitle: nil,
            durationSeconds: 120, youTubeId: videoID, artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false, mediaKind: kind)
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test("music navigation, podcast intervals and video yielding follow semantic roles")
    func commandRoleTransitions() async throws {
        let suite = "com.muses.test.system-role-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = RecordingEngine()
        let playback = PlaybackService(engine: engine, queue: QueueService(), volumeDefaults: defaults)
        var changes: [SystemMediaCommandAvailability] = []
        let manager = NowPlayingManager(playback, bindsRemoteCommands: false,
            publishCommandAvailability: { changes.append($0) }, artworkLoader: { _ in nil },
            publishInfo: { _ in })
        defer { playback.pause(); withExtendedLifetime(manager) {} }
        let unavailable = SystemMediaCommandAvailability(trackNavigation: false, skipIntervals: false, playbackRate: false)
        let music = SystemMediaCommandAvailability(trackNavigation: true, skipIntervals: false, playbackRate: false)
        let podcast = SystemMediaCommandAvailability(trackNavigation: true, skipIntervals: true, playbackRate: true)
        try await waitFor { !changes.isEmpty }
        #expect(changes.last == unavailable)
        let song = track("abcdefghijk")
        playback.playTrack(song, context: [song], from: .songs)
        try await waitFor { changes.last == music }
        let count = changes.count
        for tick in 1...20 { engine.state.position = Double(tick) / 4; await Task.yield() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(changes.count == count)
        let episode = track("abcdefghij2", kind: .podcastEpisode)
        playback.playTrack(episode, context: [episode], from: .podcast)
        try await waitFor { changes.last == podcast }
        let session = playback.beginVideoSession(videoId: episode.youTubeId)
        try await waitFor { changes.last == unavailable }
        playback.finishVideoSession(session, resume: false)
        try await waitFor { changes.last == podcast }
        playback.playTrack(song, context: [song], from: .songs)
        try await waitFor { changes.last == music }
    }

    @Test("system artist follows verified exact-video credits without rewriting user truth")
    func verifiedArtistPublication() async throws {
        let suite = "com.muses.test.system-credit-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let playback = PlaybackService(engine: RecordingEngine(), queue: QueueService(), volumeDefaults: defaults)
        let credits = SongCreditCache()
        let song = track("abcdefghijk", artist: "Playlist owner")
        credits.recordOwner("Playlist owner", videoID: song.youTubeId)
        var published: [String: Any] = [:]
        let manager = NowPlayingManager(playback, bindsRemoteCommands: false, credits: credits,
            artworkLoader: { _ in nil }, publishInfo: { published = $0 })
        defer { playback.pause(); withExtendedLifetime(manager) {} }
        playback.playTrack(song, context: [song], from: .songs)
        try await waitFor { published[MPMediaItemPropertyTitle] as? String == song.title }
        #expect(published[MPMediaItemPropertyArtist] as? String == tr("Artist unavailable", "艺人信息暂缺"))
        credits.store(.init(id: song.youTubeId, title: song.title, uploader: "Publisher", artist: "Verified artist"))
        try await waitFor { published[MPMediaItemPropertyArtist] as? String == "Verified artist" }
        #expect(playback.state.track?.artist == "Playlist owner")

        let second = track("abcdefghij2", artist: "Second owner")
        credits.recordOwner("Second owner", videoID: second.youTubeId)
        playback.playTrack(second, context: [second], from: .songs)
        credits.store(.init(id: song.youTubeId, title: song.title, uploader: "Old publisher", artist: "Late old artist"))
        try await waitFor { published[MPMediaItemPropertyArtist] as? String == tr("Artist unavailable", "艺人信息暂缺") }
        credits.store(.init(id: second.youTubeId, title: second.title, uploader: "Verified publisher"))
        try await waitFor { published[MPMediaItemPropertyArtist] as? String == "Verified publisher" }

        let custom = track("abcdefghij3", artist: "Custom performer")
        credits.store(.init(id: custom.youTubeId, title: custom.title, uploader: "Publisher", artist: "Source artist"))
        playback.playTrack(custom, context: [custom], from: .songs)
        try await waitFor { published[MPMediaItemPropertyArtist] as? String == "Custom performer" }
        #expect(playback.state.track == custom)
    }

    @Test("interval events cannot seek music or a video that replaced their podcast")
    func intervalEventOwnership() async throws {
        let suite = "com.muses.test.system-skip-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = RecordingEngine()
        let playback = PlaybackService(engine: engine, queue: QueueService(), volumeDefaults: defaults)
        let manager = NowPlayingManager(playback, bindsRemoteCommands: false,
            artworkLoader: { _ in nil }, publishInfo: { _ in })
        defer { playback.pause(); withExtendedLifetime(manager) {} }
        let song = track("abcdefghijk")
        playback.playTrack(song, context: [song], from: .songs)
        try await waitFor { playback.state.track?.id == song.id }
        playback.seek(to: 30)
        manager.handleRemoteSkip(by: 15)
        #expect(playback.state.position == 30)

        let episode = track("abcdefghij2", kind: .podcastEpisode)
        playback.playTrack(episode, context: [episode], from: .podcast)
        try await waitFor { playback.state.track?.id == episode.id }
        playback.seek(to: 30)
        manager.handleRemoteSkip(by: 15)
        #expect(playback.state.position == 45)
        manager.handleRemoteSkip(by: -15)
        #expect(playback.state.position == 30)
        let session = playback.beginVideoSession(videoId: episode.youTubeId)
        let videoPosition = session.state.position
        manager.handleRemoteSkip(by: 15)
        #expect(session.state.position == videoPosition)
        playback.finishVideoSession(session, resume: false)
        #expect(playback.state.position == 30)
    }
}
