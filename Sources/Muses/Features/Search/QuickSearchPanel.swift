import SwiftUI

/// A local-only quick entry. Remote search starts in the main destination.
struct QuickSearchPanel: View {
    var onShowResults: (String) -> Void
    var onDismiss: () -> Void
    @Environment(LibraryService.self) private var library
    @Environment(PlaybackService.self) private var playback
    @State private var query = ""
    @State private var matches: [TrackSnapshot] = []
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField(tr("Quick Search", "快捷搜索"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($inputFocused)
                    .onSubmit { onShowResults(query) }
                Button(action: onDismiss) { Image(systemName: "xmark") }
                    .help(tr("Close Quick Search", "关闭快捷搜索"))
                    .accessibilityLabel(tr("Close Quick Search", "关闭快捷搜索"))
            }
            Divider()
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(tr("Search your library here. Open full search for YouTube, albums, artists, and notes.",
                        "在此快捷搜索资料库；完整搜索包含 YouTube、专辑、艺术家与笔记。"))
                    .foregroundStyle(.secondary)
            } else if matches.isEmpty {
                Text(tr("No matching library songs", "资料库中没有匹配歌曲"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches.prefix(6)) { snapshot in
                    GlobalSearchTrackRow(snapshot: snapshot,
                                         isCurrent: playback.state.track?.id == snapshot.id,
                                         videoContext: matches) {
                        playback.playTrack(snapshot, context: matches, from: .search)
                        onDismiss()
                    }
                    .trackContextMenu(snapshot: snapshot, onPlay: {
                        playback.playTrack(snapshot, context: matches, from: .search)
                        onDismiss()
                    }, videoContext: matches)
                }
            }
            Button(tr("Open full search", "打开完整搜索"), systemImage: "arrow.up.forward.app") {
                onShowResults(query)
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(24)
        .frame(width: 580)
        .onExitCommand(perform: onDismiss)
        .task { inputFocused = true }
        .task(id: query) {
            guard !Task.isCancelled else { return }
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            matches = text.isEmpty ? [] : library.allTracks(search: text)
                .filter { !$0.youTubeId.isEmpty }.map(TrackSnapshot.init(from:))
        }
    }
}
