import Foundation
import os

/// One existing task, with one cancellation owner at a time. The lock lets a
/// canceled preparation distinguish synchronous transfer from abandonment.
private final class MpvPendingResolution: @unchecked Sendable {
    let id = UUID()
    let trackID: UUID
    let videoID: String
    let quality: String
    let context: String?
    let prepared: Bool
    let task: Task<ResolvedAudioStream, Error>
    private let lock = NSLock()
    private var transferred = false
    private var cancelled = false

    init(track: TrackSnapshot, quality: String, context: String?, prepared: Bool,
         task: Task<ResolvedAudioStream, Error>) {
        trackID = track.id; videoID = track.youTubeId
        self.quality = quality; self.context = context
        self.prepared = prepared; self.task = task
    }
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !transferred, !cancelled, !task.isCancelled else { return false }
        transferred = true
        return true
    }
    func cancelSpeculation() {
        lock.lock()
        let shouldCancel = !transferred
        if shouldCancel { cancelled = true }
        lock.unlock()
        if shouldCancel { task.cancel() }
    }
    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
        task.cancel()
    }
}


/// One native audio authority. Resolution stays replaceable and queue ownership stays in PlaybackService.
@MainActor
final class MpvStreamEngine: PlayerEngine {
    let state = PlayerState()
    var onCompletion: (@MainActor () -> Void)?
    private(set) var resolvedStream: ResolvedAudioStream?
    private(set) var lastFailure: MpvFailure?
    /// libmpv's client API does not expose decoded PCM. Never synthesize spectrum frames.
    let supportsSpectrum = false
    private(set) var equalizerAvailable = false

    private let nativeLog = AppLog.for("NativeAudio")
    private var nativeStageStart = ProcessInfo.processInfo.systemUptime
    private var recordedNativeStages: Set<NativeDiagnosticStage> = []
    private enum NativeDiagnosticStage: Int, Hashable {
        case loadStarted = 1, typedResolved, cacheSelected, fileLoaded, playbackRestart, positivePosition, failure, preparationHandoff
    }
    private let provider: any ResolvedStreamProvider
    private let client: any MpvClient
    private let readinessTimeoutDuration: Duration
    private let cacheDirectory: URL
    private let cacheSession: URLSession
    private let cacheDelay: Duration
    private var cacheWork: Task<Void, Never>?
    private var cacheResource: SharedStreamResource?
    private var cacheGate: MediaCachePublicationGate?
    private var cacheWorkID = UUID()
    private var loadOperationID = UUID()
    private var currentQualityKey = "bestaudio"
    private var usingCachedFile = false
    private var cachedEntry: MediaFileCache.CompletedEntry?
    private var cacheRetirementGate: MediaCachePublicationGate?
    private var cacheFallbackUsed = false
    private let qualityProvider: @MainActor () -> String
    private var generation: UInt64 = 0
    private var playbackRequested = false
    private var loaded = false
    private var controlsApplied = false
    private var loadTask: Task<Void, Never>?
    private var readinessTimeout: Task<Void, Never>?
    private var readiness: (token: UInt64, continuation: CheckedContinuation<Void, Error>)?
    private var completed = false
    private var reachedEnd = false
    private var cachePaused = false
    private var seekTarget: Double?
    private var volume: Float = 0.8
    private var rate: Float = 1
    private var bands: [EQBand] = []
    private var pendingPrefetch: MpvPendingResolution?
    private var foregroundHandoff: MpvPendingResolution?
    private var activeResolution: MpvPendingResolution?
    private var prefetchID = UUID()
    private var prefetched: Prefetched?

    private struct Prefetched {
        let track: TrackSnapshot
        let quality: String
        let stream: ResolvedAudioStream
        let prepared: Bool
    }

    init(provider: any ResolvedStreamProvider,
         clientFactory: @MainActor () -> any MpvClient = { NativeMpvClient() },
         qualityProvider: @escaping @MainActor () -> String = {
             UserDefaults.standard.string(forKey: PrefKey.ytAudioQuality) ?? "bestaudio"
         }, readinessTimeoutDuration: Duration = .seconds(35),
         cacheDirectory: URL? = nil, cacheSession: URLSession? = nil,
         cacheDelay: Duration = .seconds(1)) {
        self.provider = provider
        self.client = clientFactory()
        self.qualityProvider = qualityProvider
        self.readinessTimeoutDuration = readinessTimeoutDuration
        self.cacheDirectory = cacheDirectory ?? MusesDataPaths.caches.appendingPathComponent("streams", isDirectory: true)
        self.cacheSession = MediaFileCache.ephemeralSession(copying: cacheSession)
        self.cacheDelay = cacheDelay
        client.onEvent = { [weak self] generation, event in self?.receive(event, generation: generation) }
    }

    func load(_ track: TrackSnapshot) async throws {
        let quality = qualityProvider()
        let ready = prefetched.flatMap {
            $0.track.youTubeId == track.youTubeId && $0.quality == quality && !$0.stream.isExpired() ? $0.stream : nil
        }
        let handoff = foregroundHandoff
        foregroundHandoff = nil
        let matching = handoff.flatMap { matches($0, track: track, quality: quality) ? $0 : nil }
        if matching == nil { handoff?.cancel() }
        let token = beginLoad(track, quality: quality)
        let operation = loadOperationID
        invalidatePreparedStream()
        activeResolution = matching
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                readiness = (token, continuation)
                if Task.isCancelled {
                    cancelLoad(token)
                    return
                }
                startReadinessTimeout(operation: operation)
                startLoadTask(track, quality: quality, ready: ready, token: token, allowCache: true,
                              pending: matching)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.loadOperationID == operation else { return }
                self.cancelLoad(self.generation)
            }
        }
    }

    deinit {
        pendingPrefetch?.cancel()
        foregroundHandoff?.cancel()
        activeResolution?.cancel()
        cacheWork?.cancel()
        cacheGate?.close()
        cacheRetirementGate?.close()
        cacheSession.invalidateAndCancel()
    }

    private func startReadinessTimeout(operation: UUID) {
        readinessTimeout?.cancel()
        let timeout = readinessTimeoutDuration
        readinessTimeout = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, self.loadOperationID == operation else { return }
            let failure = MpvFailure(stage: .load, code: -1013)
            if !self.retryCorruptCacheIfNeeded(failure) { self.fail(failure) }
        }
    }

    private func startLoadTask(_ track: TrackSnapshot, quality: String, ready: ResolvedAudioStream?,
                               token: UInt64, allowCache: Bool, pending: MpvPendingResolution? = nil,
                               quarantining rejected: MediaFileCache.CompletedEntry? = nil,
                               retirementGate: MediaCachePublicationGate? = nil) {
        let root = cacheDirectory
        loadTask = Task { [weak self, provider] in
            do {
                guard !track.youTubeId.isEmpty else { throw PlayerError.sourceUnavailable }
                if let rejected, let retirementGate {
                    try await Task.detached(priority: .utility) {
                        try retirementGate.whileOpen { _ = MediaFileCache.quarantine(rejected, in: root) }
                    }.value
                }
                let cached: MediaFileCache.CompletedEntry?
                if allowCache {
                    cached = await Task.detached(priority: .utility) {
                        MediaFileCache.completedEntry(videoID: track.youTubeId, quality: quality, in: root)
                    }.value
                } else { cached = nil }
                try Task.checkCancellation()
                let stream: ResolvedAudioStream
                if let cached {
                    pending?.cancel()
                    // File URLs originate solely from the exact trusted cache lookup, never a provider.
                    stream = ResolvedAudioStream(url: cached.url, contextID: "public-cache")
                } else if let ready { stream = ready }
                else if let pending {
                    guard pending.context == provider.streamContextID else { throw CancellationError() }
                    stream = try await pending.task.value
                    try Task.checkCancellation()
                    guard pending.context == provider.streamContextID,
                          stream.contextID == pending.context else { throw CancellationError() }
                } else { stream = try await provider.resolveStream(videoID: track.youTubeId, quality: quality) }
                try Task.checkCancellation()
                guard let self, self.isCurrent(token, track.id) else { return }
                self.activeResolution = nil
                if let cached {
                    self.usingCachedFile = true
                    self.cachedEntry = cached
                    guard MediaFileCache.matches(cached, in: root) else {
                        throw MpvFailure(stage: .load, code: -1014)
                    }
                } else { try self.validate(stream) }
                self.resolvedStream = stream
                self.recordNativeStage(cached == nil ? .typedResolved : .cacheSelected)
                self.updateQuality()
                try await self.client.load(stream, generation: token)
                try Task.checkCancellation()
                guard self.isCurrent(token, track.id) else { return }
                self.applyControls()
                self.controlsApplied = true
                self.finishReadinessIfPossible()
            } catch {
                guard let self, self.isCurrent(token, track.id) else { return }
                if error is CancellationError || Task.isCancelled { self.cancelLoad(token) }
                else if !self.retryCorruptCacheIfNeeded(error) { self.fail(error) }
            }
        }
    }

    /// One remote attempt for a corrupt completed cache. Preserve intent/position and reject all old native events.
    private func retryCorruptCacheIfNeeded(_ error: Error) -> Bool {
        guard usingCachedFile, !cacheFallbackUsed, let track = state.track,
              let failure = error as? MpvFailure, [.load, .decode].contains(failure.stage),
              [-13, -16, -17, -18].contains(failure.code), let rejected = cachedEntry else { return false }
        recordNativeStage(.failure, code: failure.code)
        let retirement = MediaCachePublicationGate()
        cacheRetirementGate = retirement
        cacheFallbackUsed = true
        usingCachedFile = false
        loadTask?.cancel()
        generation &+= 1
        beginNativeDiagnostics()
        client.stop()
        loaded = false
        controlsApplied = false
        reachedEnd = false
        cachePaused = false
        resolvedStream = nil
        state.quality = nil
        state.buffering = true
        state.isPlaying = false
        if seekTarget == nil && state.position > 0 { seekTarget = state.position }
        startReadinessTimeout(operation: loadOperationID)
        startLoadTask(track, quality: currentQualityKey, ready: nil, token: generation, allowCache: false,
                      quarantining: rejected, retirementGate: retirement)
        return true
    }

    private func settleReadiness(_ result: Result<Void, Error>) {
        guard let readiness else { return }
        self.readiness = nil
        readinessTimeout?.cancel()
        readinessTimeout = nil
        readiness.continuation.resume(with: result)
    }

    private func finishReadinessIfPossible() {
        if loaded && controlsApplied {
            readinessTimeout?.cancel()
            readinessTimeout = nil
            settleReadiness(.success(()))
            schedulePausedCache()
        }
    }

    private func beginLoad(_ track: TrackSnapshot, quality: String) -> UInt64 {
        activeResolution?.cancel()
        activeResolution = nil
        cancelCacheWork()
        cacheRetirementGate?.close()
        cacheRetirementGate = nil
        cachedEntry = nil
        loadOperationID = UUID()
        currentQualityKey = quality
        usingCachedFile = false
        cacheFallbackUsed = false
        settleReadiness(.failure(CancellationError()))
        loadTask?.cancel()
        loadTask = nil
        generation &+= 1
        beginNativeDiagnostics()
        client.stop()
        playbackRequested = false
        loaded = false
        controlsApplied = false
        completed = false
        reachedEnd = false
        cachePaused = false
        seekTarget = nil
        resolvedStream = nil
        lastFailure = nil
        state.track = track
        state.position = 0
        state.duration = max(0, track.durationSeconds)
        state.isPlaying = false
        state.buffering = true
        state.bufferRatio = 0
        state.error = nil
        state.quality = nil
        state.audioProcessing = .streamOnly
        equalizerAvailable = false
        return generation
    }

    private func cancelLoad(_ token: UInt64) {
        guard generation == token else { return }
        activeResolution?.cancel()
        activeResolution = nil
        cacheRetirementGate?.close()
        cacheRetirementGate = nil
        cancelCacheWork()
        settleReadiness(.failure(CancellationError()))
        loadTask?.cancel()
        loadTask = nil
        generation &+= 1
        client.stop()
        playbackRequested = false
        loaded = false
        state.isPlaying = false
        state.buffering = false
        state.audioProcessing = .unavailable
        equalizerAvailable = false
    }

    private func isCurrent(_ token: UInt64, _ trackID: UUID) -> Bool {
        generation == token && state.track?.id == trackID
    }

    func play() {
        guard state.track != nil, state.error == nil else { return }
        cancelCacheWork()
        playbackRequested = true
        if reachedEnd { finishOnce(); return }
        client.set("pause", "no", generation: generation)
        state.isPlaying = loaded && !cachePaused && seekTarget == nil
    }

    func pause() {
        playbackRequested = false
        client.set("pause", "yes", generation: generation)
        state.isPlaying = false
        schedulePausedCache()
    }

    func toggle() { playbackRequested ? pause() : play() }

    func seek(to time: Double) {
        guard time.isFinite, state.track != nil, state.error == nil else { return }
        cancelCacheWork()
        let target = max(0, state.duration > 0 ? min(time, state.duration) : time)
        seekTarget = target
        state.position = target
        state.buffering = true
        state.isPlaying = false
        reachedEnd = false
        if loaded { client.seek(to: target, generation: generation) }
    }

    func setVolume(_ v: Float) {
        guard v.isFinite else { return }
        volume = min(1, max(0, v))
        client.set("volume", String(volume * 100), generation: generation)
    }

    func setPlaybackRate(_ rate: Float) {
        guard rate.isFinite else { return }
        self.rate = min(4, max(0.25, rate))
        client.set("speed", String(self.rate), generation: generation)
    }

    func setEQ(_ bands: [EQBand]) {
        self.bands = Array(bands.prefix(32)).filter {
            $0.frequency.isFinite && $0.frequency > 0 && $0.frequency <= 24000 &&
            $0.gain.isFinite && $0.q.isFinite && $0.q > 0
        }
        equalizerAvailable = false
        state.audioProcessing = .streamOnly
        client.set("af", Self.equalizerFilter(self.bands), generation: generation)
    }

    /// FFmpeg equalizer width_type=o preserves the app's persisted bandwidth-in-octaves meaning.
    static func equalizerFilter(_ bands: [EQBand]) -> String {
        let filters = bands.filter { $0.gain != 0 }.map {
            "equalizer=f=\($0.frequency):t=o:w=\(min(8, max(0.01, $0.q))):g=\(min(24, max(-24, $0.gain)))"
        }
        return filters.isEmpty ? "" : "lavfi=[" + filters.joined(separator: ",") + "]"
    }

    func installSpectrumTap(_ handler: @escaping (SpectrumFrame) -> Void) {
        // No PCM tap exists in the client API. Deliberately publish no synthetic samples.
    }
    func removeSpectrumTap() {}

    /// Only one speculative resolution is owned by this engine. Focus warmup never replaces a prepared next slot.
    func prewarmSelection(_ track: TrackSnapshot) async {
        guard prefetched?.prepared != true, pendingPrefetch?.prepared != true else { return }
        await prefetch(track, prepared: false)
    }
    func prewarmSelections(_ tracks: [TrackSnapshot]) async {
        if let track = tracks.first { await prewarmSelection(track) }
    }
    func prepare(_ track: TrackSnapshot) async { await prefetch(track, prepared: true) }

    private func prefetch(_ track: TrackSnapshot, prepared: Bool) async {
        guard !track.youTubeId.isEmpty else { return }
        let quality = qualityProvider()
        invalidatePreparedStream()
        let token = prefetchID
        let task = Task { try await provider.resolveStream(videoID: track.youTubeId, quality: quality) }
        let pending = MpvPendingResolution(track: track, quality: quality, context: provider.streamContextID,
                                        prepared: prepared, task: task)
        pendingPrefetch = pending
        defer { if prefetchID == token { pendingPrefetch = nil } }
        do {
            let stream = try await withTaskCancellationHandler { try await task.value } onCancel: { pending.cancelSpeculation() }
            guard !Task.isCancelled, !task.isCancelled, prefetchID == token, quality == qualityProvider(),
                  !stream.isExpired() else { return }
            try validate(stream)
            prefetched = Prefetched(track: track, quality: quality, stream: stream, prepared: prepared)
        } catch {
            // The original owner remains responsible unless the facade claimed it.
        }
    }

    private func matches(_ pending: MpvPendingResolution, track: TrackSnapshot, quality: String) -> Bool {
        pending.prepared && pending.trackID == track.id && pending.videoID == track.youTubeId &&
            pending.quality == quality && pending.context != nil && pending.context == provider.streamContextID &&
            !pending.task.isCancelled
    }

    func handoffPreparedResolution(to track: TrackSnapshot) -> (@MainActor () -> Void)? {
        foregroundHandoff?.cancel()
        foregroundHandoff = nil
        guard let pending = pendingPrefetch,
              matches(pending, track: track, quality: qualityProvider()), pending.claim() else { return nil }
        recordNativeStage(.preparationHandoff)
        // The facade owns this lease until load consumes it; the old preparation
        // can now cancel without discarding the same underlying extraction.
        pendingPrefetch = nil
        prefetchID = UUID()
        foregroundHandoff = pending
        return { [weak self] in
            guard self?.foregroundHandoff?.id == pending.id else { return }
            self?.foregroundHandoff = nil
            pending.cancel()
        }
    }

    /// Call on resolver/account-context changes, in addition to foreground load's automatic invalidation.
    func invalidatePreparedStream() {
        cancelCacheWork()
        prefetchID = UUID()
        pendingPrefetch?.cancel()
        pendingPrefetch = nil
        foregroundHandoff?.cancel()
        foregroundHandoff = nil
        prefetched = nil
    }

    @discardableResult
    func playPrepared(expectedTrackID: UUID) -> Bool {
        // A resolved URL is not a loaded standby decoder. Let the facade perform its normal async load,
        // which consumes this bounded prefetch. Do not return a false claim of gapless playback.
        false
    }

    private func cancelCacheWork() {
        cacheWorkID = UUID()
        cacheGate?.close()
        cacheGate = nil
        cacheWork?.cancel()
        cacheWork = nil
        if let resource = cacheResource { Task { await resource.cancel() } }
        cacheResource = nil
    }

    /// Whole-media transfer is deferred until a settled pause; foreground playback never waits for it.
    private func schedulePausedCache() {
        guard loaded, controlsApplied, !playbackRequested, !usingCachedFile, !state.buffering, state.error == nil,
              cacheWork == nil, let track = state.track, let stream = resolvedStream,
              let ext = MediaFileCache.cacheExtension(for: stream),
              MediaFileCache.validKey(videoID: track.youTubeId, quality: currentQualityKey) else { return }
        let token = generation, identity = cacheWorkID, quality = currentQualityKey
        let gate = MediaCachePublicationGate()
        cacheGate = gate
        let root = cacheDirectory, session = cacheSession, delay = cacheDelay
        cacheWork = Task { [weak self] in
            defer {
                if let self, self.cacheWorkID == identity {
                    self.cacheWork = nil
                    self.cacheGate = nil
                    self.cacheResource = nil
                }
            }
            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
                guard let self, self.generation == token, !self.playbackRequested else { return }
                let existing = await Task.detached(priority: .utility) {
                    MediaFileCache.existing(videoId: track.youTubeId, quality: quality, in: root)
                }.value
                try Task.checkCancellation()
                guard existing == nil, self.generation == token, !self.playbackRequested,
                      quality == self.qualityProvider() else { return }
                let destination = MediaFileCache.file(videoId: track.youTubeId, quality: quality, ext: ext, in: root)
                let resource = try SharedStreamResource(stream: stream, destination: destination,
                    session: session, publicationGate: gate, renewStream: { [weak self] in
                        guard let self else { throw CancellationError() }
                        return try await self.renewPausedCache(videoID: track.youTubeId, quality: quality, token: token)
                    })
                self.cacheResource = resource
                defer { Task { await resource.cancel() } }
                _ = try await resource.finish { [weak self] in
                    await MainActor.run {
                        guard let self else { return false }
                        return self.generation == token && !self.playbackRequested &&
                            self.state.error == nil && quality == self.qualityProvider()
                    }
                }
            } catch {
                // Cache failure cannot change transport, queue/history, or a successfully resolved remote stream.
            }
        }
    }

    private func renewPausedCache(videoID: String, quality: String, token: UInt64) async throws -> ResolvedAudioStream {
        try Task.checkCancellation()
        guard generation == token, !playbackRequested, currentQualityKey == quality else { throw CancellationError() }
        provider.invalidateStream(videoID: videoID, quality: quality)
        let stream = try await provider.resolveStream(videoID: videoID, quality: quality)
        try Task.checkCancellation()
        guard generation == token, !playbackRequested, currentQualityKey == quality else { throw CancellationError() }
        return stream
    }

    func awaitCacheWorkForTests() async { await cacheWork?.value }

    private func applyControls() {
        client.set("volume", String(volume * 100), generation: generation)
        client.set("speed", String(rate), generation: generation)
        client.set("af", Self.equalizerFilter(bands), generation: generation)
        client.set("pause", playbackRequested ? "no" : "yes", generation: generation)
    }

    private func receive(_ event: MpvEvent, generation token: UInt64) {
        guard generation == token, state.track != nil, state.error == nil, !completed else { return }
        switch event {
        case .loaded:
            recordNativeStage(.fileLoaded)
            loaded = true
            if let seekTarget { client.seek(to: seekTarget, generation: generation) }
            client.set("pause", playbackRequested ? "no" : "yes", generation: generation)
            refreshTransport()
            finishReadinessIfPossible()
        case .restarted:
            recordNativeStage(.playbackRestart)
            refreshTransport()
        case .position(let position):
            guard position.isFinite, position >= 0 else { return }
            if position > 0 { recordNativeStage(.positivePosition) }
            // Ignore delayed pre-seek clocks; every newer seek replaces this target.
            if let target = seekTarget {
                guard abs(position - target) < 1.5 else { return }
                seekTarget = nil
            }
            state.position = position
            refreshTransport()
        case .duration(let duration):
            if duration.isFinite, duration > 0 { state.duration = duration }
        case .buffering(let buffering):
            cachePaused = buffering
            refreshTransport()
        case .bufferPercent(let percent):
            if percent.isFinite { state.bufferRatio = min(1, max(0, percent / 100)) }
        case .seeking(let seeking):
            if seeking { state.buffering = true; state.isPlaying = false }
            else { refreshTransport() }
        case .paused(let paused):
            // A delayed backend pause event must never overwrite newer user intent.
            if paused { state.isPlaying = false }
            else if !playbackRequested { client.set("pause", "yes", generation: generation) }
            else { refreshTransport() }
        case .codec(let codec): updateQuality(codec: codec)
        case .sampleRate(let sampleRate): updateQuality(sampleRate: sampleRate)
        case .ended:
            guard loaded else { return }
            reachedEnd = true
            state.isPlaying = false
            state.buffering = false
            if playbackRequested { finishOnce() }
        case .equalizerConfigured:
            equalizerAvailable = true
            state.audioProcessing = .eqOnly
        case .failed(let failure):
            recordNativeStage(.failure, code: failure.code)
            if retryCorruptCacheIfNeeded(failure) { return }
            lastFailure = failure
            if failure.stage == .control && failure.property == "af" {
                equalizerAvailable = false
                state.audioProcessing = .streamOnly
            } else {
                fail(failure)
            }
        }
    }

    private func refreshTransport() {
        state.buffering = !loaded || cachePaused || seekTarget != nil
        state.isPlaying = playbackRequested && loaded && !state.buffering && !reachedEnd
        if !state.buffering { schedulePausedCache() }
    }

    private func finishOnce() {
        guard !completed else { return }
        completed = true
        playbackRequested = false
        state.isPlaying = false
        state.buffering = false
        onCompletion?()
        schedulePausedCache()
    }

    private func updateQuality(codec: String? = nil, sampleRate: Int? = nil) {
        let codec = codec ?? state.quality?.codec ?? resolvedStream?.codec ?? "unknown"
        let sampleRate = sampleRate ?? state.quality?.sampleRate ?? resolvedStream?.sampleRate ?? 0
        state.quality = AudioQualityInfo(sampleRate: max(0, sampleRate), bitDepth: 0,
                                       codec: codec, isLossless: false,
                                       bitrateKbps: resolvedStream?.bitrateKbps,
                                       formatID: resolvedStream?.formatID)
    }

    private func fail(_ error: Error) {
        activeResolution?.cancel()
        activeResolution = nil
        readinessTimeout?.cancel()
        readinessTimeout = nil
        cancelCacheWork()
        if !usingCachedFile, let failure = error as? MpvFailure,
           [.load, .decode].contains(failure.stage), ![-14, -15].contains(failure.code), let track = state.track {
            provider.invalidateStream(videoID: track.youTubeId, quality: currentQualityKey)
            invalidatePreparedStream()
        }
        loadTask?.cancel()
        loadTask = nil
        if let failure = error as? MpvFailure {
            lastFailure = failure
            state.error = failure.stage == .decode && ![-14, -15].contains(failure.code)
                ? .decodingFailed("libmpv (\(failure.code))") : .engineStartFailed
        } else if let playerError = error as? PlayerError {
            state.error = playerError
        } else if let resolverError = error as? YTDlpBridge.YTDlpError {
            switch resolverError {
            case .timeout:
                lastFailure = MpvFailure(stage: .resolve, code: -1021)
                state.error = .networkError(tr("Stream resolution timed out", "音频流解析超时"))
            case .notFound:
                lastFailure = MpvFailure(stage: .resolve, code: -1020)
                state.error = .sourceUnavailable
            case .exitCode(let code, _):
                lastFailure = MpvFailure(stage: .resolve, code: Int32(clamping: code))
                state.error = .sourceUnavailable
            case .parseFailed:
                lastFailure = MpvFailure(stage: .resolve, code: -1022)
                state.error = .sourceUnavailable
            }
        } else {
            // Avoid displaying errors that may contain URLs or extractor credential context.
            state.error = .sourceUnavailable
        }
        recordNativeStage(.failure, code: lastFailure?.code ?? -1099)
        settleReadiness(.failure(state.error ?? PlayerError.sourceUnavailable))
        client.stop()
        loaded = false
        playbackRequested = false
        state.isPlaying = false
        state.buffering = false
        state.audioProcessing = .unavailable
        equalizerAvailable = false
    }

    private func beginNativeDiagnostics() {
        nativeStageStart = ProcessInfo.processInfo.systemUptime
        recordedNativeStages.removeAll(keepingCapacity: true)
        recordNativeStage(.loadStarted)
    }

    /// Fixed stage IDs and numeric API codes only; observations do not establish audible output.
    private func recordNativeStage(_ stage: NativeDiagnosticStage, code: Int32 = 0) {
        guard recordedNativeStages.insert(stage).inserted else { return }
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - nativeStageStart)
        nativeLog.info("generation=\(self.generation, privacy: .public) stage=\(stage.rawValue, privacy: .public) elapsed=\(elapsed, privacy: .public) code=\(code, privacy: .public)")
    }

    private func validate(_ stream: ResolvedAudioStream) throws {
        guard MediaFileCache.validRemoteStream(stream) else { throw PlayerError.sourceUnavailable }
    }
}
