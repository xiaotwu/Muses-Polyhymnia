import Foundation

/// In-memory cache of resolved YouTube stream URLs, optionally backed by disk.
///
/// yt-dlp produces a signed, time-limited direct URL for each video. Re-resolving
/// is slow and rate-limit-prone, so successful resolutions are cached with a TTL
/// (default 6 hours, matching the typical longevity of YouTube's signed URLs).
/// On 403/expiry the caller invalidates the entry so the next load re-resolves.
///
/// When `persistencePath` is non-nil (as in the `.default` singleton), the cache
/// is persisted to JSON on disk so resolved URLs survive restarts, and the first
/// playback after a cold start does not need to call yt-dlp.
@MainActor
final class StreamURLCache {
    /// Shared singleton used by `YouTubeStreamEngine` and friends. Enables disk persistence.
    static let `default` = StreamURLCache(
        persistencePath: StreamURLCache.defaultPersistenceURL)

    private static var defaultPersistenceURL: URL? {
        MusesDataPaths.caches.appendingPathComponent("stream-urls.json")
    }

    private struct Entry: Codable {
        let url: URL
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let defaultTTL: TimeInterval
    private let persistencePath: URL?
    private var didLoadFromDisk = false

    init(defaultTTL: TimeInterval = 6 * 3600, persistencePath: URL? = nil) {
        self.defaultTTL = defaultTTL
        self.persistencePath = persistencePath
    }

    /// Lazily loads the disk cache (only once a `persistencePath` is configured
    /// and it has not been loaded yet).
    private func ensureLoadedFromDisk() {
        guard !didLoadFromDisk, let path = persistencePath else { return }
        didLoadFromDisk = true
        guard let data = try? Data(contentsOf: path) else { return }
        struct Persisted: Codable { let entries: [String: Entry] }
        guard let decoded = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        // Keep only entries that have not expired.
        let now = Date()
        for (id, entry) in decoded.entries where entry.expiresAt > now {
            entries[id] = entry
        }
    }

    /// Writes the current in-memory cache to disk (only when a
    /// `persistencePath` is configured).
    private func persistToDisk() {
        guard let path = persistencePath else { return }
        struct Persisted: Codable { let entries: [String: Entry] }
        let payload = Persisted(entries: entries)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: path, options: .atomic)
    }

    static func cacheKey(videoId: String, quality: String) -> String {
        "\(videoId)|\(quality)"
    }

    /// Returns the cached URL for `videoId`+`quality` if present and unexpired.
    /// Expired entries are evicted on read.
    func get(videoId: String, quality: String = "bestaudio") -> URL? {
        ensureLoadedFromDisk()
        let key = Self.cacheKey(videoId: videoId, quality: quality)
        return liveURL(for: key)
    }

    /// Stores `url` for `videoId`+`quality` with the cache's default TTL (or a custom one).
    func set(videoId: String, url: URL, quality: String = "bestaudio", ttl: TimeInterval? = nil) {
        ensureLoadedFromDisk()
        let effective = ttl ?? defaultTTL
        let key = Self.cacheKey(videoId: videoId, quality: quality)
        let requestedExpiry = Date().addingTimeInterval(effective)
        let signedExpiry = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "expire" })?.value.flatMap(Double.init)
            .map { Date(timeIntervalSince1970: $0 - 30) }
        entries[key] = Entry(url: url, expiresAt: min(requestedExpiry, signedExpiry ?? requestedExpiry))
        persistToDisk()
    }

    /// Removes a quality-specific entry, or every quality for `videoId` when `quality` is nil.
    func invalidate(videoId: String, quality: String? = nil) {
        ensureLoadedFromDisk()
        streams = streams.filter { key, _ in key.videoID != videoId || (quality != nil && key.quality != quality!) }
        if let quality {
            entries.removeValue(forKey: Self.cacheKey(videoId: videoId, quality: quality))
        } else {
            let prefix = "\(videoId)|"
            entries = entries.filter { key, _ in key != videoId && !key.hasPrefix(prefix) }
        }
        persistToDisk()
    }

    private func liveURL(for key: String) -> URL? {
        guard let entry = entries[key] else { return nil }
        guard entry.expiresAt > Date() else {
            entries.removeValue(forKey: key)
            persistToDisk()
            return nil
        }
        return entry.url
    }

    private struct StreamKey: Hashable {
        let videoID: String
        let quality: String
        let context: String
    }
    private struct StreamEntry {
        let stream: ResolvedAudioStream
        let expiresAt: Date
    }
    // Complete request contexts are volatile; never write headers or signed
    // session URLs into the legacy URL-only persistence file.
    private var streams: [StreamKey: StreamEntry] = [:]

    func getStream(videoId: String, quality: String, contextID: String) -> ResolvedAudioStream? {
        let key = StreamKey(videoID: videoId, quality: quality, context: contextID)
        guard let entry = streams[key] else { return nil }
        guard entry.expiresAt > Date(), !entry.stream.isExpired() else {
            streams.removeValue(forKey: key)
            return nil
        }
        return entry.stream
    }

    func setStream(videoId: String, quality: String, stream: ResolvedAudioStream) {
        let key = StreamKey(videoID: videoId, quality: quality, context: stream.contextID)
        streams = streams.filter { $0.value.expiresAt > Date() }
        // Bound speculative/prefetch metadata, independently of library size.
        if streams.count >= 128, let oldest = streams.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key {
            streams.removeValue(forKey: oldest)
        }
        let signedExpiry = URLComponents(url: stream.url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "expire" })?.value.flatMap(Double.init)
            .flatMap { $0.isFinite ? Date(timeIntervalSince1970: $0 - 30) : nil }
        let expiry = min(Date().addingTimeInterval(defaultTTL),
                         stream.expiresAt?.addingTimeInterval(-30) ?? .distantFuture,
                         signedExpiry ?? .distantFuture)
        guard expiry > Date() else { return }
        streams[key] = StreamEntry(stream: stream, expiresAt: expiry)
    }

    func invalidateStream(videoId: String, quality: String, contextID: String) {
        streams.removeValue(forKey: StreamKey(videoID: videoId, quality: quality, context: contextID))
    }

    func retainStreamContext(_ contextID: String) {
        streams = streams.filter { $0.key.context == contextID }
    }

    /// Removes a single entry (alias for `invalidate`).
    func remove(videoId: String) {
        invalidate(videoId: videoId)
    }

    /// Evicts every entry whose TTL has passed.
    func clearExpired() {
        ensureLoadedFromDisk()
        let now = Date()
        entries = entries.filter { _, entry in entry.expiresAt > now }
        streams = streams.filter { $0.value.expiresAt > now }
        persistToDisk()
    }
}
