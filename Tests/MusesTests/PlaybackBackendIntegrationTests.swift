import Foundation
import Testing
@testable import Muses

/// Crosses the real facade/queue/mpv state machines with a deterministic native driver.
/// It establishes behavior, not audible output or network acceptance.
@MainActor
@Suite("Native playback facade integration", .serialized)
struct PlaybackBackendIntegrationTests {
    @Test("An opt-in private test host resolves app paths inside its isolated home")
    func isolatedHomeBoundary() throws {
        guard let expected = ProcessInfo.processInfo.environment["MUSES_TEST_ISOLATED_HOME"] else { return }
        let root = URL(fileURLWithPath: expected).standardizedFileURL
        #expect(URL.homeDirectory.standardizedFileURL == root)
        #expect(FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL == root)
        let appRoot = MusesDataPaths.root(bundleID: Bundle.main.bundleIdentifier).standardizedFileURL.path
        #expect(appRoot.hasPrefix(root.path + "/.muses"))
        #expect(MusesDataPaths.applicationSupport.path.hasPrefix(appRoot + "/"))
        #expect(MusesDataPaths.caches.path.hasPrefix(appRoot + "/"))
    }

    private func track(_ title: String) -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: title, artist: "Artist", albumTitle: nil,
            durationSeconds: 120, youTubeId: title, artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw IntegrationTimeout()
    }

    @Test("Pause during native loading prevents a late ready event from playing or recording history")
    func pauseDuringLoading() async throws {
        let client = FacadeMpvDriver()
        let engine = MpvStreamEngine(provider: FacadeStreamProvider(), clientFactory: { client })
        let queue = QueueService()
        let suite = "com.muses.tests.mpv-facade.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let playback = PlaybackService(engine: engine, queue: queue, volumeDefaults: defaults)
        var starts = 0
        let subscription = playback.eventBus.subscribe { event in
            if case .trackStarted = event { starts += 1 }
        }
        defer { playback.pause(); playback.eventBus.unsubscribe(subscription) }
        let first = track("first")
        playback.playTrack(first, context: [first], from: .search)
        try await waitFor { client.loads.count == 1 }
        playback.pause()
        client.send(.loaded)
        try await waitFor { !engine.state.buffering }
        #expect(!engine.state.isPlaying)
        #expect(starts == 0)
        #expect(queue.current()?.track.id == first.id)
        playback.play()
        #expect(engine.state.isPlaying)
        #expect(starts == 1)
    }

    @Test("Paused restoration keeps its offset and a replaced load cannot start it")
    func pausedRestoreThenReplace() async throws {
        let client = FacadeMpvDriver()
        let engine = MpvStreamEngine(provider: FacadeStreamProvider(), clientFactory: { client })
        let queue = QueueService()
        let suite = "com.muses.tests.mpv-restore.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let playback = PlaybackService(engine: engine, queue: queue, volumeDefaults: defaults)
        defer { playback.pause() }
        let first = track("first"), second = track("second")
        queue.play(first, context: [first, second], from: .search)
        playback.restoreCurrentPaused(atMs: 42_000)
        try await waitFor { client.loads.count == 1 }
        client.send(.loaded)
        try await waitFor { client.seeks.contains(42) }
        #expect(playback.checkpointPositionMs == 42_000)
        #expect(!engine.state.isPlaying)
        let oldGeneration = client.generation
        playback.playTrack(second, context: [first, second], from: .search)
        try await waitFor { client.loads.count == 2 }
        client.send(.position(42), generation: oldGeneration)
        client.send(.ended, generation: oldGeneration)
        client.send(.loaded)
        try await waitFor { engine.state.isPlaying }
        #expect(engine.state.track?.id == second.id)
        #expect(engine.state.position == 0)
        #expect(queue.current()?.track.id == second.id)
    }

    @Test("Natural mpv EOF advances the collection once and rejects the old decoder's late events")
    func completionUsesCollectionQueue() async throws {
        let client = FacadeMpvDriver()
        let engine = MpvStreamEngine(provider: FacadeStreamProvider(), clientFactory: { client })
        let queue = QueueService()
        let suite = "com.muses.tests.mpv-completion.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let playback = PlaybackService(engine: engine, queue: queue, volumeDefaults: defaults)
        var completed = 0
        let subscription = playback.eventBus.subscribe { event in
            if case .trackCompleted = event { completed += 1 }
        }
        defer { playback.pause(); playback.eventBus.unsubscribe(subscription) }
        let first = track("first"), second = track("second")
        playback.playTrack(first, context: [first, second], from: .search)
        try await waitFor { client.loads.count == 1 }
        client.send(.loaded)
        try await waitFor { engine.state.isPlaying }
        let oldGeneration = client.generation
        client.send(.position(120))
        client.send(.ended)
        client.send(.ended)
        try await waitFor { client.loads.count == 2 }
        client.send(.ended, generation: oldGeneration)
        client.send(.failed(MpvFailure(stage: .decode, code: -13)), generation: oldGeneration)
        client.send(.loaded)
        try await waitFor { engine.state.isPlaying }
        #expect(completed == 1)
        #expect(queue.history.count == 1)
        #expect(queue.current()?.track.id == second.id)
        #expect(engine.state.error == nil)
    }
}

private struct IntegrationTimeout: Error {}

@MainActor
private final class FacadeStreamProvider: ResolvedStreamProvider {
    func resolveStream(videoID: String, quality: String) async throws -> ResolvedAudioStream {
        ResolvedAudioStream(url: URL(string: "https://example.test/\(videoID)")!,
            codec: "opus", container: "webm", sampleRate: 48000)
    }
    func invalidateStream(videoID: String, quality: String) {}
}

@MainActor
private final class FacadeMpvDriver: MpvClient {
    var onEvent: (@MainActor @Sendable (UInt64, MpvEvent) -> Void)?
    var generation: UInt64 = 0
    var loads: [ResolvedAudioStream] = []
    var seeks: [Double] = []
    func load(_ stream: ResolvedAudioStream, generation: UInt64) async throws {
        self.generation = generation
        loads.append(stream)
    }
    func stop() {}
    func set(_ property: String, _ value: String, generation: UInt64) {
        if property == "af" { send(.equalizerConfigured, generation: generation) }
    }
    func seek(to seconds: Double, generation: UInt64) { seeks.append(seconds) }
    func send(_ event: MpvEvent, generation: UInt64? = nil) {
        onEvent?(generation ?? self.generation, event)
    }
}
