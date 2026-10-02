import SwiftUI

/// Resume uses persisted episode progress and the existing playback facade.
struct PodcastContinueShelf: View {
    @Environment(PodcastLibraryService.self) private var podcasts
    @Environment(YouTubeSearchService.self) private var search
    @Environment(PlaybackService.self) private var playback
    @State private var episodes: [PodcastEpisodeSnapshot] = []
    @State private var showTitles: [String: String] = [:]
    @State private var preparingVideoID: String?
    @State private var galleryPreview: GalleryMediaPreview?
    @State private var failure: String?

    var body: some View {
        Group {
            if !episodes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: tr("Continue listening", "继续收听"),
                                  subtitle: tr("Podcasts · saved progress", "播客 · 已保存进度"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 18) {
                            ForEach(episodes, id: \.videoID) { episode in
                                VStack(alignment: .leading, spacing: 8) {
                                    AlbumObjectView(title: episode.title,
                                                    subtitle: showTitles[episode.showCatalogID] ?? tr("Podcast", "播客"),
                                                    artwork: .resolve(remoteURL: episode.artworkURL, youTubeId: episode.videoID),
                                                    size: 180, role: .browse, isYouTube: true,
                                                    showsHoverPlay: true,
                                                    onSelect: { openPreview(episode) },
                                                    onPlay: { preparingVideoID = episode.videoID })
                                    Text(tr("Resume at \(position(episode.lastPositionMs))",
                                            "从 \(position(episode.lastPositionMs)) 继续"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .disabled(preparingVideoID != nil)
                            }
                        }
                        .padding(.horizontal, AppleMusicTokens.contentPaddingX)
                    }
                    if let failure {
                        Text(failure).font(.callout).foregroundStyle(.secondary)
                            .padding(.horizontal, AppleMusicTokens.contentPaddingX)
                    }
                }
            }
        }
        .sheet(item: $galleryPreview) { GalleryMediaPreviewSheet(preview: $0) }
        .task(id: podcasts.revision) {
            let shows = podcasts.followedShows()
            showTitles = Dictionary(uniqueKeysWithValues: shows.map { ($0.catalogID, $0.title) })
            var seen = Set<String>()
            episodes = Array(shows.flatMap { podcasts.episodes(showCatalogID: $0.catalogID) }
                .filter { !$0.completed && $0.lastPositionMs > 0 && $0.availability == .available && seen.insert($0.videoID).inserted }
                .prefix(12))
        }
        .task(id: preparingVideoID) {
            guard let id = preparingVideoID else { return }
            defer { if preparingVideoID == id { preparingVideoID = nil } }
            guard let episode = episodes.first(where: { $0.videoID == id }) else { return }
            let entries = episodes.map {
                YTDlpBridge.YTDlpPlaylistEntry(id: $0.videoID, title: $0.title,
                    uploader: showTitles[$0.showCatalogID], duration: $0.durationMs.map { Double($0) / 1000 })
            }
            guard let entry = entries.first(where: { $0.id == id }) else { return }
            do {
                let snapshot = try await search.resolveTrack(entry: entry, mediaKindOverride: .podcastEpisode)
                guard !Task.isCancelled else { return }
                playback.playTrack(snapshot, context: TrackSnapshot.playbackContext(
                    playing: snapshot, youTubeEntries: entries, mediaKind: .podcastEpisode),
                    from: .podcast, resumeAtMs: episode.lastPositionMs)
                failure = nil
            } catch {
                guard !Task.isCancelled else { return }
                failure = tr("This episode could not be prepared. Try again.", "无法准备这集播客，请重试。")
            }
        }
    }

    private func openPreview(_ episode: PodcastEpisodeSnapshot) {
        galleryPreview = .init(id: episode.videoID, title: episode.title,
            subtitle: (showTitles[episode.showCatalogID] ?? tr("Podcast", "播客"))
                + " · " + tr("Resume at \(position(episode.lastPositionMs))", "从 \(position(episode.lastPositionMs)) 继续"),
            artwork: .resolve(remoteURL: episode.artworkURL, youTubeId: episode.videoID),
            duration: episode.durationMs.map { Double($0) / 1000 },
            onPlay: { preparingVideoID = episode.videoID })
    }

    private func position(_ milliseconds: Double) -> String {
        let seconds = max(0, Int(milliseconds / 1000))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
