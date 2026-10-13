import Foundation
import Testing
@testable import Muses

@Suite("Home feed retirement and provenance")
@MainActor
struct HomeFeedRetirementTests {
    @Test("missing, retired and unknown section provenance fail closed",
          arguments: ["missing", "publicDiscovery", "unknownSource"])
    func retiredSectionCannotDecode(source: String) throws {
        let section = localSection()
        var object = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(section)) as? [String: Any])
        if source == "missing" { object.removeValue(forKey: "source") }
        else { object["source"] = source }
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(HomeSection.self, from: data) }
    }

    @Test("saved presentation keeps genuine upstream provenance")
    func cachedSectionKeepsOrigin() {
        let web = webSection("UC_one")
        let cached = web.presentedFromCache(staleReason: "offline")
        #expect(cached.source == .cached)
        #expect(cached.cachedOrigin == .signedInWeb)
        #expect(cached.accountChannelID == "UC_one")
        #expect(cached.staleReason == "offline")
    }

    @Test("Muses and account Web cache layers accept only their actual producer")
    func layersRejectRelabeledContent() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let account = input(.account(channelID: "UC_one"))
        let local = snapshot(account.scope, sections: [localSection()])
        let web = snapshot(account.scope, sections: [webSection("UC_one")])
        let official = snapshot(account.scope, sections: [HomeSection(
            id: "official", title: "Likes", kind: .quickPicks, items: [],
            source: .officialAccount, accountChannelID: "UC_one")])
        #expect(cache.set(local, for: account, layer: .baseline, mode: .muses))
        #expect(cache.set(web, for: account, layer: .web, mode: .youtubeMusic))
        #expect(!cache.set(local, for: account, layer: .baseline, mode: .youtubeMusic))
        #expect(!cache.set(official, for: account, layer: .baseline, mode: .muses))
        #expect(!cache.set(web, for: account, layer: .baseline, mode: .muses))
        #expect(!cache.set(web, for: account, layer: .web, mode: .muses))
        #expect(!cache.set(local, for: account, layer: .web, mode: .youtubeMusic))
        #expect(!cache.set(official, for: account, layer: .web, mode: .youtubeMusic))
        let relabeled = snapshot(account.scope, sections: [localSection().presentedFromCache(staleReason: nil)])
        #expect(!cache.set(relabeled, for: account, layer: .baseline, mode: .muses))
    }

    @Test("guest, wrong-account and mixed Web snapshots cannot cross account ownership")
    func snapshotManifestRejectsCrossAccountContent() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let account = input(.account(channelID: "UC_one"))
        let wrong = snapshot(account.scope, sections: [webSection("UC_two")])
        #expect(!wrong.belongs(to: account.scope))
        #expect(!cache.set(wrong, for: account, layer: .web, mode: .youtubeMusic))
        let mixed = snapshot(account.scope, sections: [webSection("UC_one"), localSection()])
        #expect(!cache.set(mixed, for: account, layer: .web, mode: .youtubeMusic))
        let guest = input(.guest)
        #expect(!cache.set(snapshot(.guest, sections: [webSection("UC_one")]),
                           for: guest, layer: .web, mode: .youtubeMusic))
        #expect(cache.get(for: guest, layer: .web, mode: .youtubeMusic) == nil)
    }

    @Test("Web snapshots older than seven days are not presented")
    func webStaleLimitIsSevenDays() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let account = input(.account(channelID: "UC_one"))
        let old = Date().addingTimeInterval(-(HomeFeedCache.webStaleLimit + 1))
        let web = snapshot(account.scope, sections: [webSection("UC_one")], fetchedAt: old)
        #expect(cache.set(web, for: account, layer: .web, mode: .youtubeMusic))
        #expect(cache.get(for: account, layer: .web, mode: .youtubeMusic) == nil)
    }

    @Test("anonymous baseline retirement preserves Web, Muses and unrelated cache paths")
    func retirementDeletesOnlyAnonymousLayers() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let retired = [
            "youtube-music-v1/guest/en-us/baseline-official-v3",
            "youtube-music-v1/guest/baseline-official-v3",
            "youtube-music-v1/account-UC_one/en-us/baseline-official-v3",
            "youtube-music-v1/account-UC_one/zh-hant-tw/baseline-official-v3"
        ]
        let retained = [
            "youtube-music-v1/account-UC_one/en-us/web",
            "youtube-music-v1/account-UC_two/zh-hant-tw/web",
            "muses-v1/guest/en-us/baseline-official-v3",
            "catalog-v1/cache",
            "youtube-music-v1/unrelated/en-us/baseline-official-v3"
        ]
        for path in retired + retained {
            let directory = root.appendingPathComponent(path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(path.utf8).write(to: directory.appendingPathComponent("fixture.json"))
        }
        _ = HomeFeedCache(directory: root)
        for path in retired { #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path)) }
        for path in retained {
            let file = root.appendingPathComponent(path).appendingPathComponent("fixture.json")
            #expect(try Data(contentsOf: file) == Data(path.utf8))
        }
    }

    @Test("anonymous retirement never traverses scope or layer symlinks")
    func retirementDoesNotFollowSymlinks() throws {
        let root = temporaryRoot()
        let external = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let outside = external.appendingPathComponent("baseline-official-v3", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("sentinel.json")
        try Data("preserved".utf8).write(to: sentinel)
        let mode = root.appendingPathComponent("youtube-music-v1", isDirectory: true)
        try FileManager.default.createDirectory(at: mode, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: mode.appendingPathComponent("account-linked"),
                                                   withDestinationURL: external)
        let locale = mode.appendingPathComponent("guest/en-us", isDirectory: true)
        try FileManager.default.createDirectory(at: locale, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: locale.appendingPathComponent("baseline-official-v3"),
                                                   withDestinationURL: outside)
        _ = HomeFeedCache(directory: root)
        #expect(try Data(contentsOf: sentinel) == Data("preserved".utf8))
        #expect(FileManager.default.fileExists(atPath: mode.appendingPathComponent("account-linked").path))
    }

    @Test("retirement refuses a symlinked Home cache root or path ancestor",
          arguments: [false, true])
    func retirementDoesNotFollowCacheRootSymlinks(linkRoot: Bool) throws {
        let root = temporaryRoot()
        let external = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let externalCache = external.appendingPathComponent("home-feed", isDirectory: true)
        let outside = externalCache.appendingPathComponent(
            "youtube-music-v1/guest/en-us/baseline-official-v3", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("sentinel.json")
        let direct = externalCache.appendingPathComponent("legacy.json")
        try Data("preserved".utf8).write(to: sentinel)
        try Data("legacy-preserved".utf8).write(to: direct)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link,
            withDestinationURL: linkRoot ? externalCache : external)
        let directory = linkRoot ? link : link.appendingPathComponent("home-feed", isDirectory: true)
        let cache = HomeFeedCache(directory: directory)
        #expect(try Data(contentsOf: sentinel) == Data("preserved".utf8))
        #expect(try Data(contentsOf: direct) == Data("legacy-preserved".utf8))
        #expect(cache.get(for: input(.guest), layer: .baseline, mode: .youtubeMusic) == nil)
    }

    @Test("retired Home disk envelopes cannot be decoded in an otherwise valid account Web partition",
          arguments: ["missing", "publicDiscovery", "unknownSource", "cachedPublic"])
    func retiredDiskEnvelopeNeverLoads(source: String) throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let account = input(.account(channelID: "UC_one"))
        let web = snapshot(account.scope, sections: [webSection("UC_one")])
        var value = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(web)) as? [String: Any])
        var sections = try #require(value["sections"] as? [[String: Any]])
        if source == "missing" { sections[0].removeValue(forKey: "source") }
        else if source == "cachedPublic" {
            sections[0]["source"] = "cached"
            sections[0]["cachedOrigin"] = "publicDiscovery"
        } else { sections[0]["source"] = source }
        value["sections"] = sections
        let envelope: [String: Any] = ["value": value, "fetchedAt": web.fetchedAt.timeIntervalSinceReferenceDate]
        let directory = cache.directoryURL(for: account.scope, layer: .web, mode: .youtubeMusic)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let key = SHA256Hex(HomeFeedCache.key(for: account, mode: .youtubeMusic))
        try JSONSerialization.data(withJSONObject: envelope).write(to: directory.appendingPathComponent(key + ".json"))
        #expect(cache.get(for: account, layer: .web, mode: .youtubeMusic) == nil)
    }

    @Test("legacy combined JSON is invalidated without touching partition directories")
    func legacyCombinedCacheIsInvalidated() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacy = root.appendingPathComponent("legacy.json")
        let partition = root.appendingPathComponent("account-UC_one", isDirectory: true)
        try Data("legacy".utf8).write(to: legacy)
        try FileManager.default.createDirectory(at: partition, withIntermediateDirectories: true)
        _ = HomeFeedCache(directory: root)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(FileManager.default.fileExists(atPath: partition.path))
    }

    @Test("blank account identifiers remain a non-account scope")
    func blankAccountIsGuest() {
        #expect(HomeFeedScope(accountChannelID: "  ") == .guest)
        #expect(HomeFeedScope(accountChannelID: "UC_one") == .account(channelID: "UC_one"))
    }

    private func temporaryRoot() -> URL {
        isolatedHomeTestDirectory("muses-home-retirement-")
    }

    private func input(_ scope: HomeFeedScope) -> HomeDiscoveryInput {
        HomeDiscoveryInput(topArtistNames: [], recentlyPlayedArtistNames: [], likedArtistNames: [],
                           timeBand: .morning, hour: 9, scope: scope)
    }

    private func localSection() -> HomeSection {
        HomeSection(id: "local", title: "Local", kind: .quickPicks, items: [], source: .localLibrary)
    }

    private func webSection(_ channelID: String) -> HomeSection {
        HomeSection(id: "web", title: "Web", kind: .quickPicks, items: [],
                    source: .signedInWeb, accountChannelID: channelID)
    }

    private func snapshot(_ scope: HomeFeedScope, sections: [HomeSection],
                          fetchedAt: Date = .init()) -> HomeSnapshot {
        HomeSnapshot(scope: scope, sections: sections, fetchedAt: fetchedAt,
                     expiresAt: fetchedAt.addingTimeInterval(600))
    }
}
