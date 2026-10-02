import SwiftUI

/// One local draft for a track note and its bookmarks, committed by Save.
/// Text and bookmark edits remain value drafts until Save commits them together;
/// an empty note deletes its persisted row only during that commit. Cancel discards
/// the draft. With ffNotes off, existing notes and bookmarks remain read-only.
struct TrackNotesSheet: View {
    let track: Track
    @Environment(NotesService.self) private var notes
    @Environment(PlaybackService.self) private var playback
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarkSeconds = 0.0
    @State private var followsPlaybackPosition = true
    @State private var saveError: String?
    @State private var noteText: String = ""
    @State private var bookmarks: [TrackBookmarkDraft] = []
    @State private var originalBookmarks: [TrackBookmarkDraft] = []
    @State private var originalContent = ""
    @State private var newBookmarkTitle: String = ""
    @State private var editingBookmark: TrackBookmarkDraft?
    @State private var editTitle: String = ""
    @State private var editNote: String = ""

    private var enabled: Bool { notes.isEnabled }

    private var bookmarkTime: Binding<Double> {
        Binding(get: {
            followsPlaybackPosition && playback.transportState.track?.id == track.id
                ? playback.transportState.position : bookmarkSeconds
        }, set: {
            followsPlaybackPosition = false
            bookmarkSeconds = $0
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(MusesTypography.headline)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(track.title)
                        .help(track.title)
                    Text(SongCreditCache.shared.artist(snapshot: TrackSnapshot(from: track))).font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(tr("Cancel", "取消")) { dismiss() }
                    .fixedSize()
                    .keyboardShortcut(.cancelAction)
                Button(enabled ? tr("Save", "保存") : tr("Done", "完成")) {
                    guard enabled else { dismiss(); return }
                    if notes.saveDraft(trackId: track.id, content: noteText, bookmarks: bookmarks,
                        originalContent: originalContent, originalBookmarks: originalBookmarks) { dismiss() }
                    else { saveError = notes.lastError }
                }
                .fixedSize()
                .keyboardShortcut(.defaultAction)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !enabled { Text(tr("Notes are read-only.", "笔记为只读。", zhHant: "筆記為唯讀。")) .foregroundStyle(.secondary) }

                    // Track note
                    Text(tr("Note", "笔记")).font(MusesTypography.subheadline).foregroundStyle(BrandColors.textSecondary)
                    Group {
                        if enabled {
                            TextEditor(text: $noteText)
                        } else {
                            ScrollView {
                                Text(noteText.isEmpty ? tr("No note", "无笔记", zhHant: "沒有筆記") : noteText)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                        .font(MusesTypography.body)
                        .frame(height: 120)
                        .padding(6)
                        .background(BrandColors.surface)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(BrandColors.hairline, lineWidth: 1))
                        .disabled(!enabled)

                    if let saveError {
                        Text(saveError).font(MusesTypography.callout).foregroundStyle(.red)
                    }

                    // Bookmarks
                    Text(tr("Bookmarks", "书签")).font(MusesTypography.subheadline)
                        .foregroundStyle(BrandColors.textSecondary)
                    HStack {
                        Text(tr("Time (seconds)", "时间（秒）", zhHant: "時間（秒）"))
                        TextField("", value: bookmarkTime, format: .number.precision(.fractionLength(0...1)))
                            .textFieldStyle(.roundedBorder).frame(width: 90)
                            .accessibilityLabel(tr("Bookmark time in seconds", "书签时间（秒）", zhHant: "書籤時間（秒）"))
                            .disabled(!enabled)
                        if playback.transportState.track?.id == track.id {
                            Button(tr("Current Position", "当前位置", zhHant: "目前位置")) {
                                followsPlaybackPosition = true
                                bookmarkSeconds = playback.transportState.position
                            }.disabled(!enabled)
                        }
                    }
                    Text(tr("Notes and bookmarks are saved together. Cancel discards this draft.", "笔记与书签一并保存。取消将放弃本次暂存修改。"))
                        .font(MusesTypography.caption).foregroundStyle(.secondary)
                    ScrollView {
                        LazyVStack {
                            if bookmarks.isEmpty {
                                Text(tr("No bookmarks", "无书签")).font(MusesTypography.caption)
                                    .foregroundStyle(BrandColors.textSecondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(bookmarks, id: \.id) { bm in
                                    bookmarkRow(bm)
                                }
                            }
                        }
                    }.frame(height: 160)

                    // New bookmark title input
                    HStack {
                        TextField(tr("Bookmark title (optional)", "书签标题(可选)"), text: $newBookmarkTitle)
                            .disabled(!enabled)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            addBookmark()
                        } label: { Label(tr("Add", "添加"), systemImage: "plus") }
                            .buttonStyle(.bordered)
                            .help(tr("Add bookmark", "添加书签", zhHant: "新增書籤"))
                            .accessibilityLabel(tr("Add bookmark", "添加书签", zhHant: "新增書籤"))
                            .disabled(!enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            }
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 560, minHeight: 480, idealHeight: 600, maxHeight: 700)
        .onAppear {
            noteText = notes.note(forTrack: track.id)?.content ?? ""
            bookmarkSeconds = playback.transportState.track?.id == track.id ? playback.transportState.position : 0
            originalContent = noteText
            bookmarks = notes.bookmarks(forTrack: track.id).map(TrackBookmarkDraft.init)
            originalBookmarks = bookmarks
        }
        .sheet(item: $editingBookmark) { bm in
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Edit Bookmark", "编辑书签")).font(MusesTypography.headline)
                TextField(tr("Title", "标题"), text: $editTitle).textFieldStyle(.roundedBorder).disabled(!enabled)
                if let saveError { Text(saveError).foregroundStyle(.red).font(MusesTypography.callout) }
                TextField(tr("Note", "笔记"), text: $editNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(3...6).disabled(!enabled)
                HStack {
                    Spacer()
                    Button(tr("Cancel", "取消")) { editingBookmark = nil }
                    Button(tr("Save", "保存")) { saveEdit(bm) }.musesAction(prominent: true).disabled(!enabled)
                }
            }
            .padding(20).frame(width: 380)
        }
    }

    private func bookmarkRow(_ bm: TrackBookmarkDraft) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill").foregroundStyle(BrandColors.accent)
            Button(formatTimestamp(bm.timestampMs)) {
                playback.seek(to: bm.timestampMs)
            }
            .disabled(playback.transportState.track?.id != track.id)
            .help(tr("Go to bookmark", "跳转到书签", zhHant: "跳至書籤"))
            .monospacedDigit().frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(bm.title ?? "").font(MusesTypography.caption).foregroundStyle(BrandColors.textPrimary).lineLimit(1)
                if let n = bm.note, !n.isEmpty {
                    Text(n).font(MusesTypography.caption2).foregroundStyle(BrandColors.textSecondary).lineLimit(1)
                }
            }
            Spacer()
            Button { editingBookmark = bm; editTitle = bm.title ?? ""; editNote = bm.note ?? "" } label: {
                Image(systemName: "pencil").frame(width: 28, height: 28)
            }.buttonStyle(.fullAreaPlain).foregroundStyle(BrandColors.textSecondary).disabled(!enabled)
            .help(tr("Edit bookmark", "编辑书签", zhHant: "編輯書籤"))
            .accessibilityLabel(tr("Edit bookmark", "编辑书签", zhHant: "編輯書籤"))
            Button { deleteBookmark(bm) } label: {
                Image(systemName: "trash").frame(width: 28, height: 28)
            }.buttonStyle(.fullAreaPlain).foregroundStyle(BrandColors.textSecondary).disabled(!enabled)
            .help(tr("Delete bookmark", "删除书签", zhHant: "刪除書籤"))
            .accessibilityLabel(tr("Delete bookmark", "删除书签", zhHant: "刪除書籤"))
        }
        .padding(.vertical, 4)
    }

    private func addBookmark() {
        let ts = bookmarkTime.wrappedValue
        let title = newBookmarkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ts.isFinite, ts >= 0, ts < Double(Int.max) else {
            saveError = tr("Enter a valid bookmark time.", "请输入有效的书签时间。")
            return
        }
        bookmarks.append(TrackBookmarkDraft(timestampMs: ts, title: title.isEmpty ? nil : title))
        bookmarks.sort { $0.timestampMs < $1.timestampMs }
        saveError = nil
        newBookmarkTitle = ""
    }

    private func saveEdit(_ bm: TrackBookmarkDraft) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bm.id }) else { return }
        bookmarks[index].title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editTitle
        bookmarks[index].note = editNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editNote
        saveError = nil
        editingBookmark = nil
    }

    private func deleteBookmark(_ bm: TrackBookmarkDraft) {
        bookmarks.removeAll { $0.id == bm.id }
        saveError = nil
    }

    private func formatTimestamp(_ s: Double) -> String {
        let m = Int(s) / 60, sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }
}

/// Bookmark list in the Now Playing right column (Final Spec §10.7): tapping a bookmark seeks to that timestamp.
/// Rendered only when the current track has bookmarks; takes no space otherwise.
struct BookmarksView: View {
    let trackId: UUID
    @Environment(NotesService.self) private var notes
    @Environment(PlaybackService.self) private var playback

    var body: some View {
        let bms = notes.bookmarks(forTrack: trackId)
        let _ = notes.revision
        if !bms.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("Bookmarks", "书签"))
                    .font(MusesTypography.caption).fontWeight(.semibold)
                    .foregroundStyle(BrandColors.textSecondary)
                ForEach(bms, id: \.id) { bm in
                    Button {
                        playback.seek(to: bm.timestampMs)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .font(MusesTypography.caption2).foregroundStyle(BrandColors.accent)
                            Text(format(bm.timestampMs)).font(MusesTypography.caption).monospacedDigit()
                                .foregroundStyle(BrandColors.textPrimary)
                            if let t = bm.title, !t.isEmpty {
                                Text(t).font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(BrandColors.surface.opacity(0.6))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.fullAreaPlain)
                    .disabled(playback.transportState.track?.id != trackId)
                }
            }
        }
    }

    private func format(_ s: Double) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}
