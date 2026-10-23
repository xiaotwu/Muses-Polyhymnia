import Foundation
import Testing
@testable import Muses

/// Production facade/engine/coordinator/bridge/runner integration with local
/// extractor processes and a no-output client. No media request or native audio.
@MainActor
@Suite("Queued prepared Next priority", .serialized)
struct QueuedPreparedNextPriorityTests {
    @Test("Next promotes the same preparation before background work finishes", arguments: [false, true])
    func nextPromotesSamePreparation(beforeCoordinatorRegistration: Bool) async throws {
        let f = try QueuedNextFixture(gateRegistration: beforeCoordinatorRegistration)
        let blockers = ["one", "two"].map { label in
            Task { try await f.runner.run(executablePath: f.binary.path, args: ["hold", label], timeout: 10) }
        }
        do {
            try await f.waitFor {
                let active = await f.runner.inFlightCount
                return active == 2 && f.exists("one.started") && f.exists("two.started")
            }
            f.playback.playTrack(f.first, context: [f.first, f.second], from: .search)
            try await f.waitFor { f.engine.state.isPlaying && f.engine.state.track?.id == f.first.id }
            if beforeCoordinatorRegistration {
                try await f.waitFor { f.gate.pending != nil }
                #expect(await f.runner.waitingCount == 0)
            } else { try await f.waitFor { await f.runner.waitingCount == 1 } }
            f.playback.next()
            try await f.waitFor { f.engine.state.track?.id == f.second.id }
            f.gate.open()
            try await f.waitFor { f.engine.state.isPlaying && f.engine.state.track?.id == f.second.id }
            #expect(!f.exists("one.finished") && !f.exists("two.finished"))
            #expect(f.starts(f.second.youTubeId) == 1)
            #expect(f.client.loadedVideos == [f.first.youTubeId, f.second.youTubeId])
            #expect(await f.runner.waitingCount == 0)
            try f.releaseBackground()
            for blocker in blockers { _ = try await blocker.value }
            try await f.waitFor { await f.runner.inFlightCount == 0 }
            await f.close(blockers: blockers)
        } catch {
            await f.close(blockers: blockers)
            throw error
        }
    }
}

@MainActor
private final class QueuedNextFixture {
    let runner = YTDlpRunner(maxConcurrent: 2)
    let client = QueuedNextClient()
    let first = QueuedNextFixture.track("first000001")
    let second = QueuedNextFixture.track("second00001")
    let directory: URL
    let binary: URL
    let gate: QueuedNextRegistrationGate
    let engine: MpvStreamEngine
    let playback: PlaybackService
    let defaults: UserDefaults
    let domain = "com.muses.tests.queued-priority.\(UUID().uuidString)"

    init(gateRegistration: Bool) throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "queued-next-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        binary = directory.appending(path: "extractor")
        let quoted = "'" + directory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        try """
        #!/bin/sh
        root=\(quoted)
        case "$1" in
          hold)
            printf started > "$root/$2.started"
            while [ ! -e "$root/release" ]; do /bin/sleep 0.005; done
            printf finished > "$root/$2.finished"
            printf released
            ;;
          *)
            for argument do video="$argument"; done
            video="${video##*/}"
            printf 'started\\n' >> "$root/$video.started"
            printf '{"id":"%s","url":"https://fixture.invalid/%s","format_id":"251","acodec":"opus","vcodec":"none","ext":"webm"}' "$video" "$video"
            ;;
        esac
        """.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        let bridge = YTDlpBridge(binaryPath: binary.path, searchCache: nil, runner: runner,
                                 streamAccessPolicy: .publicAudio)
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache())
        gate = QueuedNextRegistrationGate(resolver: resolver, videoID: gateRegistration ? second.youTubeId : nil)
        let client = client
        engine = MpvStreamEngine(provider: gate, clientFactory: { client }, qualityProvider: { "bestaudio" },
            readinessTimeoutDuration: .seconds(5), cacheDirectory: directory.appending(path: "media"), cacheDelay: .seconds(60))
        defaults = try #require(UserDefaults(suiteName: domain))
        defaults.set(0.0, forKey: PrefKey.volume)
        playback = PlaybackService(engine: engine, queue: QueueService(), volumeDefaults: defaults)
    }

    func waitFor(_ condition: () async -> Bool) async throws {
        let end = ContinuousClock.now.advanced(by: .seconds(3))
        while !(await condition()) {
            guard ContinuousClock.now < end else { throw QueuedNextTimeout() }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
    func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: directory.appending(path: name).path) }
    func starts(_ videoID: String) -> Int {
        (try? String(contentsOf: directory.appending(path: videoID + ".started"), encoding: .utf8).split(separator: "\n").count) ?? 0
    }
    func releaseBackground() throws { try Data().write(to: directory.appending(path: "release")) }
    func close(blockers: [Task<(stdout: String, stderr: String), Error>]) async {
        try? releaseBackground()
        blockers.forEach { $0.cancel() }
        for blocker in blockers { _ = try? await blocker.value }
        gate.open()
        playback.pause()
        engine.invalidatePreparedStream()
        defaults.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: directory)
    }
    private static func track(_ video: String) -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: video, artist: "Fixture", albumTitle: nil,
            durationSeconds: 120, youTubeId: video, artworkUrl: nil,
            sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
    }
}

private struct QueuedNextTimeout: Error {}

@MainActor
private final class QueuedNextRegistrationGate: ResolvedStreamProvider {
    let resolver: StreamResolutionCoordinator
    let videoID: String?
    var pending: CheckedContinuation<Void, Never>?
    var streamContextID: String? { resolver.streamContextID }
    init(resolver: StreamResolutionCoordinator, videoID: String?) {
        self.resolver = resolver; self.videoID = videoID
    }
    func resolveStream(videoID: String, quality: String) async throws -> ResolvedAudioStream {
        if videoID == self.videoID { await withCheckedContinuation { pending = $0 } }
        return try await resolver.resolveStream(videoID: videoID, quality: quality)
    }
    func open() { pending?.resume(); pending = nil }
    func invalidateStream(videoID: String, quality: String) { resolver.invalidateStream(videoID: videoID, quality: quality) }
}

@MainActor
private final class QueuedNextClient: MpvClient {
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
