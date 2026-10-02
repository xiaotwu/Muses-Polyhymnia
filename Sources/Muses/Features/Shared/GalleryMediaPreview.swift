import SwiftUI
import Observation

/// Read-only media details. Opening a cover never starts or replaces playback.
struct GalleryMediaPreview: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let artwork: ArtworkSource
    let duration: Double?
    let onPlay: () -> Void
}

/// Window-local presentation; the existing playback closure retains its collection context.
@MainActor @Observable
final class GalleryPreviewPresentation {
    var preview: GalleryMediaPreview?
    func present(_ preview: GalleryMediaPreview) { self.preview = preview }
    func dismiss() { preview = nil }
    func play() {
        guard let selected = preview else { return }
        preview = nil
        selected.onPlay()
    }
}

private struct GalleryPreviewRequest: ViewModifier {
    @Binding var item: GalleryMediaPreview?
    @Environment(GalleryPreviewPresentation.self) private var presentation
    func body(content: Content) -> some View {
        content.onChange(of: item?.id) { _, _ in
            guard let item else { return }
            presentation.present(item)
            self.item = nil
        }
    }
}

extension View {
    func galleryMediaPreview(item: Binding<GalleryMediaPreview?>) -> some View {
        modifier(GalleryPreviewRequest(item: item))
    }
}

struct GalleryMediaPreviewOverlay: View {
    let preview: GalleryMediaPreview
    let onDismiss: () -> Void
    let onPlay: () -> Void

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                Button(action: onDismiss) {
                    BrandColors.scrim.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Close song details", "关闭歌曲详情"))
                .keyboardShortcut(.cancelAction)
                .ignoresSafeArea()

                let wide = viewport.size.width >= 680
                let artworkSize: CGFloat = wide ? 224 : 148
                VStack(alignment: .leading, spacing: 24) {
                    if wide {
                        HStack(alignment: .top, spacing: 28) {
                            artwork(size: artworkSize)
                            information
                        }
                    } else {
                        artwork(size: artworkSize)
                            .frame(maxWidth: .infinity)
                        information
                    }
                    HStack(spacing: 12) {
                        Button(tr("Play", "播放"), systemImage: "play.fill", action: onPlay)
                            .musesAction(prominent: true)
                            .keyboardShortcut(.return, modifiers: [])
                        Spacer(minLength: 12)
                        Button(tr("Done", "完成"), action: onDismiss)
                            .musesAction()
                    }
                    .controlSize(.large)
                }
                .padding(28)
                .frame(width: min(720, max(280, viewport.size.width - 48)),
                       height: min(wide ? 344 : 480, max(280, viewport.size.height - 48)))
                .background(BrandColors.surface, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                .accessibilityElement(children: .contain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func artwork(size: CGFloat) -> some View {
        ArtworkView(source: preview.artwork, cornerRadius: 16, glyphSize: 40, targetSize: size)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var information: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("Song details", "歌曲详情"))
                    .font(MusesTypography.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.textSecondary)
                Text(preview.title)
                    .font(MusesTypography.song(size: 23, text: preview.title).weight(.semibold))
                    .foregroundStyle(BrandColors.textPrimary)
                    .textSelection(.enabled)
                    .accessibilityAddTraits(.isHeader)
                Text(preview.subtitle)
                    .font(MusesTypography.song(size: 16, text: preview.subtitle))
                    .foregroundStyle(BrandColors.textSecondary)
                    .textSelection(.enabled)
                if let duration = preview.duration, duration.isFinite,
                   duration > 0, duration < Double(Int.max) {
                    Label("\(Int(duration) / 60):\(String(format: "%02d", Int(duration) % 60))", systemImage: "clock")
                        .font(MusesTypography.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                        .accessibilityLabel(tr("Duration", "时长"))
                        .accessibilityValue("\(Int(duration) / 60):\(String(format: "%02d", Int(duration) % 60))")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
