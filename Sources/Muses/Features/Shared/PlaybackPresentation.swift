import SwiftUI

/// UI routing uses the app-lifetime playback facade and its existing video
/// suspension lifecycle. Every surface shares one floating video session.
@MainActor
enum PlaybackPresentation {
    static func nowPlaying() {
        NotificationCenter.default.post(name: .musesOpenNowPlaying, object: nil)
    }

    static func video(_ snapshot: TrackSnapshot, context: [TrackSnapshot] = [],
                      source: QueueSource = .search, resumeAtMs: Double? = nil,
                      playback: PlaybackService) {
        guard let session = prepareVideo(snapshot, context: context, source: source,
                                         resumeAtMs: resumeAtMs, playback: playback) else { return }
        if session.surface == nil {
            let resume = UserDefaults.standard.object(forKey: PrefKey.resumeAfterVideo) as? Bool ?? true
            session.surface = VideoSurface(session: session, playback: playback, resume: resume)
        }
        session.surface?.float()
    }

    /// Prepare queue and transport independently of the native video window.
    /// The session initialization command reads its saved position before playback starts.
    static func prepareVideo(_ snapshot: TrackSnapshot, context: [TrackSnapshot],
                             source: QueueSource, resumeAtMs: Double? = nil,
                             playback: PlaybackService) -> VideoPlaybackSession? {
        guard !snapshot.youTubeId.isEmpty else { return nil }
        let selectsNewTrack = playback.state.track?.youTubeId != snapshot.youTubeId
        if selectsNewTrack {
            playback.playTrack(snapshot, context: context.isEmpty ? [snapshot] : context,
                               from: source, resumeAtMs: resumeAtMs)
        }
        let session: VideoPlaybackSession
        if let existing = playback.videoSession, existing.videoId == snapshot.youTubeId, !existing.closing {
            session = existing
        } else { session = playback.beginVideoSession(videoId: snapshot.youTubeId) }
        if selectsNewTrack, let resumeAtMs, resumeAtMs.isFinite, resumeAtMs > 0 {
            let position = resumeAtMs / 1000
            let duration = snapshot.durationSeconds
            session.seek(to: duration.isFinite && duration > 0 ? min(position, duration) : position)
        }
        return session
    }
}

struct YouTubeVideoButton: View {
    let entry: YTDlpBridge.YTDlpPlaylistEntry
    @Environment(YouTubeSearchService.self) private var search
    @Environment(PlaybackService.self) private var playback
    @State private var resolving = false
    @State private var failed = false
    @State private var resolutionTask: Task<Void, Never>?

    var body: some View {
        Button {
            resolving = true
            resolutionTask = Task { @MainActor in
                defer { resolving = false }
                do {
                    let snapshot = try await search.resolveTrack(entry: entry)
                    guard !Task.isCancelled else { return }
                    PlaybackPresentation.video(snapshot, playback: playback)
                } catch { if !Task.isCancelled { failed = true } }
            }
        } label: {
            YouTubeMark(size: 14).frame(width: 28, height: 28)
        }
        .buttonStyle(.fullAreaPlain).disabled(resolving)
        .help(tr("Play in floating video window", "在悬浮视频窗口播放"))
        .accessibilityLabel(tr("Play in floating video window", "在悬浮视频窗口播放") + " " + entry.title)
        .onDisappear { resolutionTask?.cancel(); resolving = false }
        .alert(tr("Video unavailable", "视频暂不可用"), isPresented: $failed) {
            Button(tr("OK", "好"), role: .cancel) {}
        }
    }
}
