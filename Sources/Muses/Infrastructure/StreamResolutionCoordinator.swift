import Foundation

/// Shares one cancellable extraction per media/quality/session identity.
@MainActor
final class StreamResolutionCoordinator: ResolvedStreamProvider {
    private struct Key: Hashable {
        let videoID: String
        let quality: String
        let context: String
    }
    private struct Request {
        let identity: UUID
        let task: Task<Void, Never>
        let priority: YTDlpQueuedPriority
        var consumers: [UUID: CheckedContinuation<ResolvedAudioStream, Error>]
    }
    private let bridge: any YTDlpBridgeProtocol
    private let cache: StreamURLCache
    private let contextID: @MainActor () -> String
    private var requests: [Key: Request] = [:]
    private let log = AppLog.for("StreamResolution")

    init(bridge: any YTDlpBridgeProtocol, cache: StreamURLCache,
         contextID: (@MainActor () -> String)? = nil) {
        self.bridge = bridge
        self.cache = cache
        self.contextID = contextID ?? { (bridge as? YTDlpBridge)?.streamContextID ?? "public" }
    }

    var streamContextID: String? { contextID() }

    /// Legacy callers still share the same typed extraction; URL-only disk entries
    /// cannot supply its headers/format/session and are deliberately not promoted.
    func resolve(videoID: String, quality: String) async throws -> URL {
        try await resolveStream(videoID: videoID, quality: quality).url
    }

    func resolveStream(videoID: String, quality: String) async throws -> ResolvedAudioStream {
        try Task.checkCancellation()
        // Concrete bridge contexts include immutable access policy plus session
        // generation, so public and authorized loads cannot coalesce or share cache.
        let context = contextID()
        retireOtherContexts(context)
        if let stream = cache.getStream(videoId: videoID, quality: quality, contextID: context) { return stream }
        let key = Key(videoID: videoID, quality: quality, context: context)
        let consumer = UUID()
        // A preparation may be claimed before this consumer registers. Forward
        // its sticky intent only to this request, never a later matching key.
        let callerPriority = YTDlpRequestPriority.queuedPriority
        defer { callerPriority?.stopObserving(id: consumer) }
        return try await withTaskCancellationHandler {
            let stream = try await withCheckedThrowingContinuation { continuation in
                if var request = requests[key] {
                    if YTDlpRequestPriority.interactive { request.priority.promote() }
                    request.consumers[consumer] = continuation
                    requests[key] = request
                    let priority = request.priority
                    callerPriority?.observe(id: consumer) { priority.promote() }
                } else {
                    let identity = UUID()
                    let priority = YTDlpQueuedPriority()
                    if YTDlpRequestPriority.interactive { priority.promote() }
                    let task = Task { @MainActor [weak self, bridge, log] in
                        let start = ContinuousClock.now
                        let result: Result<ResolvedAudioStream, Error>
                        do {
                            // No identical blind retry: client/session recovery is a
                            // separate, explicit policy, not another background resolver.
                            guard self?.contextID() == key.context else { throw CancellationError() }
                            let stream = try await YTDlpRequestPriority.$queuedPriority.withValue(priority) {
                                try await bridge.resolveAudioStream(videoId: videoID,
                                    quality: quality, timeout: 20)
                            }
                            try Task.checkCancellation()
                            result = .success(stream)
                        } catch { result = .failure(error) }
                        log.info("Resolution finished in \(start.duration(to: .now).seconds, privacy: .public)s")
                        self?.finish(key: key, identity: identity, result: result)
                    }
                    requests[key] = Request(identity: identity, task: task, priority: priority,
                                            consumers: [consumer: continuation])
                    callerPriority?.observe(id: consumer) { priority.promote() }
                }
            }
            try Task.checkCancellation()
            return stream
        } onCancel: {
            Task { @MainActor [weak self] in self?.release(key: key, consumer: consumer) }
        }
    }

    func invalidateStream(videoID: String, quality: String) {
        let key = Key(videoID: videoID, quality: quality, context: contextID())
        cache.invalidateStream(videoId: videoID, quality: quality, contextID: key.context)
        cache.invalidate(videoId: videoID, quality: quality)
        cancel(key)
    }

    private func finish(key: Key, identity: UUID, result: Result<ResolvedAudioStream, Error>) {
        guard let request = requests[key], request.identity == identity else { return }
        requests.removeValue(forKey: key)
        var result = result
        if contextID() != key.context { result = .failure(CancellationError()) }
        if case .success(let stream) = result {
            if stream.contextID != key.context || stream.isExpired() {
                result = .failure(YTDlpBridge.YTDlpError.parseFailed("Expired or mismatched stream context"))
            } else {
                cache.setStream(videoId: key.videoID, quality: key.quality, stream: stream)
            }
        }
        for consumer in request.consumers.values { consumer.resume(with: result) }
    }

    private func release(key: Key, consumer: UUID) {
        guard var request = requests[key], let continuation = request.consumers.removeValue(forKey: consumer) else { return }
        continuation.resume(throwing: CancellationError())
        if request.consumers.isEmpty {
            requests.removeValue(forKey: key)
            request.task.cancel()
        } else { requests[key] = request }
    }

    private func cancel(_ key: Key) {
        guard let request = requests.removeValue(forKey: key) else { return }
        request.task.cancel()
        for consumer in request.consumers.values { consumer.resume(throwing: CancellationError()) }
    }

    private func retireOtherContexts(_ context: String) {
        for key in Array(requests.keys) where key.context != context { cancel(key) }
        cache.retainStreamContext(context)
    }
}

enum StreamResolutionPolicy {
    static func shouldRetry(_ error: Error) -> Bool {
        guard !(error is CancellationError) else { return false }
        if let error = error as? YTDlpBridge.YTDlpError {
            switch error {
            case .notFound, .parseFailed: return false
            case .timeout: return true
            case .exitCode(_, let message):
                let text = message.lowercased()
                if ["private video", "video unavailable", "removed", "not available in your country",
                    "sign in", "age-restricted", "unsupported url", "requested format is not available",
                    "http error 429"].contains(where: text.contains) { return false }
                return ["timed out", "timeout", "connection", "http error 5", "http error 403"].contains(where: text.contains)
            }
        }
        return true
    }
}

extension Duration {
    fileprivate var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
