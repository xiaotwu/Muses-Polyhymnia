import SwiftUI

/// A single tray control for the shared queue's repeat and shuffle settings.
struct TrayPlaybackModeButton: View {
    @Environment(PlaybackService.self) private var playback

    private var mode: TrayPlaybackMode {
        TrayPlaybackMode(repeatMode: playback.queue.repeatMode, shuffle: playback.queue.shuffle)
    }

    var body: some View {
        Button { mode.next.apply(to: playback.queue) } label: {
            Image(systemName: mode.symbol)
                .font(MusesTypography.system(size: 14, weight: .semibold))
                .foregroundStyle(mode == .inOrder ? AnyShapeStyle(.primary) : AnyShapeStyle(BrandColors.accent))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.musesTransport(selected: mode != .inOrder))
        .help(tr("Playback mode", "播放模式") + ": " + mode.title)
        .accessibilityLabel(tr("Playback mode", "播放模式"))
        .accessibilityValue(mode.title)
        .accessibilityHint(tr("Switch to", "切换为") + " " + mode.next.title)
    }
}

enum TrayPlaybackMode {
    case inOrder, repeatOne, repeatAll, shuffle

    init(repeatMode: RepeatMode, shuffle: Bool) {
        // Repeat One governs completion even if another surface left shuffle on.
        if repeatMode == .one { self = .repeatOne }
        else if shuffle { self = .shuffle }
        else { self = repeatMode == .all ? .repeatAll : .inOrder }
    }

    var next: Self {
        switch self {
        case .inOrder: .repeatOne
        case .repeatOne: .repeatAll
        case .repeatAll: .shuffle
        case .shuffle: .inOrder
        }
    }

    var symbol: String {
        switch self {
        case .inOrder: "list.number"
        case .repeatOne: "repeat.1"
        case .repeatAll: "repeat"
        case .shuffle: "shuffle"
        }
    }

    var title: String {
        switch self {
        case .inOrder: tr("In Order", "顺序播放")
        case .repeatOne: tr("Repeat One", "单曲循环")
        case .repeatAll: tr("Repeat All", "列表循环")
        case .shuffle: tr("Shuffle", "随机播放")
        }
    }

    @MainActor
    func apply(to queue: QueueService) {
        if queue.shuffle != (self == .shuffle) { queue.toggleShuffle() }
        let repeatMode: RepeatMode = switch self {
        case .repeatOne: .one
        case .repeatAll: .all
        case .inOrder, .shuffle: .off
        }
        if queue.repeatMode != repeatMode { queue.setRepeat(repeatMode) }
    }
}
