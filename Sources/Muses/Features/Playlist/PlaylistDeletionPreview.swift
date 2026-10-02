import SwiftUI

/// Names affected collection entries and retained user truth before deletion.
struct PlaylistDeletionPreview: View {
    let title: String
    let explanation: String
    let itemTitles: [String]
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.weight(.semibold))
            Text(explanation).font(.callout)
            Label(tr("Songs, favorites, listening history and YouTube remain available.",
                     "歌曲、收藏、播放历史及 YouTube 保留。"), systemImage: "checkmark.shield")
                .font(.callout).foregroundStyle(.secondary)
            Text(tr("Affected collection entries: \(itemTitles.count)", "受影响的歌单条目：\(itemTitles.count)"))
                .font(.headline)
            List(Array(itemTitles.enumerated()), id: \.offset) { index, name in
                HStack {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                    Text(name).lineLimit(2)
                }
            }
            Divider()
            HStack {
                Button(tr("Cancel", "取消"), action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button(tr("Delete", "删除"), role: .destructive, action: onDelete)
            }
        }
        .padding(24)
        .frame(minWidth: 500, idealWidth: 580, minHeight: 380, idealHeight: 500)
    }
}
