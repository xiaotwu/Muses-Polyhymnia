import Darwin
import Foundation
import SwiftData
import Testing
@testable import Muses

@Suite("Rebuildable JSON family budgets")
struct RebuildableJSONCacheTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "muses-json-budget-\(UUID().uuidString)")
    }
    private func file(_ root: URL, _ key: String) -> URL { root.appending(path: SHA256Hex(key) + ".json") }

    private func footprint(_ root: URL) -> (bytes: Int64, entries: Int) {
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var bytes: Int64 = 0, entries = 0
        while let url = files?.nextObject() as? URL {
            var info = stat()
            if lstat(url.path, &info) == 0 {
                bytes += max(Int64(info.st_size), Int64(info.st_blocks) * 512)
                entries += 1
            }
        }
        return (bytes, entries)
    }

    @Test("concurrent independent writers share byte and entry admission")
    func concurrentFamilyBudget() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = JSONCacheLimits(bytes: 64 * 1024, entries: 8, entryBytes: 8192)
        await withTaskGroup(of: Bool.self) { group in
            for index in 0..<32 {
                let cache = RebuildableJSONCache(root: directory, limits: limits)
                let url = file(directory, String(index))
                group.addTask { cache.write(Data(repeating: UInt8(index), count: 4096), at: url) }
            }
            for await result in group { #expect(result) }
        }
        let final = footprint(directory)
        #expect(final.bytes <= limits.bytes)
        #expect(final.entries <= limits.entries)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(files.count == 8)
        #expect(files.allSatisfy { $0.pathExtension == "json" })
    }

    @Test("byte admission is independent of entry count and oversized input creates no staging")
    func byteAdmission() throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = JSONCacheLimits(bytes: 16 * 1024, entries: 40, entryBytes: 8192)
        let cache = RebuildableJSONCache(root: directory, limits: limits)
        for index in 0..<16 {
            #expect(cache.write(Data(repeating: 1, count: 4096), at: file(directory, String(index))))
        }
        #expect(footprint(directory).bytes <= limits.bytes)
        #expect(footprint(directory).entries == 4)
        #expect(!cache.write(Data(repeating: 1, count: 8193), at: file(directory, "oversized")))
        #expect(footprint(directory).entries == 4)
    }

    @Test("unknown files and orphan staging count toward the cap without being deleted")
    func unknownFilesAndFallback() throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = RebuildableJSONCache(root: directory,
            limits: .init(bytes: 16 * 1024, entries: 10, entryBytes: 8192))
        let fallback = file(directory, "fallback")
        #expect(cache.write(Data("saved-account".utf8), at: fallback))
        cache.protectFallback(at: fallback)
        let manual = directory.appending(path: "manual.bin")
        let orphan = directory.appending(path: ".old.tmp")
        try Data(repeating: 7, count: 8192).write(to: manual)
        try Data(repeating: 8, count: 4096).write(to: orphan)
        let before = footprint(directory)
        #expect(!cache.write(Data("new".utf8), at: file(directory, "new")))
        #expect(cache.read(at: fallback) == Data("saved-account".utf8))
        #expect(try Data(contentsOf: manual) == Data(repeating: 7, count: 8192))
        #expect(try Data(contentsOf: orphan) == Data(repeating: 8, count: 4096))
        #expect(footprint(directory).entries == before.entries)
    }

    @Test("symlink roots, partitions and hard-linked cache files never escape ownership")
    func pathOwnership() throws {
        let directory = root(), outside = root()
        defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = file(outside, "sentinel")
        try Data("outside".utf8).write(to: sentinel)
        let link = directory.appending(path: "linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let cache = RebuildableJSONCache(root: directory, limits: .search)
        #expect(!cache.write(Data("bad".utf8), at: file(link, "sentinel")))
        #expect(cache.read(at: file(link, "sentinel")) == nil)
        let linkedRoot = RebuildableJSONCache(root: link, limits: .search)
        #expect(!linkedRoot.write(Data("bad".utf8), at: file(link, "sentinel")))
        let hardLink = file(directory, "hard-link")
        try FileManager.default.linkItem(at: sentinel, to: hardLink)
        #expect(!cache.write(Data("bad".utf8), at: hardLink))
        cache.remove(at: hardLink)
        #expect(FileManager.default.fileExists(atPath: hardLink.path))
        #expect(try Data(contentsOf: sentinel) == Data("outside".utf8))
    }

    @Test("a revoked publication preserves the old destination and removes only its staging")
    func revokedPublication() throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = RebuildableJSONCache(root: directory, limits: .search)
        let url = file(directory, "same")
        #expect(cache.write(Data("old".utf8), at: url))
        #expect(!cache.write(Data("replacement".utf8), at: url, publish: { _ in false }))
        #expect(cache.read(at: url) == Data("old".utf8))
        #expect(footprint(directory).entries == 1)
    }

    @Test("replacing a staged partition revokes publication even when its textual path returns")
    func replacedDirectory() throws {
        let directory = root(), moved = root()
        defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: moved) }
        let cache = RebuildableJSONCache(root: directory, limits: .search)
        let url = file(directory, "same")
        #expect(cache.write(Data("old".utf8), at: url))
        let published = cache.write(Data("new".utf8), at: url) { commit in
            do {
                try FileManager.default.moveItem(at: directory, to: moved)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch { return false }
            return commit()
        }
        #expect(!published)
        #expect(try Data(contentsOf: file(moved, "same")) == Data("old".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        #expect(footprint(moved).entries == 1)
    }

    @Test("SWR partitions share one budget while cold readers retain provider timestamps")
    @MainActor
    func swrPartitions() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = JSONCacheLimits(bytes: 64 * 1024, entries: 8, entryBytes: 8192)
        let disk = RebuildableJSONCache(root: directory, limits: limits)
        let first = SWRCache<[String]>(directory: directory.appending(path: "one"), diskCache: disk)
        let second = SWRCache<[String]>(directory: directory.appending(path: "two"), diskCache: disk)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<20 {
            let cache = index.isMultiple(of: 2) ? first : second
            cache.set("key-\(index)", value: [String(index)], fetchedAt: date)
            await cache.flushPendingWrites()
        }
        #expect(footprint(directory).bytes <= limits.bytes)
        #expect(footprint(directory).entries <= limits.entries)
        let cold = SWRCache<[String]>(directory: directory.appending(path: "two"), diskCache: disk)
        let saved = try #require(cold.get("key-19"))
        #expect(saved.value == ["19"])
        #expect(saved.fetchedAt == date)
        #expect(!cold.isFresh(saved, freshWindow: 60))
    }

    @Test("Home budget preserves the active account fallback and the seven-day trust boundary")
    @MainActor
    func homeFallback() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = JSONCacheLimits(bytes: 128 * 1024, entries: 14, entryBytes: 16384)
        let cache = HomeFeedCache(directory: directory, diskLimits: limits)
        let account = input(scope: .account(channelID: "UC_one"))
        let savedAt = Date().addingTimeInterval(-6 * 24 * 60 * 60)
        let saved = HomeSnapshot(scope: account.scope,
            sections: [.init(id: "web", title: "saved", kind: .quickPicks, items: [],
                source: .signedInWeb, accountChannelID: "UC_one")],
            fetchedAt: savedAt, expiresAt: savedAt.addingTimeInterval(15 * 60))
        #expect(cache.set(saved, for: account, layer: .web, mode: .youtubeMusic))
        await cache.flushPendingWrites()
        // A missing account partition must not replace the validated fallback's protection.
        #expect(cache.get(for: input(scope: .account(channelID: "UC_missing")), layer: .web, mode: .youtubeMusic) == nil)
        for index in 0..<24 {
            let guest = input(scope: .guest, artist: String(index))
            let date = Date()
            let local = HomeSnapshot(scope: .guest,
                sections: [.init(id: "local", title: "local", kind: .quickPicks, items: [], source: .localLibrary)],
                fetchedAt: date, expiresAt: date.addingTimeInterval(60))
            #expect(cache.set(local, for: guest, layer: .baseline))
            await cache.flushPendingWrites()
        }
        #expect(footprint(directory).bytes <= limits.bytes)
        #expect(footprint(directory).entries <= limits.entries)
        let cold = HomeFeedCache(directory: directory, diskLimits: limits)
        let fallback = try #require(cold.get(for: account, layer: .web, mode: .youtubeMusic))
        #expect(fallback.value.accountChannelID == "UC_one")
        #expect(fallback.value.fetchedAt == savedAt)
        #expect(!cold.isFresh(fallback, layer: .web))
        #expect(cold.get(for: input(scope: .account(channelID: "UC_other")), layer: .web, mode: .youtubeMusic) == nil)
        #expect(cold.get(for: account, layer: .web, mode: .youtubeMusic,
            now: savedAt.addingTimeInterval(HomeFeedCache.webStaleLimit + 1)) == nil)
    }

    private func input(scope: HomeFeedScope, artist: String = "") -> HomeDiscoveryInput {
        .init(topArtistNames: [artist], recentlyPlayedArtistNames: [], likedArtistNames: [],
            timeBand: .morning, hour: 8, scope: scope, language: "en", region: "US")
    }

    @Test("catalog locales share a whole-family limit without turning successful provider results into errors")
    func catalogLocales() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = JSONCacheLimits(bytes: 64 * 1024, entries: 8, entryBytes: 8192)
        for index in 0..<20 {
            let region = index.isMultiple(of: 2) ? "US" : "GB"
            let language = index.isMultiple(of: 2) ? "en" : "zh-Hant"
            let provider = CachedMusicCatalogProvider(upstream: BudgetCatalogFixture(region: region, language: language),
                directory: directory, region: region, language: language, diskLimits: limits)
            let page = try await provider.search("query-\(index)", kind: nil)
            #expect(page.items.first?.title == "Fresh")
            #expect(!page.isStale)
        }
        #expect(footprint(directory).bytes <= limits.bytes)
        #expect(footprint(directory).entries <= limits.entries)
    }
}

private actor BudgetCatalogFixture: MusicCatalogProviding {
    let region: String
    let language: String
    init(region: String, language: String) { self.region = region; self.language = language }
    func reset() {}
    func search(_ query: String, kind: MusicCatalogKind?) async throws -> MusicCatalogPage {
        .init(items: [.init(id: "video:abcdefghijk", kind: .song, title: "Fresh", subtitle: "", artwork: nil,
            artists: [], releases: [], channels: [])], filters: [], next: nil, fetchedAt: Date(),
            region: region, language: language)
    }
    func browse(_ id: String) async throws -> MusicCatalogPage { try await search(id, kind: nil) }
    func next(_ cursor: MusicCatalogCursor) async throws -> MusicCatalogPage { throw MusicCatalogError.unavailable }
}
