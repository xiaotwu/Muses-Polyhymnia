import Foundation
import Testing
@testable import Muses

@Suite("Home recommendations and partition lifetime")
struct HomeRecommendationTests {
    @Test("mode cache trees cannot read each other's snapshot")
    @MainActor
    func cacheModeIsolation() {
        let root = isolatedHomeTestDirectory("muses-home-mode-")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let input = HomeDiscoveryInput(
            topArtistNames: [], recentlyPlayedArtistNames: [], likedArtistNames: [],
            timeBand: .morning, hour: 9, scope: .guest)
        let now = Date()
        let snapshot = HomeSnapshot(
            scope: .guest,
            sections: [HomeSection(
                id: "muses-only", title: "Muses", kind: .youTubeCarousel,
                items: [], source: .localLibrary)],
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(600))

        #expect(cache.set(snapshot, for: input, layer: .baseline, mode: .muses))
        #expect(cache.get(for: input, layer: .baseline, mode: .muses) != nil)
        #expect(cache.get(for: input, layer: .baseline, mode: .youtubeMusic) == nil)
        #expect(cache.directoryURL(for: .guest, layer: .baseline, mode: .muses).path
            .contains("/muses-v1/guest/"))
        #expect(cache.directoryURL(for: .guest, layer: .baseline, mode: .youtubeMusic).path
            .contains("/youtube-music-v1/guest/"))
    }

    @Test("Home cache and continuation identity include language and region")
    @MainActor
    func cacheLocaleIsolation() {
        let root = isolatedHomeTestDirectory("muses-home-locale-")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = HomeFeedCache(directory: root)
        let english = HomeDiscoveryInput(
            topArtistNames: [], recentlyPlayedArtistNames: [],
            likedArtistNames: [], timeBand: .morning, hour: 9,
            scope: .guest, language: "en", region: "US")
        let traditional = HomeDiscoveryInput(
            topArtistNames: [], recentlyPlayedArtistNames: [],
            likedArtistNames: [], timeBand: .morning, hour: 9,
            scope: .guest, language: "zh-Hant", region: "TW")
        let now = Date()
        let snapshot = HomeSnapshot(
            scope: .guest,
            sections: [HomeSection(
                id: "source", title: "Source", kind: .youTubeCarousel,
                items: [], source: .localLibrary)],
            fetchedAt: now, expiresAt: now.addingTimeInterval(600))

        #expect(cache.set(snapshot, for: english, layer: .baseline,
                          mode: .muses))
        #expect(cache.get(for: english, layer: .baseline,
                          mode: .muses) != nil)
        #expect(cache.get(for: traditional, layer: .baseline,
                          mode: .muses) == nil)
        #expect(cache.directoryURL(
            for: .guest, layer: .baseline, mode: .muses,
            language: "en", region: "US").path
            != cache.directoryURL(
                for: .guest, layer: .baseline, mode: .muses,
                language: "zh-Hant", region: "TW").path)

        #expect(cache.set(snapshot, for: traditional, layer: .baseline,
                          mode: .muses))
        let legacyLayer = root
            .appendingPathComponent(
                "muses-v1/guest/\(HomeFeedCache.Layer.baseline.directoryName)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(
            at: legacyLayer, withIntermediateDirectories: true)
        let legacyFile = legacyLayer.appendingPathComponent("legacy.json")
        try? Data("legacy".utf8).write(to: legacyFile)
        cache.invalidate(scope: .guest, layer: .baseline,
                         mode: .muses)
        #expect(cache.get(for: english, layer: .baseline,
                          mode: .muses) == nil)
        #expect(cache.get(for: traditional, layer: .baseline,
                          mode: .muses) == nil)
        #expect(!FileManager.default.fileExists(atPath: legacyFile.path))
    }

    @Test("cleared account Web partitions can persist fresh snapshots for a cold reader",
          arguments: [false, true])
    @MainActor
    func webCacheRecoversAfterPrivacyDeletion(openBothLocales: Bool) async throws {
        let root = isolatedHomeTestDirectory("muses-home-recovery-")
        defer { try? FileManager.default.removeItem(at: root) }
        let selectedScope = HomeFeedScope.account(channelID: "UC1234567890123456789012")
        let otherScope = HomeFeedScope.account(channelID: "UC9876543210987654321098")
        func input(_ scope: HomeFeedScope, language: String = "en",
                   region: String = "US") -> HomeDiscoveryInput {
            HomeDiscoveryInput(
                topArtistNames: [], recentlyPlayedArtistNames: [], likedArtistNames: [],
                timeBand: .morning, hour: 9, scope: scope, language: language, region: region)
        }
        let english = input(selectedScope)
        let traditional = input(selectedScope, language: "zh-Hant", region: "TW")
        let other = input(otherScope)
        let guest = input(.guest)
        let now = Date()
        func snapshot(_ input: HomeDiscoveryInput, id: String,
                      source: HomeSource = .localLibrary) -> HomeSnapshot {
            let channel: String?
            if source == .signedInWeb, case .account(let id) = input.scope {
                channel = id
            } else { channel = nil }
            let card = YouTubeDiscoveryCard(
                id: "video:dQw4w9WgXc", title: "Normalized cache fixture", browseEndpoint: nil,
                playEndpoint: HomeCardEndpoint(kind: .video, identifier: "dQw4w9WgXc"),
                availability: .available)
            return HomeSnapshot(
                scope: input.scope,
                sections: [HomeSection(id: id, title: "Fixture", kind: .quickPicks,
                                       items: [.youTube(card)], source: source,
                                       accountChannelID: channel)],
                fetchedAt: now, expiresAt: now.addingTimeInterval(600))
        }
        let baseline: [(input: HomeDiscoveryInput, mode: HomeRecommendationMode, id: String)] = [
            (english, .muses, "baseline-en"),
            (traditional, .muses, "baseline-zh"),
            (guest, .muses, "guest-baseline"),
            (other, .muses, "other-account-baseline")
        ]
        let seed = HomeFeedCache(directory: root)
        for entry in baseline {
            try #require(seed.set(snapshot(entry.input, id: entry.id), for: entry.input,
                                  layer: .baseline, mode: entry.mode))
        }
        for (value, id) in [(english, "old-en"), (traditional, "old-zh"), (other, "other-account")] {
            try #require(seed.set(snapshot(value, id: id, source: .signedInWeb),
                                  for: value, layer: .web, mode: .youtubeMusic))
        }
        await seed.flushPendingWrites()

        let cache = HomeFeedCache(directory: root)
        try #require(cache.get(for: english, layer: .web, mode: .youtubeMusic) != nil)
        if openBothLocales {
            try #require(cache.get(for: traditional, layer: .web, mode: .youtubeMusic) != nil)
        }
        let englishDirectory = cache.directoryURL(
            for: selectedScope, layer: .web, mode: .youtubeMusic, language: "en", region: "US")
        let traditionalDirectory = cache.directoryURL(
            for: selectedScope, layer: .web, mode: .youtubeMusic, language: "zh-Hant", region: "TW")
        let legacy = englishDirectory.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(HomeFeedCache.Layer.web.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot(english, id: "legacy", source: .signedInWeb))
            .write(to: legacy.appendingPathComponent("legacy.json"))

        cache.invalidate(scope: selectedScope, layer: .web, mode: .youtubeMusic)
        #expect(!FileManager.default.fileExists(atPath: englishDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: traditionalDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        // Do not cold-read the deleted target before set: that would recreate
        // its directory and hide the opened handle's recovery failure.
        for (value, id) in [(english, "fresh-en"), (traditional, "fresh-zh")] {
            try #require(cache.set(snapshot(value, id: id, source: .signedInWeb),
                                   for: value, layer: .web, mode: .youtubeMusic))
            #expect(cache.get(for: value, layer: .web, mode: .youtubeMusic)?.value.sections.first?.id == id)
        }
        await cache.flushPendingWrites()
        let cold = HomeFeedCache(directory: root)
        #expect(cold.get(for: english, layer: .web, mode: .youtubeMusic)?.value.sections.first?.id == "fresh-en")
        #expect(cold.get(for: traditional, layer: .web, mode: .youtubeMusic)?.value.sections.first?.id == "fresh-zh")
        #expect(cold.get(for: other, layer: .web, mode: .youtubeMusic)?.value.sections.first?.id == "other-account")
        for entry in baseline {
            #expect(cold.get(for: entry.input, layer: .baseline, mode: entry.mode)?.value.sections.first?.id == entry.id)
        }
    }

    @Test("local ranking is deterministic and contains only supplied tracks")
    func localRankingIsDeterministic() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let favorite = recommendationTrack(
            videoID: "favorite001", artist: "Artist", playCount: 8,
            favorite: true, lastPlayedAt: now.addingTimeInterval(-45 * 86_400))
        let recent = recommendationTrack(
            videoID: "recent00001", artist: "Artist", playCount: 3,
            favorite: false, lastPlayedAt: now.addingTimeInterval(-2 * 86_400))
        let input = LocalRecommendationInput(
            tracks: [recent, favorite], currentHour: 9, timeBand: .morning, now: now)
        let engine = LocalRecommendationEngine()

        let first = engine.plan(for: input)
        let second = engine.plan(for: input)

        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.flatMap(\.items).map(\.homeMediaIdentity)
            == second.flatMap(\.items).map(\.homeMediaIdentity))
        #expect(Set(first.flatMap(\.items).compactMap(\.homeMediaIdentity))
            .isSubset(of: ["video:favorite001", "video:recent00001"]))
        #expect(first.allSatisfy { $0.source == .localLibrary })
    }

    @Test("local recommendations never merge same-name artists without the same stable ID")
    func sameNameArtistsStaySeparate() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let first = recommendationTrack(videoID: "same-name-1", artist: "Atlas", playCount: 12,
                                        favorite: true, lastPlayedAt: now, artistCatalogID: "channel:first")
        let second = recommendationTrack(videoID: "same-name-2", artist: "Atlas", playCount: 11,
                                         favorite: true, lastPlayedAt: now, artistCatalogID: "channel:second")
        let sections = LocalRecommendationEngine().plan(for: .init(
            tracks: [first, second], currentHour: 9, timeBand: .morning, now: now))

        let artistSections = sections.filter { $0.id.hasPrefix("muses:artist:") }
        #expect(artistSections.count == 1)
        #expect(artistSections.first?.items.count == 1)
    }

    private func recommendationTrack(
        videoID: String,
        artist: String,
        playCount: Int,
        favorite: Bool,
        lastPlayedAt: Date?,
        artistCatalogID: String? = nil
    ) -> TrackRecommendationSnapshot {
        TrackRecommendationSnapshot(
            track: TrackSnapshot(
                id: UUID(), title: videoID, artist: artist, albumTitle: nil,
                durationSeconds: 180, youTubeId: videoID, artworkUrl: nil,
                sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false,
                liked: favorite),
            artistCatalogID: artistCatalogID ?? "channel:\(artist.lowercased())",
            playCount: playCount,
            isFavorite: favorite,
            addedAt: Date(timeIntervalSince1970: 1_900_000_000),
            lastPlayedAt: lastPlayedAt)
    }
}
