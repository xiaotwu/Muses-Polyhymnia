import SwiftUI

/// Landscape video browsing retains Track identities and collection-context playback.
struct MusicVideoCollectionView: View {
    let rows: [CollectionTrackRow]
    @Environment(PlaybackService.self) private var playback
    @Environment(YouTubeImportService.self) private var importService: YouTubeImportService?
    private var snapshots: [TrackSnapshot] { rows.map(\.snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Music Videos", "音乐视频"))
                .font(MusesTypography.pageTitle).foregroundStyle(BrandColors.heading)
                .padding(.top, AppleMusicSpacing.browseTitleTop)
            Text(tr("\(rows.count) music videos • YouTube", "\(rows.count) 个音乐视频 • YouTube"))
                .font(.callout).foregroundStyle(.secondary)
            if rows.isEmpty {
                EmptyStateView(icon: "play.rectangle", title: tr("No music videos yet", "还没有音乐视频"),
                    subtitle: tr("Find videos in Search or import a YouTube playlist.", "在搜索中查找视频，或导入 YouTube 歌单。"),
                    actionTitle: tr("Open Search", "打开搜索")) {
                        NotificationCenter.default.post(name: .musesFocusSearch, object: nil)
                    }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 24)], spacing: 24) {
                        ForEach(rows) { row in
                            VStack(alignment: .leading, spacing: 8) {
                                Button { play(row) } label: {
                                    GeometryReader { geometry in
                                        ArtworkView(source: ArtworkSource.resolve(for: row.snapshot),
                                            cornerRadius: 0, glyphSize: 40,
                                            targetSize: geometry.size.width,
                                            targetHeight: geometry.size.height, presentation: .fill)
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                            .clipped()
                                            .overlay(alignment: .bottomTrailing) {
                                                if row.duration.isFinite && row.duration > 0 {
                                                    Text(Duration.seconds(row.duration).formatted(.time(pattern: .minuteSecond)))
                                                        .font(.caption.monospacedDigit()).foregroundStyle(.white)
                                                        .padding(5).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                                                        .padding(8)
                                                }
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tr("Play music video \(row.title)", "播放音乐视频 \(row.title)"))
                                Text(row.title).font(.headline).lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    Text(row.displayArtist).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer()
                                    YouTubeMark(size: 14)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .trackContextMenu(snapshot: row.snapshot, onPlay: { play(row) },
                                              videoContext: snapshots, videoSource: .songs, showsMenuButton: true)
                            .task(id: row.snapshot.youTubeId) {
                                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                                guard !Task.isCancelled, let importService else { return }
                                _ = await importService.songMetadata(videoID: row.snapshot.youTubeId)
                            }
                        }
                    }
                    .padding(.bottom, OverlayChromeMetrics.scrollBottomInset)
                }
            }
        }
        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BrowseBackground())
    }

    private func play(_ row: CollectionTrackRow) {
        playback.playTrack(row.snapshot, context: snapshots, from: .songs)
    }
}
