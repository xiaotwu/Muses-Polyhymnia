import SwiftUI

/// Stable artist identity with the native circular artist artwork convention.
struct ArtistObjectView: View {
    let name: String
    let detail: String
    let artwork: ArtworkSource
    var size: CGFloat = MusicObjectMetrics.artistGrid
    var isNowPlaying: Bool = false
    var showsHoverPlay: Bool = false
    var onSelect: () -> Void
    var onPlay: () -> Void

    private enum Control: Hashable { case artwork, play }
    @FocusState private var focusedControl: Control?
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelect) {
                ArtworkView(source: artwork, cornerRadius: 0, glyphSize: 40,
                            targetSize: size, targetHeight: size, presentation: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .focused($focusedControl, equals: .artwork)
            .accessibilityLabel(tr("Open \(name)", "打开 \(name)"))
            .accessibilityValue(detail)
            .overlay(alignment: .bottomTrailing) {
                if showsHoverPlay && (hovering || focusedControl != nil) {
                    HoverPlayButton(onPlay: onPlay)
                        .focused($focusedControl, equals: .play)
                        .accessibilityLabel(tr("Play \(name)", "播放 \(name)"))
                        .padding(8)
                }
            }
            Text(name)
                .font(MusesTypography.song(size: 13, emphasized: true, text: name))
                .foregroundStyle(BrandColors.textPrimary)
                .lineLimit(2)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            if isNowPlaying {
                Label(tr("Playing", "播放中"), systemImage: "speaker.wave.2.fill")
                    .font(.caption).foregroundStyle(BrandColors.accent)
            }
        }
        .frame(width: size, alignment: .leading)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
    }
}
