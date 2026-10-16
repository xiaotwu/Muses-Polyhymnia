import Foundation
import SwiftUI

struct LyricsSearchRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let query: String

    init(query: String, id: UUID = UUID()) {
        self.id = id
        self.query = query
    }
}

enum LyricsSearchHost: Equatable, Sendable {
    case root
    case equalizer
}

@MainActor
enum LyricsSearchPresentation {
    nonisolated static func host(audioInfoPresented: Bool, equalizerPresented: Bool) -> LyricsSearchHost {
        audioInfoPresented && equalizerPresented ? .equalizer : .root
    }

    /// Each rendered binding owns one request, not a later replacement or another host's sheet.
    static func binding(
        request: Binding<LyricsSearchRequest?>,
        host: LyricsSearchHost,
        activeHost: @escaping @MainActor () -> LyricsSearchHost,
        isBlocked: @escaping @MainActor () -> Bool = { false }
    ) -> Binding<LyricsSearchRequest?> {
        let requestID = request.wrappedValue?.id
        return Binding(
            get: {
                guard activeHost() == host, !isBlocked(),
                      let current = request.wrappedValue, current.id == requestID else { return nil }
                return current
            },
            set: { value in
                guard value == nil, activeHost() == host, !isBlocked(),
                      let requestID, request.wrappedValue?.id == requestID else { return }
                request.wrappedValue = nil
            }
        )
    }
}

/// The same content is presented by either the root or the already-open EQ editor.
struct LyricsSearchSheet: View {
    let request: LyricsSearchRequest
    @Environment(PlaybackService.self) private var playback
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let track = playback.transportState.track {
            LyricsMatchPicker(track: track, initialQuery: request.query).id(track.id)
        } else {
            VStack(spacing: 16) {
                ContentUnavailableView(tr("Play a song first", "请先播放歌曲"), systemImage: "music.note",
                    description: Text(tr("Lyrics are matched to the current recording.", "歌词会匹配当前录音版本。")))
                Button(tr("Close", "关闭")) { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(24).frame(width: 460, height: 260)
        }
    }
}
