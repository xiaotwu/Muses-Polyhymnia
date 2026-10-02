import SwiftUI

enum EditorialInformationStyle {
    case above, bottomGradient, leftGradient, bottomPanel, compactPanel
}

/// Editorial artwork keeps independent native Open and Play interactions.
struct EditorialCard: View {
    private enum Control: Hashable { case artwork, play }
    let eyebrow: String
    let title: String
    let subtitle: String
    let artwork: ArtworkSource
    var width: CGFloat = AppleMusicTokens.editorialWidth
    var imageHeight: CGFloat = AppleMusicTokens.editorialHeight
    var informationStyle: EditorialInformationStyle = .above
    var onOpen: () -> Void
    var onPlay: () -> Void

    @State private var hovering = false
    @FocusState private var focusedControl: Control?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if informationStyle == .above {
                information(overArtwork: false)
                    .padding(.bottom, 8)
            }
            Button(action: onOpen) {
                ZStack(alignment: .bottomLeading) {
                    ArtworkView(source: artwork, cornerRadius: 0, glyphSize: 28,
                                targetSize: width, targetHeight: imageHeight)
                    if informationStyle != .above {
                        artworkInformation
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: width, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: AppleMusicTokens.cardCorner, style: .continuous))
            }
            .buttonStyle(.fullAreaPlain)
            .focused($focusedControl, equals: .artwork)
            .help(tr("Open \(title)", "打开 \(title)"))
            .accessibilityLabel(tr("Open \(title)", "打开 \(title)"))
            .accessibilityValue(subtitle)
            .overlay(alignment: .bottomTrailing) {
                if hovering || focusedControl != nil {
                    HoverPlayButton(onPlay: onPlay)
                        .focused($focusedControl, equals: .play)
                        .accessibilityLabel(tr("Play \(title)", "播放 \(title)"))
                        .padding(10)
                }
            }
            .onHover { hovering = $0 }
            .animation(MusesMotion.hoverAnimation(reduceMotion: reduceMotion), value: hovering)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var artworkInformation: some View {
        switch informationStyle {
        case .above:
            EmptyView()
        case .bottomGradient, .leftGradient:
            LinearGradient(colors: [.clear, .black.opacity(contrast == .increased ? 0.96 : 0.88)],
                           startPoint: informationStyle == .leftGradient ? .trailing : .center,
                           endPoint: informationStyle == .leftGradient ? .leading : .bottom)
            information(overArtwork: true)
                .padding(18)
                .padding(.trailing, 42)
                .frame(maxWidth: informationStyle == .leftGradient ? width * 0.65 : width,
                       maxHeight: .infinity, alignment: .bottomLeading)
        case .bottomPanel:
            information(overArtwork: true)
                .padding(14).padding(.trailing, 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.12))
        case .compactPanel:
            information(overArtwork: true)
                .padding(12)
                .frame(maxWidth: width * 0.65, alignment: .leading)
                .background(Color.black.opacity(reduceTransparency || contrast == .increased ? 1 : 0.8),
                            in: RoundedRectangle(cornerRadius: 12))
                .padding(14)
        }
    }

    private func information(overArtwork: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(MusesTypography.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(overArtwork ? Color.white.opacity(0.9) : BrandColors.textSecondary)
            Text(title)
                .font(MusesTypography.song(size: overArtwork ? 19 : 15, emphasized: true, text: title))
                .foregroundStyle(overArtwork ? Color.white : BrandColors.textPrimary)
                .lineLimit(2)
            Text(subtitle)
                .font(MusesTypography.song(size: 13, text: subtitle))
                .foregroundStyle(overArtwork ? Color.white.opacity(0.94) : BrandColors.textSecondary)
                .lineLimit(2)
        }
    }
}
