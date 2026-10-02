import SwiftUI

/// Source → occurrence selection → confirmation. Only the last action writes the library.
struct YouTubeImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(YouTubeImportService.self) private var service
    @State private var url = ""
    @State private var preview: YouTubePlaylistImportPreview?
    @State private var selected = Set<Int>()
    @State private var step = 0
    @State private var busy = false
    @State private var error: String?
    @State private var operation: Task<Void, Never>?
    var initialURL = ""
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Import YouTube Playlist", "导入 YouTube 歌单"))
                .font(MusesTypography.title2.weight(.semibold))
            HStack {
                stepLabel(0, tr("Source", "来源"))
                Image(systemName: "chevron.right")
                stepLabel(1, tr("Select items", "选择条目"))
                Image(systemName: "chevron.right")
                stepLabel(2, tr("Confirm", "确认"))
            }.font(.caption).foregroundStyle(.secondary)
            Divider()
            if step == 0 {
                Form {
                    TextField(tr("Playlist link", "歌单链接"), text: $url)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if !busy { loadPreview() } }
                    Text(tr("Preview reads the playlist without changing your library or YouTube. Nothing is imported until you confirm.",
                            "预览只读取歌单，不改变资料库或 YouTube。确认后才会导入。"))
                        .font(.callout).foregroundStyle(.secondary)
                }.formStyle(.grouped)
            } else if let preview {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preview.title).font(.headline)
                    Text(preview.channel).foregroundStyle(.secondary)
                    Text(preview.url).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if step == 1 {
                    HStack {
                        Text(tr("\(selected.count) of \(preview.entries.count) selected", "已选 \(selected.count)/\(preview.entries.count) 项"))
                        Spacer()
                        Button(tr("Select All", "全选")) { selected = Set(preview.entries.indices) }
                        Button(tr("Deselect All", "取消全选")) { selected = [] }
                    }.font(.callout)
                    List(Array(preview.entries.enumerated()), id: \.offset) { index, entry in
                        Toggle(isOn: Binding(get: { selected.contains(index) }, set: { value in
                            if value { selected.insert(index) } else { selected.remove(index) }
                        })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.title).lineLimit(2)
                                Text(entry.artist ?? entry.uploader ?? tr("Unknown Artist", "未知艺人"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.toggleStyle(.checkbox)
                    }
                } else {
                    Form {
                        LabeledContent(tr("Destination", "目标"), value: tr("Muses library on this Mac", "此 Mac 的 Muses 资料库"))
                        LabeledContent(tr("Selected items", "所选条目"), value: String(selected.count))
                        Text(tr("YouTube stays unchanged. Importing an existing playlist opens its saved copy. A later Pull can include items you omit here.",
                                "YouTube 保持不变。已导入的歌单将打开保存副本。后续 Pull 可能包含本次未选的条目。"))
                            .font(.callout).foregroundStyle(.secondary)
                    }.formStyle(.grouped)
                }
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
            Divider()
            HStack {
                Button(tr("Cancel", "取消")) { operation?.cancel(); dismiss() }
                    .keyboardShortcut(.cancelAction)
                if step > 0 {
                    Button(tr("Back", "返回")) { step -= 1; error = nil }.disabled(busy)
                }
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button(step == 2 ? tr("Import", "导入") : tr("Continue", "继续")) {
                    if step == 0 { loadPreview() }
                    else if step == 1 { step = 2 }
                    else { commit() }
                }
                .musesAction(prominent: true)
                .keyboardShortcut(.defaultAction)
                .disabled(busy || (step == 0 ? url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : selected.isEmpty))
            }
        }
        .padding(24)
        .frame(minWidth: 540, idealWidth: 620, minHeight: 420, idealHeight: 540)
        .onAppear { if url.isEmpty { url = initialURL } }
        .onDisappear { operation?.cancel() }
    }

    private func stepLabel(_ index: Int, _ title: String) -> some View {
        Text(title).fontWeight(index == step ? .semibold : .regular)
            .foregroundStyle(index == step ? Color.primary : Color.secondary)
            .accessibilityValue(index == step ? tr("Current step", "当前步骤") : "")
    }

    private func loadPreview() {
        busy = true
        error = nil
        operation = Task {
            defer { busy = false }
            do {
                let result = try await service.prepareImport(url: url.trimmingCharacters(in: .whitespacesAndNewlines))
                try Task.checkCancellation()
                preview = result
                selected = Set(result.entries.indices)
                step = 1
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }

    private func commit() {
        guard let preview else { return }
        busy = true
        error = nil
        operation = Task {
            defer { busy = false }
            do {
                _ = try await service.importPlaylist(preview: preview, selectedIndices: selected)
                onImport()
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
