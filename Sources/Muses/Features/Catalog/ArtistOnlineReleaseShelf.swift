import SwiftUI

/// Native collection scrolling avoids SwiftUI lazy accessibility enumeration.
/// Business actions remain owned by the page and run only when a control is activated.
struct ArtistOnlineReleaseShelf: View {
    let releases: [OnlineReleaseItem]
    let artist: CatalogArtistProjection
    let onOpen: (OnlineReleaseItem) -> Void
    let onPlay: (OnlineReleaseItem) -> Void
    let onShuffle: (OnlineReleaseItem) -> Void
    let onImport: (OnlineReleaseItem) -> Void

    var body: some View {
        ArtistReleaseCollection(releases: releases) { release in
            ArtistOnlineReleaseCard(
                release: release, artist: artist,
                onOpen: onOpen, onPlay: onPlay,
                onShuffle: onShuffle, onImport: onImport
            )
        }
        .frame(height: ArtistReleaseCollection<ArtistOnlineReleaseCard>.cardHeight)
    }

    static func projection(for release: OnlineReleaseItem, artist: CatalogArtistProjection) -> CatalogReleaseProjection {
        .init(stableID: release.stableID, title: release.title,
              artistName: artist.name, artistStableID: artist.stableID,
              artworkURL: release.artworkURL, year: release.year, kind: release.kind,
              cacheState: .fresh, tracks: [])
    }
}

private struct ArtistOnlineReleaseCard: View {
    let release: OnlineReleaseItem
    let artist: CatalogArtistProjection
    let onOpen: (OnlineReleaseItem) -> Void
    let onPlay: (OnlineReleaseItem) -> Void
    let onShuffle: (OnlineReleaseItem) -> Void
    let onImport: (OnlineReleaseItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumObjectView(title: release.title,
                subtitle: release.year.map(String.init) ?? artist.name,
                artwork: .resolve(remoteURL: release.artworkURL), size: 140,
                showsHoverPlay: true,
                onSelect: { onOpen(release) },
                onPlay: { onPlay(release) })
                .catalogReleaseContextMenu(release: ArtistOnlineReleaseShelf.projection(for: release, artist: artist), showsMenuButton: true,
                    canResolvePlayback: true,
                    onOpen: { onOpen(release) },
                    onPlay: { onPlay(release) },
                    onShuffle: { onShuffle(release) })

            Button {
                onImport(release)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                    Text(tr("Import", "导入"))
                }
                .font(MusesTypography.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(BrandColors.accent, in: Capsule())
            }
            .buttonStyle(.fullAreaPlain)
        }
        .frame(width: 140)
    }
}
