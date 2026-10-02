import SwiftUI

/// One collection identity with separate native open, play and menu affordances.
struct PlaylistOverviewEntry: View {
    let title: String
    let subtitle: String
    let artwork: ArtworkSource
    let grid: Bool
    var isYouTube = false
    var status: String? = nil
    var needsReview = false
    let canPlay: Bool
    let onOpen: () -> Void
    let onPlay: () -> Void

    var body: some View {
        Group {
            if grid {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: onOpen) { cover(size: 190) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("Open \(title)", "打开 \(title)"))
                        .accessibilityValue(subtitle)
                        .overlay(alignment: .bottomTrailing) { playButton.padding(8) }
                    HStack(alignment: .top, spacing: 8) {
                        information
                        sourceMark
                    }
                    .padding(.trailing, 34)
                }
                .frame(width: 190, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 14) {
                    Button(action: onOpen) {
                        HStack(spacing: 14) {
                            cover(size: 52)
                            information
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Open \(title)", "打开 \(title)"))
                    .accessibilityValue(subtitle)
                    sourceMark
                    playButton
                }
                .padding(.vertical, 10)
                .padding(.trailing, 38)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MusesTypography.song(size: 14, emphasized: true, text: title))
                .foregroundStyle(BrandColors.textPrimary)
                .lineLimit(grid ? 2 : 1)
            Text(subtitle)
                .font(MusesTypography.caption)
                .foregroundStyle(BrandColors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: grid ? 62 : 0, alignment: .topLeading)
    }

    private func cover(size: CGFloat) -> some View {
        ArtworkView(source: artwork, cornerRadius: 7, glyphSize: 20, targetSize: size)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var sourceMark: some View {
        Group {
            if needsReview {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(BrandColors.accent)
            } else if isYouTube { YouTubeMark(size: 15) }
            else { Image(systemName: "music.note.list").foregroundStyle(.secondary) }
        }
        .frame(width: 24, height: 28)
        .help(status ?? (isYouTube ? "YouTube" : "Muses"))
        .accessibilityLabel(isYouTube ? "YouTube" : "Muses")
        .accessibilityValue(status ?? "")
    }

    private var playButton: some View {
        Button(action: onPlay) {
            Image(systemName: "play.fill").frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(BrandColors.textPrimary)
        .disabled(!canPlay)
        .help(tr("Play \(title)", "播放 \(title)"))
        .accessibilityLabel(tr("Play \(title)", "播放 \(title)"))
    }
}

extension View {
    /// Keep the pointer context menu and visible keyboard-accessible menu identical.
    func playlistOverviewActions<Actions: View>(grid: Bool, title: String,
                                               @ViewBuilder actions: @escaping () -> Actions) -> some View {
        self.contextMenu(menuItems: actions)
            .overlay(alignment: grid ? .bottomTrailing : .trailing) {
                Menu(content: actions) {
                    Image(systemName: "ellipsis").frame(width: 28, height: 28)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tr("Options for \(title)", "\(title) 的选项"))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help(tr("Playlist options", "歌单选项"))
                .accessibilityLabel(tr("Options for \(title)", "\(title) 的选项"))
            }
    }
}
