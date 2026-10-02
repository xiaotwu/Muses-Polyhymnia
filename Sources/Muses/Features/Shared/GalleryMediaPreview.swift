import SwiftUI

/// Read-only media details. Opening a cover never starts or replaces playback.
struct GalleryMediaPreview: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let artwork: ArtworkSource
    let duration: Double?
    let onPlay: () -> Void
}

struct GalleryMediaPreviewSheet: View {
    let preview: GalleryMediaPreview
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ArtworkView(source: preview.artwork, cornerRadius: 10, glyphSize: 40, targetSize: 220)
                .frame(width: 220, height: 220)
            VStack(alignment: .leading, spacing: 14) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(preview.title).font(.title2).textSelection(.enabled)
                        Text(preview.subtitle).foregroundStyle(.secondary).textSelection(.enabled)
                        if let duration = preview.duration, duration.isFinite,
                           duration > 0, duration < Double(Int.max) {
                            Text(tr("Duration: \(Int(duration) / 60):\(String(format: "%02d", Int(duration) % 60))",
                                    "时长：\(Int(duration) / 60):\(String(format: "%02d", Int(duration) % 60))"))
                                .foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                HStack {
                    Button(tr("Play", "播放"), systemImage: "play.fill") {
                        dismiss()
                        preview.onPlay()
                    }.keyboardShortcut(.return, modifiers: [])
                    Button(tr("Done", "完成")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(24).frame(width: 620, height: 290)
    }
}
