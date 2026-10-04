import SwiftUI
import AppKit

/// Shared standard track context menu. Unifies the menu action set across song rows, eliminating lists that lack a context menu or ship a partial one.
///
/// - `track` non-nil (library @Model): enables like toggle / add to playlist / edit info / notes & bookmarks.
/// - `track` nil (snapshot-only: history / search / Home / derived / YouTube): playback-type actions only —
///   never fabricate like/edit/playlist entries for tracks without an @Model.
struct TrackContextMenu: ViewModifier {
    let snapshot: TrackSnapshot?
    var track: Track? = nil
    var playlists: [Playlist] = []
    let onPlay: () -> Void
    var videoContext: [TrackSnapshot] = []
    var videoSource: QueueSource = .search
    var showsMenuButton = false
    var menuButtonAlignment: Alignment = .topTrailing
    var menuButtonTrailingInset: CGFloat = 40
    var menuButtonRegionHeight: CGFloat? = nil
    var onRemoveFromContainer: (() -> Void)? = nil
    @Environment(LibraryService.self) private var library
    @Environment(PlaylistService.self) private var playlistService
    @Environment(YouTubeImportService.self) private var importService
    @State private var showEditTrack = false
    @State private var showTrackNotes = false
    @State private var showCreatePlaylist = false

    func body(content: Content) -> some View {
        if let snapshot {
            content
                .task(id: snapshot.youTubeId) {
                    guard !snapshot.youTubeId.isEmpty else { return }
                    _ = await importService.songMetadata(videoID: snapshot.youTubeId)
                }
                .overlay(alignment: menuButtonAlignment) {
                    if showsMenuButton {
                        ChromeIconMenu(systemName: "ellipsis", title: tr("Options for \(snapshot.title)", "\(snapshot.title) 的选项")) {
                            menu(snapshot)
                        }.padding(8).padding(.trailing, menuButtonTrailingInset)
                            .frame(height: menuButtonRegionHeight, alignment: .topTrailing)
                    }
                }
                .contextMenu { menu(snapshot) }
                .sheet(isPresented: $showEditTrack) {
                    if let t = resolvedTrack(for: snapshot) { EditTrackSheet(track: t) }
                }
                .sheet(isPresented: $showTrackNotes) {
                    if let t = resolvedTrack(for: snapshot) { TrackNotesSheet(track: t) }
                }
                .sheet(isPresented: $showCreatePlaylist) {
                    NewPlaylistSheet(isPresented: $showCreatePlaylist) { name in
                        guard let t = resolvedTrack(for: snapshot) else { return false }
                        let saved = playlistService.create(name: name, initialTrack: t) != nil
                        if !saved { playlistService.clearError() }
                        return saved
                    }
                }
        } else {
            content
        }
    }

    private func menu(_ snapshot: TrackSnapshot) -> some View {
        TrackContextMenuItems(
            snapshot: snapshot,
            track: track,
            playlists: playlists,
            onPlay: onPlay,
            videoContext: videoContext,
            videoSource: videoSource,
            onRemoveFromContainer: onRemoveFromContainer,
            onEditTrack: { showEditTrack = true },
            onTrackNotes: { showTrackNotes = true },
            onCreatePlaylist: { showCreatePlaylist = true }
        )
    }

    private func resolvedTrack(for snapshot: TrackSnapshot) -> Track? {
        track ?? library.track(by: snapshot.id)
    }
}

/// Context menu for a YouTube discovery result that has not necessarily been
/// persisted as a `Track` yet. Queue actions resolve the existing library row
/// (or create the lazy YouTube row) through the shared search service before
/// handing the snapshot to the existing services.
private struct YouTubeEntryContextMenu: ViewModifier {
    let entry: YTDlpBridge.YTDlpPlaylistEntry
    let mediaKind: TrackMediaKind
    let onPlay: () -> Void
    let videoContext: [YTDlpBridge.YTDlpPlaylistEntry]
    let videoSelectedIndex: Int?
    let videoResumeAtMs: Double?
    let videoSource: QueueSource
    var showsMenuButton = false
    var menuButtonAlignment: Alignment = .topTrailing
    var menuButtonTrailingInset: CGFloat = 40
    var menuButtonRegionHeight: CGFloat? = nil
    @State private var saveFailed = false

    @Environment(YouTubeSearchService.self) private var search
    @Environment(PlaybackService.self) private var playback

    private var isCurrent: Bool { playback.transportState.track?.youTubeId == entry.id }

    func body(content: Content) -> some View {
        content.contextMenu { menuItems }
        .overlay(alignment: menuButtonAlignment) {
            if showsMenuButton {
                ChromeIconMenu(systemName: "ellipsis", title: tr("More for \(entry.title)", "更多：\(entry.title)")) {
                    menuItems
                }
                .padding(6)
                .padding(.trailing, menuButtonTrailingInset)
                .frame(height: menuButtonRegionHeight, alignment: .topTrailing)
            }
        }
        .alert(tr("Could not save to Library", "无法保存到资料库", zhHant: "無法儲存至資料庫"), isPresented: $saveFailed) {
            Button(tr("OK", "好", zhHant: "好"), role: .cancel) {}
        } message: {
            Text(tr("Try saving this item again.", "请重试保存此项目。", zhHant: "請重試儲存此項目。"))
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(isCurrent ? playback.primaryAction.title : tr("Play", "播放"),
               systemImage: isCurrent ? playback.primaryAction.symbol : "play.fill") {
            if isCurrent { playback.toggle() } else { onPlay() }
        }
        .disabled(isCurrent && !playback.isPrimaryActionAvailable)
        Button(tr("Play Next", "下一首播放"), systemImage: "text.insert") {
            resolve { playback.queue.playNext($0) }
        }
        Button(tr("Save to Library", "保存到资料库", zhHant: "儲存至資料庫"), systemImage: "plus") {
            Task {
                do { _ = try await search.resolveTrack(entry: entry,
                                                      saveToLibrary: true,
                                                      mediaKindOverride: mediaKind) }
                catch { saveFailed = true }
            }
        }
        Button(tr("Add to Queue", "加入队列"), systemImage: "text.badge.plus") {
            resolve { playback.queue.addToQueue($0) }
        }
        if let url = YouTubeContextMenuLink.watchURL(videoID: entry.id) {
            if let target = YouTubeShareTarget(url: url) {
                YouTubeShareMenu(target: target)
            }
            Button(tr("Copy Link", "复制链接"), systemImage: "link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
            Button {
                resolve { snapshot in
                    PlaybackPresentation.video(snapshot,
                        context: TrackSnapshot.playbackContext(playing: snapshot,
                            youTubeEntries: videoContext, selectedIndex: videoSelectedIndex,
                            mediaKind: mediaKind),
                        source: videoSource, resumeAtMs: videoResumeAtMs, playback: playback)
                }
            } label: {
                Label {
                    Text(tr("Floating video", "悬浮视频"))
                } icon: {
                    YouTubeMark(size: 12)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(tr("Floating video", "悬浮视频"))
        }
    }

    private func resolve(_ action: @escaping @MainActor (TrackSnapshot) -> Void) {
        Task { @MainActor in
            guard let snapshot = try? await search.resolveTrack(
                entry: entry, mediaKindOverride: mediaKind) else { return }
            action(snapshot)
        }
    }
}

enum YouTubeContextMenuLink {
    static func watchURL(videoID: String) -> URL? {
        let trimmed = videoID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(string: "https://music.youtube.com/watch")
        components?.queryItems = [URLQueryItem(name: "v", value: trimmed)]
        return components?.url
    }
}

enum TrackContextMenuPlaybackPolicy {
    static func isCurrent(snapshotID: UUID, currentTrackID: UUID?,
                          queueItemID: UUID?, currentQueueItemID: UUID?,
                          allowsCurrentPlaybackAction: Bool = true) -> Bool {
        guard allowsCurrentPlaybackAction else { return false }
        if let queueItemID { return queueItemID == currentQueueItemID }
        return snapshotID == currentTrackID
    }
}

/// Shared menu content for cards and native Table selections. Presentation state
/// (sheets and dialogs) stays with the owning surface so a transient menu never owns it.
struct TrackContextMenuItems: View {
    let snapshot: TrackSnapshot
    var track: Track? = nil
    var playlists: [Playlist] = []
    let onPlay: () -> Void
    /// Queue menus distinguish repeated occurrences of the same recording.
    var queueItemID: QueueItem.ID? = nil
    /// Historical replay starts its selected context even if the recording is current.
    var allowsCurrentPlaybackAction = true
    var videoContext: [TrackSnapshot] = []
    var videoSource: QueueSource = .search
    var onRemoveFromContainer: (() -> Void)? = nil
    var removeTitle: String = tr("Remove from Playlist", "从歌单移除")
    var showsPlayNext = true
    var showsAddToQueue = true
    var onEditTrack: (() -> Void)? = nil
    var onTrackNotes: (() -> Void)? = nil
    var onCreatePlaylist: (() -> Void)? = nil

    @Environment(PlaybackService.self) private var playback
    @Environment(LibraryService.self) private var library
    @Environment(PlaylistService.self) private var playlistService

    private var isCurrent: Bool {
        TrackContextMenuPlaybackPolicy.isCurrent(
            snapshotID: snapshot.id, currentTrackID: playback.transportState.track?.id,
            queueItemID: queueItemID,
            currentQueueItemID: queueItemID == nil ? nil : playback.queue.current()?.id,
            allowsCurrentPlaybackAction: allowsCurrentPlaybackAction)
    }

    @ViewBuilder
    var body: some View {
        Button(isCurrent ? playback.primaryAction.title : tr("Play", "播放"),
                   systemImage: isCurrent ? playback.primaryAction.symbol : "play.fill") {
                if isCurrent { playback.toggle() } else { onPlay() }
            }
            .disabled(isCurrent && !playback.isPrimaryActionAvailable)
        if showsPlayNext {
            Button(tr("Play Next", "下一首播放"), systemImage: "text.insert") {
                playback.queue.playNext(snapshot)
            }
        }
        if showsAddToQueue {
            Button(tr("Add to Queue", "加入队列"), systemImage: "text.badge.plus") {
                playback.queue.addToQueue(snapshot)
            }
        }
        if let resolvedTrack {
            Divider()
            let _ = library.likedRevision
            let liked = library.isLiked(id: resolvedTrack.id)
            Button(liked ? tr("Unlike", "取消收藏") : tr("Like", "收藏"),
                   systemImage: liked ? "heart.fill" : "heart") {
                library.toggleLike(resolvedTrack)
            }
            if onCreatePlaylist != nil || !playlists.isEmpty {
                Menu(tr("Add to Playlist", "添加到歌单")) {
                    if let onCreatePlaylist {
                        Button(tr("New Playlist…", "新建歌单…"), action: onCreatePlaylist)
                    }
                    if !playlists.isEmpty {
                        if onCreatePlaylist != nil { Divider() }
                        ForEach(playlists, id: \.id) { playlist in
                            Button(playlist.name) {
                                playlistService.addTrack(playlist, track: resolvedTrack)
                            }
                        }
                    }
                }
            }
        }
        Divider()
        if !snapshot.artist.isEmpty && snapshot.artist != "Unknown" {
            Button(tr("Go to Artist", "前往艺人"), systemImage: "person.circle") {
                let artistID = resolvedTrack?.artistCatalogID
                NotificationCenter.default.post(
                    name: .musesNavigateToArtist,
                    object: artistID ?? snapshot.artist
                )
            }
        }
        if let album = resolvedTrack?.albumTitle ?? snapshot.albumTitle, !album.isEmpty {
            Button(tr("Go to Album", "前往专辑"), systemImage: "square.stack") {
                let releaseID = resolvedTrack?.releaseCatalogID
                NotificationCenter.default.post(
                    name: .musesNavigateToRelease,
                    object: releaseID ?? album
                )
            }
        }

        if resolvedTrack != nil {
            if onEditTrack != nil || onTrackNotes != nil {
                Divider()
            }
            if let onEditTrack {
                Button(tr("Edit Info", "编辑信息"), action: onEditTrack)
            }
            if let onTrackNotes {
                Button(tr("Notes & Bookmarks…", "笔记与书签…"), action: onTrackNotes)
            }
        }

        if let onRemoveFromContainer {
            Divider()
            Button(
                removeTitle,
                role: .destructive,
                action: onRemoveFromContainer
            )
        }
        Divider()
        if !snapshot.youTubeId.isEmpty,
           let url = URL(string: "https://youtu.be/\(snapshot.youTubeId)") {
            if let target = YouTubeShareTarget(kind: .video, id: snapshot.youTubeId) {
                YouTubeShareMenu(target: target)
            }
            Button(tr("Copy Link", "复制链接"), systemImage: "link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
            Button {
                PlaybackPresentation.video(snapshot, context: videoContext, source: videoSource, playback: playback)
            } label: {
                Label {
                    Text(tr("Floating video", "悬浮视频"))
                } icon: {
                    YouTubeMark(size: 12)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(tr("Floating video", "悬浮视频"))
        }
    }

    private var resolvedTrack: Track? {
        track ?? library.track(by: snapshot.id)
    }
}

extension View {
    /// Attaches the standard track context menu. Non-nil `track` enables library actions; no menu when `snapshot` is nil (track deleted).
    func trackContextMenu(snapshot: TrackSnapshot?,
                          track: Track? = nil,
                          playlists: [Playlist] = [],
                          onPlay: @escaping () -> Void,
                          videoContext: [TrackSnapshot] = [],
                          videoSource: QueueSource = .search,
                          showsMenuButton: Bool = false,
                          menuButtonAlignment: Alignment = .topTrailing,
                          menuButtonTrailingInset: CGFloat = 40,
        menuButtonRegionHeight: CGFloat? = nil,
                          onRemoveFromContainer: (() -> Void)? = nil) -> some View {
        modifier(TrackContextMenu(snapshot: snapshot, track: track,
                                  playlists: playlists, onPlay: onPlay,
                                  videoContext: videoContext, videoSource: videoSource,
                                  showsMenuButton: showsMenuButton,
                                  menuButtonAlignment: menuButtonAlignment,
                                  menuButtonTrailingInset: menuButtonTrailingInset,
                menuButtonRegionHeight: menuButtonRegionHeight,
                                  onRemoveFromContainer: onRemoveFromContainer))
    }

    /// Adds the standard playback/queue/link menu to a remote YouTube
    /// result while preserving the surface's existing collection-aware play action.
    func youTubeEntryContextMenu(
        entry: YTDlpBridge.YTDlpPlaylistEntry,
        mediaKind: TrackMediaKind = .song,
        videoContext: [YTDlpBridge.YTDlpPlaylistEntry] = [],
        videoSelectedIndex: Int? = nil,
        videoResumeAtMs: Double? = nil,
        videoSource: QueueSource = .search,
        showsMenuButton: Bool = false,
        menuButtonAlignment: Alignment = .topTrailing,
        menuButtonTrailingInset: CGFloat = 40,
        menuButtonRegionHeight: CGFloat? = nil,
        onPlay: @escaping () -> Void
    ) -> some View {
        modifier(YouTubeEntryContextMenu(entry: entry, mediaKind: mediaKind, onPlay: onPlay,
                                        videoContext: videoContext, videoSelectedIndex: videoSelectedIndex,
                                        videoResumeAtMs: videoResumeAtMs, videoSource: videoSource,
                                        showsMenuButton: showsMenuButton, menuButtonAlignment: menuButtonAlignment,
                                        menuButtonTrailingInset: menuButtonTrailingInset,
                                        menuButtonRegionHeight: menuButtonRegionHeight))
    }

    @ViewBuilder
    func youTubeEntryContextMenu(
        card: YouTubeDiscoveryCard,
        videoContext: [YouTubeDiscoveryCard] = [],
        showsMenuButton: Bool = false,
        menuButtonAlignment: Alignment = .topTrailing,
        menuButtonTrailingInset: CGFloat = 40,
        menuButtonRegionHeight: CGFloat? = nil,
        onPlay: @escaping () -> Void
    ) -> some View {
        if let videoID = card.playableVideoID {
            youTubeEntryContextMenu(
                entry: YTDlpBridge.YTDlpPlaylistEntry(
                    id: videoID,
                    title: card.title,
                    uploader: card.uploader,
                    duration: card.duration
                ),
                videoContext: videoContext.compactMap { sibling in
                    guard let id = sibling.playableVideoID else { return nil }
                    return YTDlpBridge.YTDlpPlaylistEntry(id: id, title: sibling.title,
                        uploader: sibling.uploader, duration: sibling.duration)
                },
                showsMenuButton: showsMenuButton,
                menuButtonAlignment: menuButtonAlignment,
                menuButtonTrailingInset: menuButtonTrailingInset,
                menuButtonRegionHeight: menuButtonRegionHeight,
                onPlay: onPlay
            )
        } else {
            self
        }
    }
}
