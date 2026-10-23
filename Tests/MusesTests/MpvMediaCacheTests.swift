import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Mpv typed media cache", .serialized)
struct MpvMediaCacheTests {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("muses-cache-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func track(_ video: String = "cached") -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: "Cache fixture", artist: "Fixture", albumTitle: nil,
                      durationSeconds: 120, youTubeId: video, artworkUrl: nil,
                      sampleRate: 96000, bitDepth: 24, codec: "stale", isLossless: false)
    }
    private func file(_ root: URL, video: String = "cached", ext: String = "webm") throws -> URL {
        let url = MediaFileCache.file(videoId: video, quality: "bestaudio", ext: ext, in: root)
        try Data(repeating: 42, count: 8192).write(to: url)
        return url
    }

    @Test("Exact regular completed entries are playable; partials, sidecars and symlinks are excluded")
    func exactCompletedCache() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let prefix = "cached__bestaudio."
        for ext in ["webm.partial", "webm.json", "headers", "url", "m4a.sidecar"] {
            try Data(repeating: 42, count: 8192).write(to: root.appendingPathComponent(prefix + ext))
        }
        #expect(MediaFileCache.existing(videoId: "cached", quality: "bestaudio", in: root) == nil)
        let external = root.appendingPathComponent("outside.webm")
        try Data(repeating: 42, count: 8192).write(to: external)
        let link = root.appendingPathComponent(prefix + "webm")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)
        #expect(MediaFileCache.existing(videoId: "cached", quality: "bestaudio", in: root) == nil)
        try FileManager.default.removeItem(at: link)
        let valid = try file(root)
        #expect(MediaFileCache.existing(videoId: "cached", quality: "bestaudio", in: root) == valid)
        #expect(MediaFileCache.existing(videoId: "cached", quality: "128k", in: root) == nil)
        #expect(MediaFileCache.existing(videoId: "../cached", quality: "bestaudio", in: root) == nil)
        #expect(!MediaFileCache.validKey(videoID: "cached", quality: "../../escape"))
        let linkedRoot = root.appendingPathComponent("root-link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: root)
        #expect(MediaFileCache.existing(videoId: "cached", quality: "bestaudio", in: linkedRoot) == nil)
    }

    @Test("Cache replay avoids resolution and reports unknown source bits rather than stale library metadata")
    func replay() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let cached = try file(root)
        let provider = CacheFixtureProvider()
        let client = CacheFixtureClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root)
        try await engine.load(track())
        #expect(provider.qualities.isEmpty)
        #expect(client.streams.last?.url == cached)
        #expect(engine.state.quality?.sampleRate == 0)
        #expect(engine.state.quality?.bitDepth == 0)
        #expect(engine.state.quality?.bitrateKbps == nil)
        #expect(engine.state.quality?.codec == "unknown")
        client.send(.codec("opus"))
        client.send(.sampleRate(48000))
        #expect(engine.state.quality?.codec == "opus")
        #expect(engine.state.quality?.sampleRate == 48000)
    }

    @Test("A provider-returned file URL is rejected even when another track's cache exists")
    func noProviderFileAuthority() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let other = try file(root, video: "other")
        let provider = CacheFixtureProvider()
        provider.stream = ResolvedAudioStream(url: other)
        let client = CacheFixtureClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root)
        do { try await engine.load(track()); Issue.record("Provider file accepted") } catch {}
        #expect(client.streams.isEmpty)
        #expect(engine.state.error != nil)
    }

    @Test("A broken cached decoder has one remote recovery and keeps user pause/seek and file ownership")
    func corruptCacheFallback() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let cached = try file(root)
        let provider = CacheFixtureProvider()
        let client = CacheFixtureClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root)
        var completions = 0
        engine.onCompletion = { completions += 1 }
        try await engine.load(track())
        let old = client.generation
        engine.play()
        engine.seek(to: 60)
        engine.pause()
        client.send(.failed(MpvFailure(stage: .decode, code: -13)))
        while client.streams.count < 2 { await Task.yield() }
        #expect(client.streams.last?.url.scheme == "https")
        #expect(provider.qualities == ["bestaudio"])
        client.send(.ended, generation: old)
        client.send(.position(60))
        #expect(!engine.state.isPlaying)
        #expect(engine.state.position == 60)
        #expect(completions == 0)
        #expect(!FileManager.default.fileExists(atPath: cached.path))
        let retained = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "quarantine" }
        #expect(retained.count == 1)
        if let retained = retained.first { #expect(try Data(contentsOf: retained) == Data(repeating: 42, count: 8192)) }
        client.send(.failed(MpvFailure(stage: .decode, code: -13)))
        #expect(engine.state.error != nil)
        #expect(provider.invalidations.map(\.quality) == ["bestaudio"])
        #expect(client.streams.count == 2)
    }

    @Test("Remote media failure retires its captured-quality URL before the next explicit load")
    func invalidationUsesCapturedQuality() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let provider = CacheFixtureProvider()
        let client = CacheFixtureClient()
        var quality = "128k"
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, qualityProvider: { quality }, cacheDirectory: root)
        try await engine.load(track())
        quality = "256k"
        client.send(.failed(MpvFailure(stage: .decode, code: -13)))
        #expect(provider.invalidations.map(\.quality) == ["128k"])
        quality = "128k"
        try await engine.load(track())
        #expect(provider.qualities == ["128k", "128k"])
        #expect(provider.freshResolutions == 2)
        client.send(.failed(MpvFailure(stage: .control, code: -11, property: "pause")))
        #expect(provider.invalidations.count == 1)
    }

    @Test("Paused remote media atomically publishes the typed container, preserving required headers")
    func pausedDownloadAndPlayCancellation() async throws {
        CacheMediaStub.reset()
        defer { CacheMediaStub.reset() }
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data(repeating: 7, count: 8192)
        let requests = CacheRequestRecorder()
        CacheMediaStub().respond(forHostContaining: "cache.test") { request in
            requests.append(request)
            return StubResponse(statusCode: 206, body: payload,
                headers: ["Content-Range": "bytes 0-8191/8192", "Content-Type": "audio/webm"])
        }
        let provider = CacheFixtureProvider()
        provider.stream = ResolvedAudioStream(url: URL(string: "https://cache.test/audio?signed=not-persisted")!,
            requestHeaders: ["User-Agent": "typed-agent", "Referer": "https://music.youtube.com/"],
            codec: "opus", container: "webm", contextID: "public-1234")
        let client = CacheFixtureClient()
        let session = URLSession(configuration: CacheMediaStub.makeConfig())
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root,
                                     cacheSession: session, cacheDelay: .zero)
        try await engine.load(track())
        await engine.awaitCacheWorkForTests()
        let cached = MediaFileCache.file(videoId: "cached", quality: "bestaudio", ext: "webm", in: root)
        #expect(try Data(contentsOf: cached) == payload)
        #expect(requests.values.first?.value(forHTTPHeaderField: "User-Agent") == "typed-agent")
        #expect(requests.values.first?.value(forHTTPHeaderField: "Referer") == "https://music.youtube.com/")
        #expect(requests.values.first?.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(requests.values.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == [cached.lastPathComponent])

        let second = CacheFixtureClient()
        let cancelled = MpvStreamEngine(provider: provider, clientFactory: { second }, cacheDirectory: root,
                                        cacheSession: session, cacheDelay: .seconds(60))
        try await cancelled.load(track("cancelled"))
        cancelled.play()
        await cancelled.awaitCacheWorkForTests()
        #expect(MediaFileCache.existing(videoId: "cancelled", quality: "bestaudio", in: root) == nil)
        #expect(requests.values.count == 1)
    }

    @Test("Initial cached open failure resolves remotely without completing the caller early")
    func cachedOpenFallback() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try file(root)
        let provider = CacheFixtureProvider()
        let client = CacheFixtureClient()
        client.rejectFileLoads = true
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root)
        try await engine.load(track())
        #expect(client.streams.count == 2)
        #expect(client.streams.first?.url.isFileURL == true)
        #expect(client.streams.last?.url.scheme == "https")
        #expect(engine.state.error == nil)
        #expect(provider.qualities == ["bestaudio"])
        try await engine.load(track())
        #expect(client.streams.count == 3)
        #expect(client.streams.filter { $0.url.isFileURL }.count == 1)
        #expect(client.streams.last?.url.scheme == "https")
    }

    @Test("C numeric properties reject NaN, infinity and out-of-range sample rates")
    func numericBoundary() {
        for number in [Double.nan, .infinity, -.infinity, Double(Int.max), -1, 0, 768001, 44100.5] {
            #expect(MpvNumericValue.sampleRate(number) == nil)
        }
        #expect(MpvNumericValue.sampleRate(48000) == 48000)
        #expect(MpvNumericValue.sampleRate(768000) == 768000)
    }

    @Test("Ephemeral sessions discard injected ambient headers, cookies, credentials and caches")
    func independentSession() {
        let config = CacheMediaStub.makeConfig()
        config.httpAdditionalHeaders = ["Authorization": "test-secret", "Cookie": "ambient=test"]
        let ambient = URLSession(configuration: config)
        let isolated = MediaFileCache.ephemeralSession(copying: ambient)
        defer { ambient.invalidateAndCancel(); isolated.invalidateAndCancel() }
        #expect(isolated.configuration.urlCache == nil)
        #expect(isolated.configuration.httpCookieStorage == nil)
        #expect(isolated.configuration.urlCredentialStorage == nil)
        #expect(isolated.configuration.httpAdditionalHeaders == nil)
        #expect(!isolated.configuration.httpShouldSetCookies)
        #expect(isolated.configuration.protocolClasses?.contains { $0 == CacheMediaStub.self } == true)
    }

    @Test("Typed renewal updates headers once while preserving public representation identity")
    func typedRenewal() async throws {
        CacheMediaStub.reset()
        defer { CacheMediaStub.reset() }
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data(repeating: 3, count: 8192)
        let requests = CacheRequestRecorder()
        CacheMediaStub().respond(forHostContaining: "cache.test") { request in
            requests.append(request)
            if request.url?.path == "/expired" { return StubResponse(statusCode: 403, body: Data()) }
            return StubResponse(statusCode: 206, body: payload,
                headers: ["Content-Range": "bytes 0-8191/8192", "Content-Type": "audio/webm"])
        }
        let source = ResolvedAudioStream(url: URL(string: "https://cache.test/expired")!,
            requestHeaders: ["User-Agent": "first"], formatID: "251", codec: "opus", container: "webm", contextID: "public-fixture")
        let fresh = ResolvedAudioStream(url: URL(string: "https://cache.test/fresh")!,
            requestHeaders: ["User-Agent": "second"], formatID: "251", codec: "opus", container: "webm", contextID: "public-fixture")
        let destination = MediaFileCache.file(videoId: "cached", quality: "bestaudio", ext: "webm", in: root)
        let resource = try SharedStreamResource(stream: source, destination: destination,
            session: URLSession(configuration: CacheMediaStub.makeConfig()), renewStream: { fresh })
        _ = try await resource.finish()
        await resource.cancel()
        #expect(try Data(contentsOf: destination) == payload)
        #expect(requests.values.map { $0.value(forHTTPHeaderField: "User-Agent") } == ["first", "second"])
    }

    @Test("Closed publication gate and account/HLS contexts cannot publish a public media entry")
    func publicationAndContext() async throws {
        CacheMediaStub.reset()
        defer { CacheMediaStub.reset() }
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let gate = MediaCachePublicationGate()
        CacheMediaStub().respond(forHostContaining: "cache.test") { _ in
            gate.close()
            return StubResponse(statusCode: 206, body: Data(repeating: 1, count: 8192),
                headers: ["Content-Range": "bytes 0-8191/8192"])
        }
        let stream = ResolvedAudioStream(url: URL(string: "https://cache.test/audio")!, container: "webm")
        let destination = MediaFileCache.file(videoId: "cached", quality: "bestaudio", ext: "webm", in: root)
        let resource = try SharedStreamResource(stream: stream, destination: destination,
            session: URLSession(configuration: CacheMediaStub.makeConfig()), publicationGate: gate)
        do { _ = try await resource.finish(); Issue.record("Closed gate published") } catch {}
        await resource.cancel()
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(MediaFileCache.cacheExtension(for: ResolvedAudioStream(url: stream.url,
            container: "webm", contextID: "account-private")) == nil)
        #expect(MediaFileCache.cacheExtension(for: ResolvedAudioStream(url: stream.url,
            container: "m4a", protocolName: "m3u8_native")) == nil)
        #expect(MediaFileCache.cacheExtension(for: ResolvedAudioStream(url: stream.url,
            requestHeaders: ["Cookie": "secret"], container: "webm")) == nil)
    }

    @Test("Idle opt-in precache preserves typed headers/extension and skips account cache")
    func typedIdlePrecache() async throws {
        CacheMediaStub.reset()
        defer { CacheMediaStub.reset() }
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let domain = "com.muses.tests.typed-cache.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: PrefKey.streamPrecacheEnabled)
        let requests = CacheRequestRecorder()
        CacheMediaStub().respond(forHostContaining: "cache.test") { request in
            requests.append(request)
            return StubResponse(statusCode: 206, body: Data(repeating: 8, count: 8192),
                headers: ["Content-Range": "bytes 0-8191/8192", "Content-Type": "audio/webm"])
        }
        let provider = CacheFixtureProvider()
        provider.stream = ResolvedAudioStream(url: URL(string: "https://cache.test/audio")!,
            requestHeaders: ["User-Agent": "idle-agent"], container: "webm", contextID: "public-idle")
        let service = StreamPrecacheService(resolution: provider, defaults: defaults, candidates: { _ in [track()] },
            isBusy: { false }, session: URLSession(configuration: CacheMediaStub.makeConfig()), directory: root)
        service.configure()
        await service.awaitWorkForTests()
        #expect(service.completedCount == 1)
        #expect(MediaFileCache.existing(videoId: "cached", quality: "bestaudio", in: root)?.pathExtension == "webm")
        #expect(requests.values.first?.value(forHTTPHeaderField: "User-Agent") == "idle-agent")
        provider.stream = ResolvedAudioStream(url: provider.stream.url, container: "webm", contextID: "account-private")
        let account = StreamPrecacheService(resolution: provider, defaults: defaults, candidates: { _ in [track("account")] },
            isBusy: { false }, session: URLSession(configuration: CacheMediaStub.makeConfig()), directory: root)
        account.configure()
        await account.awaitWorkForTests()
        #expect(account.completedCount == 0)
        #expect(requests.values.count == 1)
    }


    @Test("Starting playback while a paused download renews cannot publish a late result")
    func playDuringCacheRenewal() async throws {
        CacheMediaStub.reset()
        defer { CacheMediaStub.reset() }
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let requests = CacheRequestRecorder()
        CacheMediaStub().respond(forHostContaining: "cache.test") { request in
            requests.append(request)
            return StubResponse(statusCode: 403, body: Data())
        }
        let provider = CacheFixtureProvider()
        provider.suspendAfterCall = 2
        provider.stream = ResolvedAudioStream(url: URL(string: "https://cache.test/expired")!, container: "webm")
        let client = CacheFixtureClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root,
            cacheSession: URLSession(configuration: CacheMediaStub.makeConfig()), cacheDelay: .zero)
        try await engine.load(track())
        while provider.pending == nil { await Task.yield() }
        engine.play()
        provider.resume()
        await Task.yield()
        #expect(engine.state.isPlaying)
        #expect(requests.values.count == 1)
        #expect(MediaFileCache.existing(videoId: "cached", quality: "bestaudio", in: root) == nil)
    }

    @Test("Foreground playback retires an idle pre-download even if resolution ignores cancellation")
    func idleResolutionCancellation() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let domain = "com.muses.tests.idle-cancel.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: PrefKey.streamPrecacheEnabled)
        let provider = CacheFixtureProvider()
        provider.suspendAfterCall = 1
        provider.stream = ResolvedAudioStream(url: URL(string: "https://cache.test/audio")!, container: "webm")
        let service = StreamPrecacheService(resolution: provider, defaults: defaults, candidates: { _ in [track()] },
            isBusy: { false }, directory: root)
        service.configure()
        while provider.pending == nil { await Task.yield() }
        service.pauseForPlayback()
        provider.resume()
        await Task.yield()
        #expect(service.completedCount == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }


    @Test("A recovered paused stream repairs its media path while quarantined bytes remain recoverable")
    func healthyRepairAfterQuarantine() async throws {
        CacheMediaStub.reset()
        defer { CacheMediaStub.reset() }
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try file(root)
        let healthy = Data(repeating: 9, count: 8192)
        CacheMediaStub().respond(forHostContaining: "cache.test") { _ in
            StubResponse(statusCode: 206, body: healthy,
                headers: ["Content-Range": "bytes 0-8191/8192", "Content-Type": "audio/webm"])
        }
        let provider = CacheFixtureProvider()
        provider.stream = ResolvedAudioStream(url: URL(string: "https://cache.test/healthy")!, container: "webm")
        let client = CacheFixtureClient()
        client.rejectFileLoads = true
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root,
            cacheSession: URLSession(configuration: CacheMediaStub.makeConfig()), cacheDelay: .zero)
        try await engine.load(track())
        client.rejectFileLoads = false
        await engine.awaitCacheWorkForTests()
        #expect(try Data(contentsOf: original) == healthy)
        let retained = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "quarantine" }
        #expect(retained.count == 1)
        if let rejected = retained.first {
            #expect(rejected.lastPathComponent.hasPrefix("."))
            #expect(try Data(contentsOf: rejected) == Data(repeating: 42, count: 8192))
        }
        try await engine.load(track())
        #expect(client.streams.last?.url == original)
        #expect(provider.qualities == ["bestaudio"])
    }

    @Test("An identity replaced after native load is never quarantined or overwritten by the old failure")
    func replacementIdentityPreserved() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try file(root)
        let identity = try #require(MediaFileCache.completedEntry(videoID: "cached", quality: "bestaudio", in: root))
        let provider = CacheFixtureProvider()
        let client = CacheFixtureClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root)
        try await engine.load(track())
        let replacement = Data(repeating: 5, count: 9000)
        try replacement.write(to: original, options: .atomic)
        #expect(MediaFileCache.quarantine(identity, in: root) == nil)
        client.send(.failed(MpvFailure(stage: .decode, code: -17)))
        while client.streams.count < 2 { await Task.yield() }
        #expect(try Data(contentsOf: original) == replacement)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == [original.lastPathComponent])
        try await engine.load(track())
        #expect(client.streams.last?.url == original)
    }

    @Test("Device and timeout failures preserve completed bytes without quarantine or remote fallback")
    func nonMediaFailuresKeepCache() async throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try file(root)
        let provider = CacheFixtureProvider()
        let client = CacheFixtureClient()
        let engine = MpvStreamEngine(provider: provider, clientFactory: { client }, cacheDirectory: root)
        for code in [Int32(-14), Int32(-15), Int32(-1013)] {
            try await engine.load(track())
            let loadedCount = client.streams.count
            client.send(.failed(MpvFailure(stage: code == -1013 ? .load : .decode, code: code)))
            #expect(engine.state.error != nil)
            #expect(provider.qualities.isEmpty)
            #expect(provider.invalidations.isEmpty)
            #expect(client.streams.count == loadedCount)
            #expect(try Data(contentsOf: original) == Data(repeating: 42, count: 8192))
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == [original.lastPathComponent])
        }
    }

}

@MainActor
private final class CacheFixtureProvider: ResolvedStreamProvider {
    struct Invalidation { let video: String; let quality: String }
    var stream = ResolvedAudioStream(url: URL(string: "https://cache.test/audio")!)
    var qualities: [String] = []
    var invalidations: [Invalidation] = []
    var freshResolutions = 0
    var suspendAfterCall: Int?
    var pending: CheckedContinuation<ResolvedAudioStream, Error>?
    func resume() { pending?.resume(returning: stream); pending = nil }
    private var cached: [String: ResolvedAudioStream] = [:]
    func resolveStream(videoID: String, quality: String) async throws -> ResolvedAudioStream {
        qualities.append(quality)
        if let suspendAfterCall, qualities.count >= suspendAfterCall {
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        let key = videoID + quality
        if let existing = cached[key] { return existing }
        freshResolutions += 1
        cached[key] = stream
        return stream
    }
    func invalidateStream(videoID: String, quality: String) {
        invalidations.append(Invalidation(video: videoID, quality: quality))
        cached.removeValue(forKey: videoID + quality)
    }
}

@MainActor
private final class CacheFixtureClient: MpvClient {
    var onEvent: (@MainActor @Sendable (UInt64, MpvEvent) -> Void)?
    var generation: UInt64 = 0
    var streams: [ResolvedAudioStream] = []
    var rejectFileLoads = false
    func load(_ stream: ResolvedAudioStream, generation: UInt64) async throws {
        self.generation = generation
        streams.append(stream)
        if rejectFileLoads && stream.url.isFileURL { throw MpvFailure(stage: .load, code: -13) }
        send(.loaded)
    }
    func stop() {}
    func set(_ property: String, _ value: String, generation: UInt64) {}
    func seek(to seconds: Double, generation: UInt64) {}
    func send(_ event: MpvEvent, generation: UInt64? = nil) { onEvent?(generation ?? self.generation, event) }
}

private final class CacheRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    func append(_ request: URLRequest) { lock.lock(); requests.append(request); lock.unlock() }
    var values: [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
}
private final class CacheMediaStub: StubURLProtocolBase, @unchecked Sendable {
    nonisolated(unsafe) private static var storedRules: [StubRule] = []
    private static let storedLock = NSLock()
    override class var rules: [StubRule] { get { storedRules } set { storedRules = newValue } }
    override class var lock: NSLock { storedLock }
}
