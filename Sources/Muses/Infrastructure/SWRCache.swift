import Foundation
import CryptoKit

/// Generic stale-while-revalidate cache: memory plus disk JSON, with a
/// `fetchedAt` timestamp.
///
/// Semantics:
///  - `get(_:)` returns the cached value and its age (fresh or stale); the
///    caller decides whether to refresh in the background.
///  - `set(_:value:)` writes to memory and persists asynchronously.
///  - `isFresh(age:freshWindow:)` checks whether the value is inside the fresh window.
///
/// `T` must be `Codable & Sendable`. Disk files live at `{dir}/{key-hex}.json`;
/// keys are normalized with SHA-256 to avoid illegal characters. `@MainActor`
/// matches `StreamURLCache`; encoding and staging writes run off the main actor.
/// Disk commits and invalidation share an identity-checked critical section.
@MainActor
final class SWRCache<T: Codable & Sendable> {
    struct Cached: Sendable {
        let value: T
        let fetchedAt: Date
        var age: TimeInterval { Date().timeIntervalSince(fetchedAt) }
    }

    private struct DiskEnvelope: Codable, Sendable {
        let value: T
        let fetchedAt: Date
    }

    private let memory: NSCache<NSString, CacheBox>
    private let directory: URL
    private let diskCache: RebuildableJSONCache
    private let diskWrites: SWRDiskWrites
    // NSCache may evict at any time. Retain new values until their detached
    // persistence completes so synchronous readers cannot fall into that gap.
    private var pendingWrites: [String: (id: UUID, cached: Cached)] = [:]
    private var persistenceTasks: [UUID: Task<Void, Never>] = [:]

    /// Box for the in-memory value (NSCache stores reference types).
    final class CacheBox {
        let cached: Cached
        init(_ cached: Cached) { self.cached = cached }
    }

    init(directory: URL, memory: NSCache<NSString, CacheBox> = .init(),
         diskCache: RebuildableJSONCache? = nil) {
        self.directory = directory
        self.memory = memory
        let cache = diskCache ?? RebuildableJSONCache(root: directory, limits: .search)
        self.diskCache = cache
        diskWrites = SWRDiskWrites(cache: cache)
    }

    /// Reads the cached value (memory first, falling back to disk). nil if not cached.
    func get(_ key: String) -> Cached? {
        if let pending = pendingWrites[key] { return pending.cached }
        let nsKey = key as NSString
        if let box = memory.object(forKey: nsKey) {
            return box.cached
        }
        // Backfill memory from disk.
        let url = fileURL(for: key)
        guard let data = diskCache.read(at: url),
              let envelope = try? JSONDecoder().decode(DiskEnvelope.self, from: data) else {
            return nil
        }
        let cached = Cached(value: envelope.value, fetchedAt: envelope.fetchedAt)
        memory.setObject(CacheBox(cached), forKey: nsKey)
        return cached
    }

    /// Writes to memory and persists to disk asynchronously.
    func set(_ key: String, value: T, fetchedAt: Date = .init()) {
        let cached = Cached(value: value, fetchedAt: fetchedAt)
        let writeID = UUID()
        pendingWrites[key] = (writeID, cached)
        memory.setObject(CacheBox(cached), forKey: key as NSString)
        let envelope = DiskEnvelope(value: value, fetchedAt: fetchedAt)
        let url = fileURL(for: key)
        let diskWrites = diskWrites
        diskWrites.begin(key, id: writeID, url: url)
        persistenceTasks[writeID] = Task.detached(priority: .utility) { [weak self] in
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(envelope) {
                diskWrites.persist(data, key: key, id: writeID, url: url)
            }
            diskWrites.finish(key, id: writeID, url: url)
            await MainActor.run {
                self?.persistenceTasks.removeValue(forKey: writeID)
                guard self?.pendingWrites[key]?.id == writeID else { return }
                self?.pendingWrites.removeValue(forKey: key)
            }
        }
    }

    /// Awaits writes dispatched before this call, including revoked writes.
    /// Callers requiring a cold disk read must cross this asynchronous boundary.
    func flushPendingWrites() async {
        let tasks = Array(persistenceTasks.values)
        for task in tasks { await task.value }
    }

    /// Invalidates a key (memory + disk).
    func invalidate(_ key: String) {
        pendingWrites.removeValue(forKey: key)
        memory.removeObject(forKey: key as NSString)
        diskWrites.invalidate(key, url: fileURL(for: key))
    }

    /// Clears everything (memory; disk files are removed as needed).
    func clearAll() {
        pendingWrites.removeAll()
        memory.removeAllObjects()
        diskWrites.clear(directory: directory)
    }

    func isFresh(_ cached: Cached, freshWindow: TimeInterval) -> Bool {
        cached.age <= freshWindow
    }

    private func fileURL(for key: String) -> URL {
        let hash = SHA256Hex(key)
        return directory.appendingPathComponent("\(hash).json")
    }
}

/// Serializes only publication/deletion, never encoding or the bulk data write.
/// Revoking a ticket and removing its file are atomic relative to publication.
private final class SWRDiskWrites: @unchecked Sendable {
    private let lock = NSLock()
    private var current: [String: UUID] = [:]
    private let cache: RebuildableJSONCache

    init(cache: RebuildableJSONCache) { self.cache = cache }

    func begin(_ key: String, id: UUID, url: URL) {
        lock.withLock {
            current[key] = id
            cache.beginPublication(at: url, id: id)
        }
    }

    func persist(_ data: Data, key: String, id: UUID, url: URL) {
        guard lock.withLock({ current[key] == id }) else { return }
        cache.write(data, at: url, publicationID: id) { commit in
            lock.withLock {
                guard current[key] == id else { return false }
                let published = commit()
                current.removeValue(forKey: key)
                return published
            }
        }
    }

    func invalidate(_ key: String, url: URL) {
        lock.withLock {
            current.removeValue(forKey: key)
            cache.remove(at: url)
        }
    }

    func finish(_ key: String, id: UUID, url: URL) {
        lock.withLock {
            if current[key] == id { current.removeValue(forKey: key) }
            cache.finishPublication(at: url, id: id)
        }
    }

    func clear(directory: URL) {
        lock.withLock {
            current.removeAll()
            cache.clear(in: directory)
        }
    }
}

/// SHA-256 hex string (normalizes cache keys).
func SHA256Hex(_ s: String) -> String {
    let data = Data(s.utf8)
    let digest = Array(SHA256.hash(data: data))
    return digest.map { String(format: "%02x", $0) }.joined()
}
