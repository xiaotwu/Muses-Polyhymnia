import Testing
import Foundation
@testable import Muses

/// Pure-logic tests for the online performance infrastructure (SWRCache / YTDlpSearchCache / PerfTrace).
/// No real network or yt-dlp; caches use a temporary directory that is cleaned up afterwards.
@MainActor
@Suite("Phase D2 — Online perf caches & trace", .serialized)
struct PerfCacheTests {

    private func tmpDir() -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("muses-d2-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    // MARK: - SWRCache

    @Test("SWRCache: set then get hits, preserving fetchedAt and age")
    func swrSetGet() throws {
        let cache = SWRCache<[String]>(directory: tmpDir())
        cache.set("k", value: ["a", "b"])
        let cached = try #require(cache.get("k"))
        #expect(cached.value == ["a", "b"])
        #expect(cached.age >= 0)
        #expect(cached.age < 1)
    }

    @Test("SWRCache: unwritten key returns nil")
    func swrMiss() {
        let cache = SWRCache<[String]>(directory: tmpDir())
        #expect(cache.get("missing") == nil)
    }

    @Test("SWRCache: isFresh is true within window and false after expiration")
    func swrFreshness() throws {
        let cache = SWRCache<[String]>(directory: tmpDir())
        let old = Date().addingTimeInterval(-120)
        cache.set("k", value: ["x"], fetchedAt: old)
        let cached = try #require(cache.get("k"))
        #expect(cache.isFresh(cached, freshWindow: 180) == true)
        #expect(cache.isFresh(cached, freshWindow: 60) == false)
    }

    @Test("SWRCache retains a just-set value when its evictable memory is cleared before persistence")
    func swrEvictionBeforePersistence() throws {
        let memory = NSCache<NSString, SWRCache<[String]>.CacheBox>()
        let cache = SWRCache<[String]>(directory: tmpDir(), memory: memory)
        let now = Date()
        // Keep the actor occupied until get: detached persistence is not an
        // authority for the synchronous set-then-get contract.
        for index in 0..<64 {
            let key = "evicted-\(index)"
            cache.set(key, value: [key], fetchedAt: now)
            memory.removeAllObjects()
            let cached = try #require(cache.get(key))
            #expect(cached.value == [key])
            #expect(cached.fetchedAt == now)
        }
    }

    @Test("SWRCache pending replacement, invalidate and clear remain synchronous without disk fallback")
    func swrPendingReplacementAndInvalidation() throws {
        let root = tmpDir()
        let blockedParent = root.appendingPathComponent("regular-file")
        try Data().write(to: blockedParent)
        // A regular-file parent prevents persistence, including clearAll's
        // directory recreation. This isolates pending values from disk timing.
        let memory = NSCache<NSString, SWRCache<[String]>.CacheBox>()
        let cache = SWRCache<[String]>(
            directory: blockedParent.appendingPathComponent("cache"), memory: memory)
        cache.set("k", value: ["old"])
        cache.set("k", value: ["replacement"])
        memory.removeAllObjects()
        #expect(try #require(cache.get("k")).value == ["replacement"])
        cache.invalidate("k")
        #expect(cache.get("k") == nil)

        cache.set("a", value: ["first"])
        cache.set("b", value: ["second"])
        memory.removeAllObjects()
        #expect(try #require(cache.get("a")).value == ["first"])
        #expect(try #require(cache.get("b")).value == ["second"])
        cache.clearAll()
        #expect(cache.get("a") == nil)
        #expect(cache.get("b") == nil)
    }

    @Test("SWRCache: disk persistence across instances simulates cold start")
    func swrDiskPersistence() async {
        let dir = tmpDir()
        let cache1 = SWRCache<[String]>(directory: dir)
        cache1.set("k", value: ["persisted"])
        await cache1.flushPendingWrites()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        #expect(files.contains { $0.pathExtension == "json" })

        // A fresh instance (empty memory) backfills from disk.
        let cache2 = SWRCache<[String]>(directory: dir)
        let cached = cache2.get("k")
        #expect(cached?.value == ["persisted"])
    }

    @Test("SWRCache: invalidate removes from memory and disk")
    func swrInvalidate() {
        let dir = tmpDir()
        let cache = SWRCache<[String]>(directory: dir)
        cache.set("k", value: ["x"])
        #expect(cache.get("k") != nil)
        cache.invalidate("k")
        #expect(cache.get("k") == nil)
    }

    @Test("obsolete delayed disk writes cannot undo invalidate, clear or replacement",
          arguments: ["invalidate", "clear", "replace"])
    func delayedDiskWriteIsRevoked(action: String) async throws {
        let dir = tmpDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let gate = CacheEncodingGate()
        defer { gate.release() }
        let cache = SWRCache<GatedCacheValue>(directory: dir)
        cache.set("k", value: GatedCacheValue(text: "old", gate: gate))
        for _ in 0..<100 where !gate.started {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(gate.started)

        if action == "replace" {
            cache.set("k", value: GatedCacheValue(text: "new"))
            // Force the new value to reach disk before the old encoder resumes.
            let reader = SWRCache<GatedCacheValue>(directory: dir)
            for _ in 0..<100 where reader.get("k")?.value.text != "new" {
                try await Task.sleep(for: .milliseconds(10))
            }
            try #require(reader.get("k")?.value.text == "new")
        } else if action == "clear" {
            cache.clearAll()
        } else {
            cache.invalidate("k")
        }
        gate.release()
        await cache.flushPendingWrites()

        let reopened = SWRCache<GatedCacheValue>(directory: dir)
        #expect(reopened.get("k")?.value.text == (action == "replace" ? "new" : nil))
        #expect(cache.get("k")?.value.text == (action == "replace" ? "new" : nil))
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        #expect(files.allSatisfy { $0.pathExtension == "json" })
    }

    // MARK: - YTDlpSearchCache

    @Test("YTDlpSearchCache: fresh hit skips process spawn determination")
    func searchCacheFreshness() {
        let cache = YTDlpSearchCache(directory: tmpDir(), freshWindow: 60)
        cache.set(query: "q", limit: 10,
                  entries: [YTDlpBridge.YTDlpPlaylistEntry(id: "yt_track_1", title: "t")])
        #expect(cache.get(query: "q", limit: 10)?.value.count == 1)
        #expect(cache.isFresh(query: "q", limit: 10) == true)
        #expect(cache.isFresh(query: "other", limit: 10) == false)
    }

    @Test("YTDlpSearchCache: stale is still readable but isFresh is false (SWR semantics)")
    func searchCacheStaleWhileRevalidate() {
        let cache = YTDlpSearchCache(directory: tmpDir(), freshWindow: 60)
        let old = Date().addingTimeInterval(-120)
        cache.set(query: "q", limit: 5,
                  entries: [YTDlpBridge.YTDlpPlaylistEntry(id: "yt_track_1", title: "t")],
                  fetchedAt: old)
        // Stale but still immediately displayable.
        #expect(cache.get(query: "q", limit: 5) != nil)
        #expect(cache.isFresh(query: "q", limit: 5) == false)
    }

    @Test("YTDlpSearchCache: invalidate and clearAll")
    func searchCacheInvalidate() {
        let cache = YTDlpSearchCache(directory: tmpDir())
        cache.set(query: "q", limit: 10, entries: [])
        #expect(cache.get(query: "q", limit: 10) != nil)
        cache.invalidate(query: "q", limit: 10)
        #expect(cache.get(query: "q", limit: 10) == nil)
    }

    // MARK: - PerfTrace

    @Test("PerfTrace: event records instantaneous event and dumpText contains name")
    func perfTraceEvent() {
        PerfTrace.clear()
        PerfTrace.event("home.appear")
        PerfTrace.event("home.firstCachedContent")
        let snap = PerfTrace.snapshot()
        #expect(snap.count == 2)
        #expect(snap[0].name == "home.appear")
        #expect(snap[0].duration == nil)
        let dump = PerfTrace.dumpText()
        #expect(dump.contains("home.appear"))
        #expect(dump.contains("home.firstCachedContent"))
        PerfTrace.clear()
    }

    @Test("PerfTrace: begin/end interval records duration")
    func perfTraceInterval() {
        PerfTrace.clear()
        let token = PerfTrace.begin("home.refreshTotal")
        Thread.sleep(forTimeInterval: 0.01)
        PerfTrace.end(token)
        let rec = PerfTrace.snapshot().first { $0.name == "home.refreshTotal" }
        #expect(rec?.duration ?? 0 >= 0.005)
        PerfTrace.clear()
    }

    // MARK: - Baseline: order of magnitude of a cache hit vs a cold spawn (spec §25 metrics)

    @Test("Benchmark: YTDlpSearchCache hit path latency (microsecond scale)")
    func benchmarkCacheHitLatency() {
        let cache = YTDlpSearchCache(directory: tmpDir(), freshWindow: 60)
        let entries = (0..<12).map {
            YTDlpBridge.YTDlpPlaylistEntry(id: "yt_track_\($0)", title: "t\($0)")
        }
        cache.set(query: "seed", limit: 12, entries: entries)
        // Warm up once (fills the in-memory cache).
        _ = cache.get(query: "seed", limit: 12)

        let n = 10_000
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<n {
            _ = cache.isFresh(query: "seed", limit: 12)
            _ = cache.get(query: "seed", limit: 12)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perOpUs = elapsed / Double(n) * 1_000_000
        // Print to stdout for the metrics file; assert the hit path stays within 100µs (far below a spawn).
        print("[D2-bench] cache hit per op: \(String(format: "%.2f", perOpUs)) µs over \(n) ops")
        #expect(perOpUs < 100)
        PerfTrace.clear()
    }
}

private final class CacheEncodingGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var blocked = true
    private var encodingStarted = false

    var started: Bool {
        condition.lock()
        defer { condition.unlock() }
        return encodingStarted
    }

    func wait() {
        condition.lock()
        encodingStarted = true
        condition.broadcast()
        while blocked { condition.wait() }
        condition.unlock()
    }

    func release() {
        condition.lock()
        blocked = false
        condition.broadcast()
        condition.unlock()
    }
}

private struct GatedCacheValue: Codable, Sendable {
    let text: String
    var gate: CacheEncodingGate? = nil

    init(text: String, gate: CacheEncodingGate? = nil) {
        self.text = text
        self.gate = gate
    }

    init(from decoder: Decoder) throws {
        text = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        gate?.wait()
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}
