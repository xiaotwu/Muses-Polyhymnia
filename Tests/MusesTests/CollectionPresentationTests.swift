import AppKit
import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Collection presentation")
struct CollectionPresentationTests {
    @Test("accessible pages preserve all 507 sorted collection occurrences")
    func accessiblePaging() {
        let rows = (0..<507).map { index in
            CollectionTrackRow(snapshot: TrackSnapshot(
                id: UUID(), title: String(format: "%04d", index),
                artist: "Synthetic", albumTitle: nil, durationSeconds: 1,
                youTubeId: String(format: "%011d", index), artworkUrl: nil,
                sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false),
                canonicalIndex: index)
        }
        let count = CollectionTablePaging.pageCount(rowCount: rows.count, pageSize: 25)
        #expect(count == 21)
        let presented = (0..<count).flatMap {
            CollectionTablePaging.rows(rows, page: $0, pageSize: 25)
        }
        #expect(presented.map(\.id) == rows.map(\.id))
        #expect(CollectionTablePaging.rows(rows, page: 20, pageSize: 25).count == 7)
    }

    @Test("Collection pages share the leading page-header rhythm")
    func collectionHeaderRhythm() {
        #expect(AppleMusicSpacing.pageHorizontal == 40)
        #expect(AppleMusicSpacing.browseTitleTop == 16)
        #expect(AppleMusicSpacing.headerToPrimary == 28)
        #expect(AppleMusicSpacing.related == 20)
        #expect(AppleMusicSpacing.section == 34)
        #expect(AppleMusicTokens.pageTitleSize == 34)
    }

    @Test("Songs canonical order is title A-Z and deterministic")
    func songsCanonicalOrder() {
        let tracks = [
            Track(title: "Zulu", artist: "B", youTubeId: "z"),
            Track(title: "Alpha", artist: "Z", youTubeId: "a2"),
            Track(title: "Alpha", artist: "A", youTubeId: "a1"),
            Track(title: "Delta", artist: "C", youTubeId: "d1")
        ]

        let rows = CollectionTrackRow.songs(from: tracks)

        #expect(rows.map(\.title) == ["Alpha", "Alpha", "Delta", "Zulu"])
        #expect(rows.map(\.artist) == ["A", "Z", "C", "B"])
        #expect(rows.map(\.canonicalIndex) == [0, 1, 2, 3])
        #expect(rows.allSatisfy { !$0.snapshot.youTubeId.isEmpty })
    }

    @Test("Legacy video-backed tracks remain ordinary Songs rows")
    func videoBackedTracksRemainSongs() {
        let video = Track(
                        title: "Wide Video",
            artist: "Artist",
            youTubeId: "video-id",
            mediaKind: .musicVideo
        )

        let rows = CollectionTrackRow.songs(from: [video])

        #expect(rows.map(\.id) == [video.id])
        #expect(video.mediaKind == .musicVideo)
    }

    @Test("Playlist rows use persisted PlaylistItem order")
    func playlistCanonicalOrder() {
        let first = Track(title: "First", artist: "A", youTubeId: "first")
        let second = Track(title: "Second", artist: "B", youTubeId: "second")
        let item0 = PlaylistItem(order: 0, track: first)
        let item1 = PlaylistItem(order: 1, track: second)

        let rows = CollectionTrackRow.playlist(from: [item1, item0])

        #expect(rows.map(\.title) == ["First", "Second"])
        #expect(rows.map(\.canonicalIndex) == [0, 1])
        #expect(rows.map(\.id) == [item0.id, item1.id])
        #expect(rows.map(\.snapshot.id) == [first.id, second.id])
    }

    @Test("Visual table sorting does not rewrite canonical order")
    func visualSortPreservesCanonicalOrder() {
        let rows = [
            makeRow(title: "B", artist: "Zulu", canonicalIndex: 0),
            makeRow(title: "A", artist: "Alpha", canonicalIndex: 1)
        ]

        let visuallySorted = CollectionTrackSort.rows(
            rows,
            using: [KeyPathComparator(\.artist, comparator: .localizedStandard)]
        )

        #expect(visuallySorted.map(\.title) == ["A", "B"])
        #expect(rows.map(\.title) == ["B", "A"])
        #expect(rows.map(\.canonicalIndex) == [0, 1])
    }

    @Test("Sort feedback follows the actual primary and secondary comparators")
    func sortFeedbackTracksComparatorPriority() {
        withLanguage("en") {
            let rows = [("Old", 10.0), ("Zulu", 20.0), ("Alpha", 20.0)].enumerated().map { index, item in
                CollectionTrackRow(
                    snapshot: makeRow(title: item.0, artist: "Artist", canonicalIndex: index).snapshot,
                    canonicalIndex: index, addedAt: Date(timeIntervalSince1970: item.1))
            }
            let originalRows = rows
            var comparators = [
                KeyPathComparator(\CollectionTrackRow.addedAtSortValue, order: .reverse),
                KeyPathComparator(\CollectionTrackRow.title, comparator: .localizedStandard)
            ]

            #expect(CollectionTrackSort.rows(rows, using: comparators).map(\.canonicalIndex) == [2, 1, 0])
            #expect(CollectionTableSortFeedback.description(for: comparators)
                    == "Date Added: Descending; then Title: Ascending")

            comparators[0].order = .forward
            #expect(CollectionTrackSort.rows(rows, using: comparators).map(\.canonicalIndex) == [0, 2, 1])
            #expect(CollectionTableSortFeedback.description(for: comparators)
                    == "Date Added: Ascending; then Title: Ascending")
            #expect(rows == originalRows)
            #expect(rows.map(\.canonicalIndex) == [0, 1, 2])
        }
    }

    @Test("Every native collection column has an identifiable sort field")
    func sortFeedbackNamesAllColumns() {
        withLanguage("en") {
            let fields: [(KeyPathComparator<CollectionTrackRow>, String)] = [
                (KeyPathComparator(\.canonicalIndex), "Collection order"),
                (KeyPathComparator(\.title, comparator: .localizedStandard), "Title"),
                (KeyPathComparator(\.artist, comparator: .localizedStandard), "Artist"),
                (KeyPathComparator(\.album, comparator: .localizedStandard), "Album"),
                (KeyPathComparator(\.yearSortValue), "Year"),
                (KeyPathComparator(\.genreSortValue, comparator: .localizedStandard), "Genre"),
                (KeyPathComparator(\.duration), "Time"),
                (KeyPathComparator(\.addedAtSortValue), "Date Added"),
                (KeyPathComparator(\.playCount), "Plays")
            ]
            for (comparator, name) in fields {
                #expect(CollectionTableSortFeedback.description(for: [comparator]) == "\(name): Ascending")
                var descending = comparator
                descending.order = .reverse
                #expect(CollectionTableSortFeedback.description(for: [descending]) == "\(name): Descending")
            }
        }
    }

    @Test("Empty and unfamiliar comparator lists do not claim the default Title order")
    func sortFeedbackKeepsHonestFallbacks() {
        withLanguage("en") {
            let rows = [makeRow(title: "Alpha", artist: "A", canonicalIndex: 0),
                        makeRow(title: "Zulu", artist: "B", canonicalIndex: 1)]
            #expect(CollectionTrackSort.rows(rows, using: []) == rows)
            #expect(CollectionTableSortFeedback.description(for: []) == "Original song order")

            let unfamiliar = KeyPathComparator(\CollectionTrackRow.snapshot.title,
                                              comparator: .localizedStandard, order: .reverse)
            let comparators = [unfamiliar, KeyPathComparator(\CollectionTrackRow.playCount)]
            #expect(CollectionTrackSort.rows(rows, using: comparators).map(\.canonicalIndex) == [1, 0])
            #expect(CollectionTableSortFeedback.description(for: comparators)
                    == "Custom field: Descending; then Plays: Ascending")
            #expect(rows.map(\.canonicalIndex) == [0, 1])
        }
    }

    @Test("Existing sort criteria translate immediately after a language change")
    func sortFeedbackFollowsLanguageChanges() {
        let comparators = [KeyPathComparator(\CollectionTrackRow.playCount, order: .reverse),
                           KeyPathComparator(\CollectionTrackRow.artist, comparator: .localizedStandard)]
        let descriptions = ["en", "zh-Hans", "zh-Hant", "en"].map { language in
            withLanguage(language) { CollectionTableSortFeedback.description(for: comparators) }
        }
        #expect(descriptions == ["Plays: Descending; then Artist: Ascending",
                                 "播放次数：降序；其次艺术家：升序",
                                 "播放次數：降序；其次藝術家：升序",
                                 "Plays: Descending; then Artist: Ascending"])
        #expect(withLanguage("zh-Hans") { CollectionTableSortFeedback.description(for: []) }
                == "原始歌曲顺序")
        #expect(withLanguage("zh-Hant") { CollectionTableSortFeedback.description(for: []) }
                == "原始歌曲順序")
    }

    @Test("Default sorts distinguish Songs from playlists")
    func defaultSorts() {
        let songComparator = CollectionTableDefaultSort.titleAZ.comparators
        let playlistComparator = CollectionTableDefaultSort.playlistOrder.comparators
        let rows = [
            makeRow(title: "B", artist: "A", canonicalIndex: 0),
            makeRow(title: "A", artist: "B", canonicalIndex: 1)
        ]

        #expect(CollectionTrackSort.rows(rows, using: songComparator).map(\.title) == ["A", "B"])
        #expect(CollectionTrackSort.rows(rows, using: playlistComparator).map(\.title) == ["B", "A"])
    }

    @Test("Artist sorting follows verified displayed credits without changing collection truth")
    func enrichedArtistSortPreservesCollection() {
        let cache = SongCreditCache()
        let originals = [
            makeRow(title: "First", artist: "Playlist owner", canonicalIndex: 0),
            makeRow(title: "Second", artist: "Playlist owner", canonicalIndex: 1)
        ]
        for row in originals { cache.recordOwner("Playlist owner", videoID: row.snapshot.youTubeId) }
        cache.store(.init(id: originals[0].snapshot.youTubeId, title: "First",
                          uploader: "Publisher", artist: "Zulu"))
        cache.store(.init(id: originals[1].snapshot.youTubeId, title: "Second",
                          uploader: "Alpha publisher"))
        let comparator = [KeyPathComparator(\CollectionTrackRow.artist, comparator: .localizedStandard)]
        let displayed = CollectionTrackSort.presentationRows(originals, using: comparator, credits: cache)
        #expect(displayed.map(\.title) == ["Second", "First"])
        #expect(displayed.map(\.artist) == ["Alpha publisher", "Zulu"])
        #expect(displayed.map(\.artist) == displayed.map(\.displayArtist))
        #expect(displayed.map(\.canonicalIndex) == [1, 0])
        #expect(originals.map(\.snapshot.artist) == ["Playlist owner", "Playlist owner"])
        #expect(originals.map(\.canonicalIndex) == [0, 1])
        #expect(displayed.map(\.snapshot) == [originals[1].snapshot, originals[0].snapshot])

        cache.store(.init(id: originals[0].snapshot.youTubeId, title: "First", artist: "Aardvark"))
        let updated = CollectionTrackSort.presentationRows(originals, using: comparator, credits: cache)
        #expect(updated.map(\.title) == ["First", "Second"])
        #expect(displayed.map(\.artist) == ["Alpha publisher", "Zulu"])
    }

    @Test("Overlapping strip reserves tilt clearance and mounts only nearby covers")
    func responsiveDeckGeometry() {
        let roomy = CollectionDeckGeometry.resolve(containerWidth: 980, containerHeight: 760)
        let compact = CollectionDeckGeometry.resolve(containerWidth: 560, containerHeight: 760)
        let compactHeight = CollectionDeckGeometry.resolve(containerWidth: 980, containerHeight: 600)

        #expect(roomy.radius >= 2)
        #expect(compact.radius == 2)
        #expect(compactHeight.radius >= roomy.radius)
        #expect(CollectionDeckProjection.visibleIndices(count: 100, position: 50, radius: roomy.radius).count <= 13)
        #expect(CollectionDeckProjection.visibleIndices(count: 100, position: 50, radius: compact.radius).count == 5)
        #expect(roomy.cardHeight > roomy.cardWidth)
        #expect(abs(roomy.cardWidth / roomy.cardHeight - 0.75) < 0.001)
        #expect(abs(compact.cardWidth / compact.cardHeight - 0.75) < 0.001)
        #expect(abs(compactHeight.cardWidth / compactHeight.cardHeight - 0.75) < 0.001)
        #expect(abs(roomy.footerHeight * 3 - roomy.cardWidth) < 0.001)
        #expect(roomy.cardWidth > 180)
        #expect(compactHeight.cardWidth > 136)
        #expect(roomy.lowerFanClearance == 24)
        #expect(compact.lowerFanClearance == 24)
        #expect(roomy.viewportHeight >= roomy.cardHeight + CollectionDeckScrubberMetrics.thumbHeight)
        let wide = CollectionDeckGeometry.resolve(containerWidth: 1_800, containerHeight: 1_160)
        #expect(wide.cardWidth > roomy.cardWidth)
        #expect(wide.radius > compact.radius)
        #expect(wide.spread < wide.cardWidth)
        #expect(abs(wide.cardWidth / wide.cardHeight - 0.75) < 0.001)
        #expect(wide.cardWidth > 260)
        let widthsAndGeometry: [(CGFloat, CollectionDeckGeometry)] = [(980, roomy), (1_800, wide)]
        for (width, geometry) in widthsAndGeometry {
            #expect(CGFloat(geometry.radius) * geometry.spread + geometry.cardWidth / 2
                    >= (width - 96) / 2)
            #expect(geometry.radius <= 6)
        }
    }

    @Test("Proportional card footers keep song credits within compact and roomy cards")
    func proportionalFooterGeometry() {
        let compact = CollectionDeckFooterMetrics.resolve(height: 56, usesProportionalFooter: true)
        #expect(compact.titleLineLimit == 1)
        #expect(!compact.showsAlbum)
        #expect(compact.verticalPadding >= 2 && compact.verticalPadding <= 8)

        let regular = CollectionDeckFooterMetrics.resolve(height: 75, usesProportionalFooter: true)
        #expect(regular.titleLineLimit == 2)
        #expect(!regular.showsAlbum)

        let roomy = CollectionDeckFooterMetrics.resolve(height: 100, usesProportionalFooter: true)
        #expect(roomy.titleLineLimit == 2)
        #expect(roomy.showsAlbum)

        let wall = CollectionDeckFooterMetrics.resolve(height: 86, usesProportionalFooter: false)
        #expect(wall.titleLineLimit == 2)
        #expect(wall.showsAlbum)
        #expect(wall.verticalPadding == 10)
    }

    @Test("Scaled proportional footers keep native title and artist line boxes inside the card")
    func scaledFooterGeometry() throws {
        let layoutManager = NSLayoutManager()
        for scale: CGFloat in [1, 1.15] {
            for height: CGFloat in [56, 75, 100] {
                let footer = CollectionDeckFooterMetrics.resolve(
                    height: height, usesProportionalFooter: true, textScale: scale
                )
                #expect(footer.verticalPadding >= 2 && footer.verticalPadding <= 10)
                for (titleName, creditName) in [
                    ("AvenirNext-DemiBold", "AvenirNext-Regular"),
                    ("PingFangSC-Medium", "PingFangSC-Regular")
                ] {
                    let title = try #require(NSFont(name: titleName, size: 14 * scale))
                    let artist = try #require(NSFont(name: creditName, size: 12 * scale))
                    let album = try #require(NSFont(name: creditName, size: 11 * scale))
                    let titleHeight = layoutManager.defaultLineHeight(for: title) * CGFloat(footer.titleLineLimit)
                    let artistHeight = layoutManager.defaultLineHeight(for: artist)
                    let albumHeight = footer.showsAlbum ? layoutManager.defaultLineHeight(for: album) + 4 : 0
                    #expect(titleHeight + artistHeight + albumHeight + 4 + footer.verticalPadding * 2 <= height)
                }
            }
        }

        let compact = CollectionDeckFooterMetrics.resolve(height: 56, usesProportionalFooter: true)
        let compactLarge = CollectionDeckFooterMetrics.resolve(
            height: 56, usesProportionalFooter: true, textScale: 1.15
        )
        #expect(compactLarge.titleLineLimit == 1)
        #expect(!compactLarge.showsAlbum)
        #expect(compactLarge.verticalPadding < compact.verticalPadding)
        let regularLarge = CollectionDeckFooterMetrics.resolve(
            height: 75, usesProportionalFooter: true, textScale: 1.15
        )
        #expect(regularLarge.titleLineLimit == 1)
        #expect(!regularLarge.showsAlbum)
        #expect(CollectionDeckFooterMetrics.resolve(height: 86, usesProportionalFooter: false, textScale: 1.15)
                == CollectionDeckFooterMetrics.resolve(height: 86, usesProportionalFooter: false))
    }

    @Test("Deck projection clamps first and last collection boundaries")
    func deckProjectionBoundaries() {
        #expect(CollectionDeckProjection.visibleIndices(count: 0, position: 0, radius: 4).isEmpty)
        #expect(CollectionDeckProjection.visibleIndices(count: 20, position: -8, radius: 4) == [0, 1, 2, 3, 4])
        #expect(CollectionDeckProjection.visibleIndices(count: 20, position: 99, radius: 4) == [15, 16, 17, 18, 19])
    }

    @Test("Deck scrubber stays compact and maps the full collection")
    func deckScrubberGeometry() {
        #expect(CollectionDeckScrubberMetrics.width(availableWidth: 980) == 460)
        #expect(CollectionDeckScrubberMetrics.width(availableWidth: 548) == 328)
        #expect(CollectionDeckScrubberMetrics.trackHeight == 4)
        #expect(CollectionDeckScrubberMetrics.thumbWidth == 46)
        #expect(CollectionDeckScrubberMetrics.thumbHeight == 24)
        #expect(CollectionDeckScrubberMetrics.stageClearance >= CollectionDeckScrubberMetrics.thumbHeight)
        #expect(CollectionDeckScrubberMetrics.playerClearance
                > OverlayChromeMetrics.scrollBottomInset)

        let width: CGFloat = 500
        #expect(CollectionDeckScrubberMetrics.thumbCenterX(position: 0, itemCount: 20, width: width) == 23)
        #expect(CollectionDeckScrubberMetrics.thumbCenterX(position: 19, itemCount: 20, width: width) == 477)
        #expect(CollectionDeckScrubberMetrics.thumbCenterX(position: -8, itemCount: 20, width: width) == 23)
        #expect(CollectionDeckScrubberMetrics.thumbCenterX(position: 99, itemCount: 20, width: width) == 477)
        #expect(CollectionDeckScrubberMetrics.position(locationX: 23, itemCount: 20, width: width) == 0)
        #expect(CollectionDeckScrubberMetrics.position(locationX: 477, itemCount: 20, width: width) == 19)
        #expect(CollectionDeckScrubberMetrics.position(locationX: -40, itemCount: 20, width: width) == 0)
        #expect(CollectionDeckScrubberMetrics.position(locationX: 540, itemCount: 20, width: width) == 19)
        #expect(CollectionDeckScrubberMetrics.position(locationX: 250, itemCount: 1, width: width) == 0)
    }

    @Test("Primary deck activation is immediate across pointer, keyboard, and VoiceOver")
    func deckActivationSemantics() {
        #expect(CollectionDeckActivationPolicy.isPrimaryActivation(.pointer))
        #expect(CollectionDeckActivationPolicy.isPrimaryActivation(.keyboard))
        #expect(CollectionDeckActivationPolicy.isPrimaryActivation(.accessibility))
        #expect(!CollectionDeckActivationPolicy.isPrimaryActivation(.contextMenu))
    }

    @Test("Ambient-fit artwork keeps its explicit presentation policy")
    func ambientArtworkPresentation() {
        #expect(ArtworkPresentation.fitOnAmbient != ArtworkPresentation.fill)
    }

    @Test("Deck event monitor stops when a parent overlay disables browsing")
    func deckEventMonitorHonorsInheritedEnabledState() {
        #expect(CollectionDeckInputPolicy.acceptsEvents(
            stageEnabled: true,
            environmentEnabled: true
        ))
        #expect(!CollectionDeckInputPolicy.acceptsEvents(
            stageEnabled: true,
            environmentEnabled: false
        ))
        #expect(!CollectionDeckInputPolicy.acceptsEvents(
            stageEnabled: false,
            environmentEnabled: true
        ))
    }

    @Test("Velocity-aware deck snapping stays integral and bounded")
    func deckProjectedSnap() {
        let forward = CollectionDeckProjection.projectedIndex(
            startPosition: 10,
            translation: -86,
            predictedTranslation: -1_000,
            spread: 86,
            count: 20
        )
        let beforeFirst = CollectionDeckProjection.projectedIndex(
            startPosition: 1,
            translation: 500,
            predictedTranslation: 900,
            spread: 86,
            count: 20
        )
        let afterLast = CollectionDeckProjection.projectedIndex(
            startPosition: 18,
            translation: -500,
            predictedTranslation: -900,
            spread: 86,
            count: 20
        )

        #expect(forward == 17)
        #expect(beforeFirst == 0)
        #expect(afterLast == 19)
    }

    @Test("Expansion gesture is directional and rejects horizontal deck motion")
    func expansionGestureDirection() {
        #expect(CollectionDeckProjection.acceptsVerticalGesture(
            translation: CGSize(width: 8, height: -52),
            direction: .up
        ))
        #expect(CollectionDeckProjection.acceptsVerticalGesture(
            translation: CGSize(width: 4, height: 56),
            direction: .down
        ))
        #expect(!CollectionDeckProjection.acceptsVerticalGesture(
            translation: CGSize(width: 70, height: -55),
            direction: .up
        ))
        #expect(!CollectionDeckProjection.acceptsVerticalGesture(
            translation: CGSize(width: 4, height: 40),
            direction: .down
        ))
        #expect(!CollectionDeckProjection.acceptsVerticalGesture(
            translation: CGSize(width: 4, height: 56),
            direction: .up
        ))
    }

    @Test("Collection motion stays brief and honors Reduce Motion")
    func collectionMotionPolicy() {
        #expect(MusesMotion.collectionDeckSnap >= 0.12)
        #expect(MusesMotion.collectionDeckSnap <= 0.24)
        #expect(MusesMotion.collectionListTransition >= 0.26)
        #expect(MusesMotion.collectionListTransition <= 0.32)
        #expect(MusesMotion.collectionCardActivation == 0.30)
        #expect(MusesMotion.collectionDeckAnimation(reduceMotion: true) == nil)
        #expect(MusesMotion.collectionListAnimation(reduceMotion: true) == nil)
        #expect(MusesMotion.collectionCardAnimation(reduceMotion: true) == nil)
        #expect(MusesMotion.collectionDeckAnimation(reduceMotion: false) != nil)
        #expect(MusesMotion.collectionListAnimation(reduceMotion: false) != nil)
        #expect(MusesMotion.collectionCardAnimation(reduceMotion: false) != nil)
    }

    private func withLanguage<T>(_ language: String, _ operation: () -> T) -> T {
        let originalLanguage = UserDefaults.standard.object(forKey: PrefKey.language)
        let originalObservedLanguage = LanguagePreferences.shared.rawValue
        defer {
            if let originalLanguage {
                UserDefaults.standard.set(originalLanguage, forKey: PrefKey.language)
            } else {
                UserDefaults.standard.removeObject(forKey: PrefKey.language)
            }
            LanguagePreferences.shared.update(originalObservedLanguage)
        }
        UserDefaults.standard.set(language, forKey: PrefKey.language)
        LanguagePreferences.shared.update(language)
        return operation()
    }

    private func makeRow(title: String, artist: String, canonicalIndex: Int) -> CollectionTrackRow {
        CollectionTrackRow(
            snapshot: TrackSnapshot(
                id: UUID(),
                title: title,
                artist: artist,
                albumTitle: nil,
                durationSeconds: 120,
                                youTubeId: UUID().uuidString,
                                artworkUrl: nil,
                sampleRate: nil,
                bitDepth: nil,
                codec: nil,
                isLossless: false
            ),
            canonicalIndex: canonicalIndex
        )
    }
}
