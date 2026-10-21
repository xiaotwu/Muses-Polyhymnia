import SwiftUI
import AppKit

/// A compact native transport surface sharing the main player's controls and semantics.
struct MenuBarPlayerView: View {
    @Environment(YouTubeImportService.self) private var importService: YouTubeImportService?
    @State private var presentationRow: CollectionTrackRow?
    @State private var songMetadata: YTDlpBridge.YTDlpPlaylistEntry?
    @Environment(PlaybackService.self) private var playback
    @Environment(AudioDeviceService.self) private var audioDevices: AudioDeviceService?
    var onOpenMain: () -> Void = {}
    var onQuit: () -> Void = {}
    @State private var isSeeking = false
    @State private var seekPosition = 0.0
    @State private var seekTrackID: UUID?

    private var track: TrackSnapshot? { playback.transportState.track }
    private var duration: Double { max(0, playback.transportState.duration) }
    private var position: Double { isSeeking && seekTrackID == track?.id ? seekPosition : playback.transportState.position }

    private var songInformation: SongDisplayInformation? {
        guard let current = track else { return nil }
        let row = presentationRow.flatMap { $0.snapshot.id == current.id ? $0 : nil }
            ?? CollectionTrackRow(snapshot: current, canonicalIndex: 0)
        return SongDisplayInformation(row: row, metadata: songMetadata)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                if let track {
                    ArtworkView(source: ArtworkSource.resolve(for: track), cornerRadius: 8,
                                glyphSize: 24, targetSize: 44)
                        .frame(width: 44, height: 44)
                } else {
                    MusesMark(size: 44)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: onOpenMain) {
                        DelayedMarqueeText(
                            text: songInformation?.title ?? tr("Not Playing", "未在播放"),
                            font: MusesTypography.song(size: 14, emphasized: true, text: songInformation?.title ?? ""))
                    }
                    .buttonStyle(.fullAreaPlain)
                    .help(tr("Open Muses", "打开 Muses"))
                    .accessibilityLabel(songInformation?.title ?? tr("Not Playing", "未在播放"))
                    .accessibilityHint(tr("Open Muses", "打开 Muses"))
                    DelayedMarqueeText(text: songInformation?.artist ?? "Muses",
                                       font: MusesTypography.song(size: 11, text: songInformation?.artist ?? ""))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44, alignment: .leading)
            }

            VStack(spacing: 2) {
                Slider(value: Binding(get: { min(duration, max(0, position)) }, set: {
                    guard !isSeeking || seekTrackID == track?.id else { return }
                    seekPosition = $0
                    if !isSeeking { playback.seek(to: $0) }
                }),
                       in: 0...max(1, duration), onEditingChanged: { editing in
                    if editing {
                        seekTrackID = track?.id
                        seekPosition = playback.transportState.position
                    } else {
                        if seekTrackID == track?.id { playback.seek(to: seekPosition) }
                        seekTrackID = nil
                    }
                    isSeeking = editing
                })
                .disabled(track == nil || duration <= 0)
                .accessibilityLabel(tr("Playback position", "播放位置", zhHant: "播放位置"))
                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text("−" + formatTime(max(0, duration - position)))
                }
                .font(MusesTypography.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                TrayPlaybackModeButton()
                    .disabled(track == nil)
                Spacer(minLength: 0)
                ChromeIconButton(systemName: "backward.fill", help: tr("Previous", "上一首"),
                                 accessibility: tr("Previous", "上一首")) { playback.previous() }
                    .disabled(track == nil)
                Spacer(minLength: 0)
                Button { playback.toggle() } label: {
                    Image(systemName: playback.primaryAction.symbol)
                        .font(MusesTypography.system(size: 24, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.fullAreaPlain)
                .modifier(PlaybackCoreSurface()).help(playback.primaryAction.title)
                .disabled(!playback.isPrimaryActionAvailable)
                .accessibilityLabel(playback.primaryAction.title)
                Spacer(minLength: 0)
                ChromeIconButton(systemName: "forward.fill", help: tr("Next", "下一首"),
                                 accessibility: tr("Next", "下一首")) { playback.next() }
                    .disabled(track == nil)
                Spacer(minLength: 0)
                playerOptions
            }
            .environment(\.groupedChromeActions, true)

            if let audioDevices, audioDevices.lastError != nil {
                Text(tr("Unable to switch audio output. Try again.", "无法切换音频输出，请重试。", zhHant: "無法切換音訊輸出，請重試。"))
                    .font(MusesTypography.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 294)
        .frame(minHeight: 154)
        .foregroundStyle(BrandColors.textPrimary)
        .tint(BrandColors.accent)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: track?.id) {
            songMetadata = nil
            presentationRow = nil
            guard let current = track, let importService else { return }
            presentationRow = importService.songPresentationRow(for: current)
            let metadata = await importService.songMetadata(videoID: current.youTubeId)
            guard !Task.isCancelled, track?.id == current.id else { return }
            songMetadata = metadata
        }
        .onAppear { audioDevices?.refresh() }
        .onChange(of: track?.id) { _, _ in
            if !isSeeking { seekTrackID = nil }
        }
        .onDisappear { isSeeking = false; seekTrackID = nil }
    }

    private var playerOptions: some View {
        ChromeIconMenu(systemName: "ellipsis", title: tr("Player options", "播放器选项")) {
            if let audioDevices {
                Menu {
                    ForEach(NowPlayingOutputDevicePolicy.visibleDevices(audioDevices.devices)) { device in
                        Button { _ = audioDevices.setDefault(device.id) } label: {
                            Label(device.name, systemImage: device.id == audioDevices.defaultDeviceID ? "checkmark" : "hifispeaker")
                        }
                    }
                } label: {
                    Label(tr("Audio output", "音频输出"), systemImage: "speaker.wave.2")
                }
            }
            if let id = track?.youTubeId, let url = URL(string: "https://youtu.be/\(id)") {
                ShareLink(item: url) {
                    Label(tr("Share", "分享"), systemImage: "square.and.arrow.up")
                }
            }
            Divider()
            Button(action: onQuit) {
                Label(tr("Quit", "退出"), systemImage: "power")
            }
        }
        .labelStyle(.titleAndIcon)
    }

    private func formatTime(_ value: Double) -> String {
        let seconds = value.isFinite ? max(0, Int(value)) : 0
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
