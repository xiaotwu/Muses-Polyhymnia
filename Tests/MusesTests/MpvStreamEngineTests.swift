import Foundation
import Testing
@testable import Muses

/// These are state-machine tests only. They do not establish native audio output or distribution acceptance.
@MainActor
@Suite("MpvStreamEngine", .serialized)
struct MpvStreamEngineTests {
    private func track(_ video: String = "video") -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: "Track", artist: "Artist", albumTitle: nil,
                      durationSeconds: 120, youTubeId: video, artworkUrl: nil,
                      sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
    }

    @Test("Resolved headers and actual source metadata reach the driver")
    func typedResolution() async throws {
        let provider = MpvTestProvider()
        provider.stream = ResolvedAudioStream(url: URL(string: "https://example.test/audio")!,
            requestHeaders: ["User-Agent": "Muses", "Referer": "https://music.youtube.com/"],
            formatID: "251", codec: "opus", container: "webm", bitrateKbps: 160,
            sampleRate: 48000, contextID: "public")
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client })
        try await engine.load(track())
        #expect(client.streams.last == provider.stream)
        #expect(engine.resolvedStream?.formatID == "251")
        #expect(engine.state.quality?.codec == "opus")
        #expect(engine.state.quality?.sampleRate == 48000)
        #expect(engine.state.quality?.bitrateKbps == 160)
        #expect(engine.state.quality?.formatID == "251")
        #expect(!engine.state.buffering)
        client.send(.loaded)
        engine.play()
        #expect(engine.state.isPlaying)
    }

    @Test("load waits for media readiness and cancellation completes before an uncooperative driver")
    func readinessAndPromptCancellation() async throws {
        let client = MpvTestClient()
        client.automaticallyLoads = false
        let engine = MpvStreamEngine(provider: MpvTestProvider(), clientFactory: { client })
        var returned = false
        let loading = Task { try await engine.load(track()); returned = true }
        while client.streams.isEmpty { await Task.yield() }
        #expect(!returned)
        #expect(engine.state.buffering)
        client.send(.loaded)
        try await loading.value
        #expect(returned)
        #expect(!engine.state.isPlaying)

        let next = Task { try await engine.load(track("next")) }
        while client.streams.count < 2 { await Task.yield() }
        next.cancel()
        _ = try? await next.value
        client.send(.loaded)
        client.send(.paused(false))
        #expect(!engine.state.isPlaying)
        #expect(!engine.state.buffering)
    }

    @Test("A decoder that never becomes ready produces an attributed bounded failure")
    func readinessTimeout() async {
        let client = MpvTestClient()
        client.automaticallyLoads = false
        let engine = MpvStreamEngine(provider: MpvTestProvider(), clientFactory: { client },
                                     readinessTimeoutDuration: .milliseconds(10))
        do {
            try await engine.load(track())
            Issue.record("Expected readiness timeout")
        } catch {
            #expect(engine.lastFailure?.stage == .load)
            #expect(engine.lastFailure?.code == -1013)
            #expect(!engine.state.buffering)
            #expect(!engine.state.isPlaying)
        }
    }

    @Test("Old decoder events cannot mutate a replacement, even for the same media identity")
    func staleEvents() async throws {
        let provider = MpvTestProvider()
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client })
        let sameTrack = track()
        var completions = 0
        engine.onCompletion = { completions += 1 }
        try await engine.load(sameTrack)
        let old = client.generation
        try await engine.load(sameTrack)
        client.send(.loaded)
        engine.play()
        client.send(.position(42), generation: old)
        client.send(.failed(MpvFailure(stage: .decode, code: -13)), generation: old)
        client.send(.ended, generation: old)
        #expect(engine.state.position == 0)
        #expect(engine.state.error == nil)
        #expect(completions == 0)
        client.send(.ended)
        client.send(.ended)
        #expect(completions == 1)
    }

    @Test("Pause and pending seek survive late ready, cache and clock events")
    func intentAndSeek() async throws {
        let provider = MpvTestProvider()
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client })
        try await engine.load(track())
        engine.play()
        engine.seek(to: 30)
        engine.pause()
        client.send(.loaded)
        #expect(client.seeks.contains(30))
        client.send(.position(0))
        #expect(engine.state.position == 30)
        engine.seek(to: 80)
        client.send(.position(30))
        client.send(.restarted)
        #expect(engine.state.position == 80)
        #expect(!engine.state.isPlaying)
        client.send(.position(80))
        client.send(.buffering(false))
        client.send(.paused(false))
        #expect(!engine.state.isPlaying)
        #expect(client.properties.last?.value == "yes")
        engine.play()
        #expect(engine.state.isPlaying)
    }

    @Test("EOF while paused cannot auto-advance; resume consumes completion once")
    func pausedCompletion() async throws {
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: MpvTestProvider(), clientFactory: { client })
        var completions = 0
        engine.onCompletion = { completions += 1 }
        try await engine.load(track())
        client.send(.loaded)
        engine.play()
        engine.pause()
        client.send(.ended)
        #expect(completions == 0)
        engine.play()
        engine.play()
        #expect(completions == 1)
    }

    @Test("Uncooperative older resolution cannot load over a newer track")
    func supersededResolution() async throws {
        let provider = MpvTestProvider()
        provider.suspendedVideo = "old"
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client })
        let old = Task { try await engine.load(track("old")) }
        while provider.pending == nil { await Task.yield() }
        let replacement = track("new")
        try await engine.load(replacement)
        provider.resume()
        _ = try? await old.value
        #expect(client.streams.count == 1)
        #expect(engine.state.track?.id == replacement.id)
        #expect(engine.state.error == nil)
    }

    @Test("Cancelled resolution cannot open an audible backend")
    func cancelledResolution() async {
        let provider = MpvTestProvider()
        provider.suspendedVideo = "wait"
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client })
        let loading = Task { try await engine.load(track("wait")) }
        while provider.pending == nil { await Task.yield() }
        loading.cancel()
        // Await cancellation before allowing the deliberately uncooperative provider to finish.
        _ = try? await loading.value
        #expect(client.streams.isEmpty)
        provider.resume()
        await Task.yield()
        #expect(client.streams.isEmpty)
        #expect(!engine.state.isPlaying)
        #expect(!engine.state.buffering)
    }

    @Test("Prepared URL is reused, but never advertised as a decoded gapless standby")
    func boundedPrefetch() async throws {
        let provider = MpvTestProvider()
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client })
        let next = track("next")
        await engine.prepare(next)
        await engine.prewarmSelections([track("focus"), track("unused")])
        #expect(provider.calls == ["next"])
        #expect(!engine.playPrepared(expectedTrackID: next.id))
        #expect(client.streams.isEmpty)
        try await engine.load(next)
        #expect(provider.calls == ["next"])
        #expect(client.streams.count == 1)
    }

    @Test("Expired or credential-bearing resolutions fail closed before opening libmpv")
    func rejectedContext() async {
        let provider = MpvTestProvider()
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client })
        for headers in [["Cookie": "secret"], ["User-Agent": "bad\r\nInjected: value"]] {
            provider.stream = ResolvedAudioStream(url: URL(string: "https://example.test/audio")!, requestHeaders: headers)
            _ = try? await engine.load(track())
            #expect(engine.state.error == .sourceUnavailable)
        }
        provider.stream = ResolvedAudioStream(url: URL(string: "https://example.test/audio")!, expiresAt: .distantPast)
        _ = try? await engine.load(track())
        #expect(client.streams.isEmpty)
    }

    @Test("Volume, rate and octave-bandwidth EQ use real backend controls; spectrum is absent")
    func processingControls() async throws {
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: MpvTestProvider(), clientFactory: { client })
        engine.setVolume(0.5)
        engine.setPlaybackRate(1.5)
        engine.setEQ([EQBand(frequency: 1000, gain: 3, q: 1)])
        try await engine.load(track())
        #expect(client.properties.contains { $0.name == "volume" && $0.value == "50.0" })
        #expect(client.properties.contains { $0.name == "speed" && $0.value == "1.5" })
        #expect(client.properties.contains { $0.name == "af" && $0.value.contains("t=o:w=1.0:g=3.0") })
        var frames = 0
        engine.installSpectrumTap { _ in frames += 1 }
        client.send(.loaded)
        engine.play()
        client.send(.position(1))
        #expect(engine.equalizerAvailable)
        #expect(engine.state.audioProcessing == .eqOnly)
        #expect(!engine.supportsSpectrum)
        #expect(frames == 0)
    }

    @Test("EQ failure downgrades capability; failed transport controls stop the native authority")
    func controlFailures() async throws {
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: MpvTestProvider(), clientFactory: { client })
        try await engine.load(track())
        engine.play()
        client.send(.failed(MpvFailure(stage: .control, code: -11, property: "af")))
        #expect(engine.state.error == nil)
        #expect(!engine.equalizerAvailable)
        #expect(engine.state.audioProcessing == .streamOnly)
        #expect(engine.state.isPlaying)
        client.send(.failed(MpvFailure(stage: .control, code: -11, property: "pause")))
        #expect(engine.state.error != nil)
        #expect(!engine.state.isPlaying)
        #expect(engine.state.audioProcessing == .unavailable)
    }

    @Test("Decoder failure stops transport without masquerading as natural completion")
    func decoderFailure() async throws {
        let client = MpvTestClient()
        let engine = MpvStreamEngine(provider: MpvTestProvider(), clientFactory: { client })
        var completions = 0
        engine.onCompletion = { completions += 1 }
        try await engine.load(track())
        client.send(.loaded)
        engine.play()
        client.send(.failed(MpvFailure(stage: .decode, code: -13)))
        client.send(.ended)
        #expect(!engine.state.isPlaying)
        #expect(!engine.state.buffering)
        #expect(engine.lastFailure?.code == -13)
        #expect(completions == 0)
    }
}

@MainActor
private final class MpvTestProvider: ResolvedStreamProvider {
    var stream = ResolvedAudioStream(url: URL(string: "https://example.test/audio")!)
    var calls: [String] = []
    var suspendedVideo: String?
    var pending: CheckedContinuation<ResolvedAudioStream, Error>?
    func resolveStream(videoID: String, quality: String) async throws -> ResolvedAudioStream {
        calls.append(videoID)
        if suspendedVideo == videoID {
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        return stream
    }
    func resume() { pending?.resume(returning: stream); pending = nil }
    func invalidateStream(videoID: String, quality: String) {}
}

@MainActor
private final class MpvTestClient: MpvClient {
    struct Property { let name: String; let value: String; let generation: UInt64 }
    var onEvent: (@MainActor @Sendable (UInt64, MpvEvent) -> Void)?
    var streams: [ResolvedAudioStream] = []
    var generation: UInt64 = 0
    var properties: [Property] = []
    var seeks: [Double] = []
    var stops = 0
    var automaticallyLoads = true
    func load(_ stream: ResolvedAudioStream, generation: UInt64) async throws {
        self.generation = generation
        streams.append(stream)
        if automaticallyLoads { send(.loaded) }
    }
    func stop() { stops += 1 }
    func set(_ property: String, _ value: String, generation: UInt64) {
        properties.append(Property(name: property, value: value, generation: generation))
        if property == "af" && generation == self.generation { send(.equalizerConfigured) }
    }
    func seek(to seconds: Double, generation: UInt64) { seeks.append(seconds) }
    func send(_ event: MpvEvent, generation: UInt64? = nil) {
        onEvent?(generation ?? self.generation, event)
    }
}
