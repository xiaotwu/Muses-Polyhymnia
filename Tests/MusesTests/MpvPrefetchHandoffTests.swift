import Foundation
import Testing
@testable import Muses

/// Bounded behavioral tests only; no real subprocess, network or native output.
@MainActor
@Suite("Pending next resolution handoff", .serialized)
struct MpvPrefetchHandoffTests {
    private func waitFor(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw HandoffTimeout() }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private func start(_ f: HandoffFixture) async throws {
        f.playback.playTrack(f.first, context: [f.first, f.second, f.third], from: .search)
        try await waitFor { f.provider.pending.count == 1 && f.engine.state.isPlaying }
        #expect(f.provider.secondRequests.count == 1)
    }

    @Test("Manual Next adopts unfinished preparation instead of starting another extraction")
    func nextKeepsSameExtraction() async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        try await start(f)
        f.playback.next()
        try await waitFor { f.engine.state.track?.id == f.second.id }
        f.provider.finishPending()
        try await waitFor { f.engine.state.isPlaying && f.engine.state.track?.id == f.second.id }
        #expect(f.provider.secondRequests.count == 1)
        #expect(f.provider.cancelledSecond == 0)
        #expect(f.provider.pending.isEmpty)
        #expect(f.client.loadedVideos == ["first", "second"])
    }

    @Test("Preparation explicitly canceled without a foreground owner terminates resolution")
    func explicitPreparationCancellation() async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        let preparation = Task { await f.engine.prepare(f.second) }
        defer { preparation.cancel() }
        try await waitFor { f.provider.pending.count == 1 }
        preparation.cancel()
        try await waitFor { f.provider.pending.isEmpty && f.provider.cancelledSecond == 1 }
    }

    @Test("Replacing a scheduled handoff before its load runs releases the unconsumed task")
    func abandonedScheduledHandoff() async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        try await start(f)
        // Both calls are synchronous on MainActor, so the canceled load cannot consume the lease.
        f.playback.next()
        f.playback.playTrack(f.third, context: [f.first, f.second, f.third], from: .search)
        try await waitFor { f.provider.pending.isEmpty && f.provider.cancelledSecond == 1 &&
            f.engine.state.track?.id == f.third.id && f.engine.state.isPlaying }
        #expect(!f.client.loadedVideos.contains("second"))
    }

    @Test("Replacing an active foreground handoff cancels its last resolution consumer")
    func cancelActiveHandoff() async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        try await start(f)
        f.playback.next()
        try await waitFor { f.engine.state.track?.id == f.second.id && f.engine.state.buffering }
        f.playback.playTrack(f.third, context: [f.first, f.second, f.third], from: .search)
        try await waitFor { f.provider.pending.isEmpty && f.provider.cancelledSecond >= 1 && f.engine.state.isPlaying }
        #expect(f.engine.state.track?.id == f.third.id)
        #expect(!f.client.loadedVideos.contains("second"))
    }

    @Test("Selecting another track cancels the old next preparation")
    func differentTrack() async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        try await start(f)
        f.playback.playTrack(f.third, context: [f.first, f.second, f.third], from: .search)
        try await waitFor { f.provider.pending.isEmpty && f.provider.cancelledSecond == 1 }
        #expect(!f.client.loadedVideos.contains("second"))
    }

    @Test("Changed quality or session cancels the old preparation and resolves the current key", arguments: [false, true])
    func changedIdentity(sessionChanged: Bool) async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        try await start(f)
        if sessionChanged { f.provider.context = "public-two" }
        else { f.quality.value = "128k" }
        f.playback.next()
        try await waitFor { f.provider.cancelledSecond == 1 && f.provider.secondRequests.count == 2 && f.provider.pending.count == 1 }
        f.provider.finishPending()
        try await waitFor { f.engine.state.isPlaying && f.engine.state.track?.id == f.second.id }
        #expect(f.provider.secondRequests.last?.quality == f.quality.value)
        #expect(f.engine.resolvedStream?.contextID == f.provider.context)
        #expect(f.provider.pending.isEmpty)
    }

    @Test("An expired transferred result never opens a second native file")
    func expiredResult() async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        try await start(f)
        f.playback.next()
        try await waitFor { f.engine.state.track?.id == f.second.id }
        f.provider.finishPending(expired: true)
        try await waitFor { f.engine.state.error != nil && !f.engine.state.buffering }
        #expect(f.provider.pending.isEmpty)
        #expect(f.provider.secondRequests.count == 1)
        #expect(!f.client.loadedVideos.contains("second"))
    }

    @Test("Session change while a foreground handoff is pending rejects its late result")
    func sessionChangeDuringHandoff() async throws {
        let f = try HandoffFixture()
        defer { f.close() }
        try await start(f)
        f.playback.next()
        try await waitFor { f.engine.state.track?.id == f.second.id }
        f.provider.context = "public-two"
        f.provider.finishPending()
        try await waitFor { f.provider.pending.isEmpty && !f.engine.state.buffering }
        #expect(!f.client.loadedVideos.contains("second"))
    }
}

private struct HandoffTimeout: Error {}
@MainActor private final class HandoffQuality { var value = "bestaudio" }

@MainActor
private final class HandoffFixture {
    let provider = HandoffProvider()
    let client = HandoffClient()
    let quality = HandoffQuality()
    let engine: MpvStreamEngine
    let playback: PlaybackService
    let first: TrackSnapshot
    let second: TrackSnapshot
    let third: TrackSnapshot
    private let directory: URL
    private let defaults: UserDefaults
    private let domain: String

    init() throws {
        func track(_ video: String) -> TrackSnapshot {
            TrackSnapshot(id: UUID(), title: video, artist: "Fixture", albumTitle: nil,
                durationSeconds: 120, youTubeId: video, artworkUrl: nil,
                sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
        }
        first = track("first"); second = track("second"); third = track("third")
        domain = "com.muses.tests.handoff.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: domain))
        directory = MusesDataPaths.root(bundleID: Bundle.main.bundleIdentifier)
            .appending(path: "tmp/handoff-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let client = client, quality = quality
        engine = MpvStreamEngine(provider: provider, clientFactory: { client }, qualityProvider: { quality.value },
            readinessTimeoutDuration: .seconds(2), cacheDirectory: directory, cacheDelay: .seconds(60))
        playback = PlaybackService(engine: engine, queue: QueueService(), volumeDefaults: defaults)
    }
    func close() {
        playback.pause()
        provider.cancelAll()
        defaults.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class HandoffProvider: ResolvedStreamProvider {
    struct Request { let video: String; let quality: String; let context: String }
    struct Pending { let request: Request; let continuation: CheckedContinuation<ResolvedAudioStream, Error> }
    private var stopped = false
    var context = "public-one"
    var streamContextID: String? { context }
    var requests: [Request] = []
    var pending: [UUID: Pending] = [:]
    var cancelledSecond = 0
    var secondRequests: [Request] { requests.filter { $0.video == "second" } }

    func resolveStream(videoID: String, quality: String) async throws -> ResolvedAudioStream {
        try Task.checkCancellation()
        guard !stopped else { throw CancellationError() }
        let request = Request(video: videoID, quality: quality, context: context)
        requests.append(request)
        guard videoID == "second" else { return stream(request) }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending[id] = Pending(request: request, continuation: $0) }
        } onCancel: {
            Task { @MainActor in
                if let old = self.pending.removeValue(forKey: id) {
                    self.cancelledSecond += 1
                    old.continuation.resume(throwing: CancellationError())
                }
            }
        }
    }
    private func stream(_ request: Request, expired: Bool = false) -> ResolvedAudioStream {
        ResolvedAudioStream(url: URL(string: "https://example.test/\(request.video)")!, codec: "opus",
            expiresAt: expired ? .distantPast : nil, contextID: request.context)
    }
    func finishPending(expired: Bool = false) {
        let old = pending; pending.removeAll()
        for item in old.values { item.continuation.resume(returning: stream(item.request, expired: expired)) }
    }
    func cancelAll() {
        stopped = true
        let old = pending; pending.removeAll()
        for item in old.values { item.continuation.resume(throwing: CancellationError()) }
    }
    func invalidateStream(videoID: String, quality: String) {}
}

@MainActor
private final class HandoffClient: MpvClient {
    var onEvent: (@MainActor @Sendable (UInt64, MpvEvent) -> Void)?
    var loadedVideos: [String] = []
    func load(_ stream: ResolvedAudioStream, generation: UInt64) async throws {
        loadedVideos.append(stream.url.lastPathComponent)
        onEvent?(generation, .loaded)
    }
    func stop() {}
    func set(_ property: String, _ value: String, generation: UInt64) {}
    func seek(to seconds: Double, generation: UInt64) {}
}
