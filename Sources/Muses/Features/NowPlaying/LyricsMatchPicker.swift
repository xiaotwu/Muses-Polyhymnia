import SwiftUI

struct LyricsMatchPicker: View {
    let track: TrackSnapshot
    var initialQuery = ""
    @Environment(LyricsService.self) private var lyrics
    @Environment(YouTubeImportService.self) private var importService
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [LyricsCandidate] = []
    @State private var loading = true
    @State private var titleQuery = ""
    @State private var artistQuery = ""
    @State private var source = "auto"
    @State private var searchRevision = 0
    @State private var initializedQuery = false
    @FocusState private var focusedField: QueryField?
    private enum QueryField: Hashable { case title, artist }
    @State private var songInformation: SongDisplayInformation?
    @State private var intelligenceTask: Task<Void, Never>?
    @State private var preparingQuery = false
    @State private var intelligenceMessage: String?
    @State private var searchMode = "fields"

    @State private var selectedCandidateID: Int?
    @State private var previewLines: [String] = []

    private var selectedCandidate: LyricsCandidate? {
        candidates.first { $0.id == selectedCandidateID }
    }

    var body: some View {
        VStack(spacing: 0) {
            heading
            Divider()
            recordingSummary
            Divider()
            compactQuery
            Divider()
            resultsPane.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            confirmationBar
        }
        .foregroundStyle(BrandColors.textPrimary)
        .tint(BrandColors.accent)
        .frame(minWidth: 760, idealWidth: 900, minHeight: 620, idealHeight: 680)
        .task {
            initializeQuery()
            focusedField = .title
        }
        .task(id: source + ":" + searchMode + ":" + String(searchRevision)) {
            initializeQuery()
            loading = true
            candidates = []
            selectedCandidateID = nil
            previewLines = []
            let query = LyricsSearchQuery(title: titleQuery, artist: artistQuery).applying(to: track)
            let found = await lyrics.findCandidates(track: query, refresh: true, source: source,
                keywords: searchMode == "keywords" ? [titleQuery, artistQuery].filter { !$0.isEmpty }.joined(separator: " ") : nil)
            guard !Task.isCancelled else { return }
            candidates = found
            selectedCandidateID = LyricsMatchPolicy.automatic(found, track: track)?.id
            updatePreview()
            loading = false
        }
        .onChange(of: selectedCandidateID) { _, _ in updatePreview() }
        .onDisappear { intelligenceTask?.cancel() }
        .onChange(of: searchMode) { _, mode in
            if mode == "keywords", source != "auto", source != "lrclib" { source = "lrclib" }
        }
    }

    private var heading: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("Match Lyrics", "匹配歌词"))
                    .font(MusesTypography.heading(tr("Match Lyrics", "匹配歌词"), size: 26))
                    .foregroundStyle(BrandColors.heading)
                Text(tr("Find lyrics for this recording, then confirm the version.", "搜索当前录音的歌词，确认版本后选用。"))
                    .font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(MusesTypography.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.fullAreaPlain).help(tr("Close", "关闭"))
            .accessibilityLabel(tr("Close", "关闭")).keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var recordingSummary: some View {
        HStack(spacing: 12) {
            ArtworkView(source: ArtworkSource.resolve(for: track), cornerRadius: 6, glyphSize: 20, targetSize: 44)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(songInformation?.title ?? track.title)
                    .font(MusesTypography.song(size: 14, emphasized: true, text: songInformation?.title ?? track.title))
                    .lineLimit(2)
                Text(songInformation?.artist ?? track.artist)
                    .font(MusesTypography.song(size: 12, text: songInformation?.artist ?? track.artist))
                    .foregroundStyle(BrandColors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 12)
            if track.durationSeconds > 0 {
                Text(Duration.seconds(track.durationSeconds).formatted(.time(pattern: .minuteSecond)))
                    .font(MusesTypography.caption.monospacedDigit()).foregroundStyle(BrandColors.textSecondary)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var compactQuery: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(tr("Song title or keywords", "歌名或关键词"), text: $titleQuery)
                    .textFieldStyle(.roundedBorder).focused($focusedField, equals: .title)
                    .accessibilityLabel(tr("Song title or keywords", "歌名或关键词"))
                TextField(tr("Artist (optional)", "艺人（可留空）"), text: $artistQuery)
                    .textFieldStyle(.roundedBorder).focused($focusedField, equals: .artist)
                    .frame(maxWidth: 240)
                Button(action: submitSearch) {
                    Label(tr("Search", "搜索"), systemImage: "magnifyingglass")
                }.buttonStyle(.borderedProminent).tint(BrandColors.playback)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack(spacing: 16) {
                Picker(tr("Source", "来源"), selection: $source) {
                    Text(tr("All sources", "全部来源")).tag("auto")
                    Text("LRCLIB").tag("lrclib")
                    Text("Musixmatch").tag("musixmatch").disabled(searchMode == "keywords")
                    Text("Lyrics.ovh").tag("lyricsOVH").disabled(searchMode == "keywords")
                }.pickerStyle(.menu).fixedSize()
                Picker(tr("Search mode", "搜索方式"), selection: $searchMode) {
                    Text(tr("Title & artist", "歌名与艺人")).tag("fields")
                    Text(tr("Keywords (fuzzy)", "关键词（模糊）")).tag("keywords")
                }.pickerStyle(.menu).fixedSize()
                Spacer()
                Button {
                    initializedQuery = false
                    initializeQuery(useInitialQuery: false)
                } label: { Image(systemName: "arrow.counterclockwise") }
                    .help(tr("Restore song information", "恢复歌曲信息"))
                    .accessibilityLabel(tr("Restore song information", "恢复歌曲信息"))
                Button { prepareIntelligentQuery() } label: {
                    Label("Apple Intelligence", systemImage: "sparkles")
                }.disabled(preparingQuery || LyricsIntelligence.availability != .available)
                    .help(LyricsIntelligence.availability.message)
            }.controlSize(.small)
            if preparingQuery {
                ProgressView(tr("Preparing search terms…", "正在整理搜索词…")).controlSize(.small)
            }
            if let intelligenceMessage {
                Text(intelligenceMessage).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.horizontal, 24).padding(.vertical, 14)
            .onSubmit { submitSearch() }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary)
    }

    @ViewBuilder private var resultsPane: some View {
        if loading {
            ProgressView(tr("Finding matching recordings…", "正在查找匹配的录音版本…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if candidates.isEmpty {
            ContentUnavailableView(tr("No lyric matches", "未找到歌词匹配"), systemImage: "text.magnifyingglass",
                description: Text(tr("Try the original song title or leave artist blank. A source may also be temporarily unavailable.",
                    "可尝试原始歌名或留空艺人字段；歌词来源也可能暂不可用。")))
        } else {
            HSplitView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("\(candidates.count) candidates", "\(candidates.count) 个候选"))
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                    List(candidates, selection: $selectedCandidateID) { candidate in
                        candidateRow(candidate).tag(candidate.id)
                    }.listStyle(.plain)
                }.frame(minWidth: 250, idealWidth: 310, maxWidth: 380)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text(tr("Lyric preview", "歌词预览")).font(.headline)
                        if let selectedCandidate {
                            Text(selectedCandidate.source.displayName).font(.caption).foregroundStyle(.secondary)
                            Text(selectedCandidate.syncedLyrics?.isEmpty == false ? tr("Synced", "逐行同步") : tr("Plain text", "纯文本"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if selectedCandidate == nil {
                                Text(tr("Select a recording to preview its lyrics.", "选择录音版本以预览歌词。"))
                                    .font(.callout).foregroundStyle(.secondary)
                            }
                            ForEach(previewLines.indices, id: \.self) { index in
                                Text(previewLines[index]).font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.textSelection(.enabled).padding(.vertical, 4)
                    }.id(selectedCandidateID)
                }.padding(16).frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }.padding(.vertical, 12)
        }
    }

    private func candidateRow(_ candidate: LyricsCandidate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selectedCandidateID == candidate.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedCandidateID == candidate.id ? BrandColors.heading : BrandColors.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.trackName).font(MusesTypography.song(size: 13, emphasized: true, text: candidate.trackName)).lineLimit(2)
                Text([candidate.artistName, candidate.albumName].compactMap { $0 }.joined(separator: " · "))
                    .font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary).lineLimit(1)
                HStack(spacing: 10) {
                    Text(candidate.source.displayName)
                    if let duration = candidate.duration {
                        Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                    }
                    Text(candidate.syncedLyrics?.isEmpty == false ? tr("Synced", "逐行同步") : tr("Plain text", "纯文本"))
                }.font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var confirmationBar: some View {
        HStack(spacing: 12) {
            if let selectedCandidate {
                Text(tr("Selected: \(selectedCandidate.source.displayName)", "已选择：\(selectedCandidate.source.displayName)"))
                    .font(MusesTypography.caption).foregroundStyle(BrandColors.textSecondary)
            }
            Spacer()
            Button(tr("Cancel", "取消")) { dismiss() }.musesAction()
            Button(tr("Use these lyrics", "使用此歌词")) {
                guard let selectedCandidate else { return }
                lyrics.choose(selectedCandidate, for: track)
                dismiss()
            }
            .musesAction(prominent: true).disabled(loading || selectedCandidate?.hasLyrics != true)
        }.padding(.horizontal, 24).padding(.vertical, 16)
    }

    private func updatePreview() {
        guard let selectedCandidate else { previewLines = []; return }
        if let plain = selectedCandidate.plainLyrics, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            previewLines = plain.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        } else {
            previewLines = LyricsService.parseLRC(selectedCandidate.syncedLyrics ?? "").map(\.text).filter { !$0.isEmpty }
        }
    }

    private func initializeQuery(useInitialQuery: Bool = true) {
        guard !initializedQuery else { return }
        let information = SongDisplayInformation(row: importService.songPresentationRow(for: track))
        songInformation = information
        titleQuery = LyricsService.sanitizedTitle(information.title)
        artistQuery = queryArtist(information)
        if useInitialQuery, !initialQuery.isEmpty {
            titleQuery = initialQuery
            artistQuery = ""
        }
        initializedQuery = true
    }

    private func queryArtist(_ information: SongDisplayInformation) -> String {
        information.artist == tr("Artist unavailable", "艺人信息暂缺")
            ? "" : LyricsMatchPolicy.queryArtist(information.artist)
    }

    private func submitSearch() {
        guard !titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        searchRevision += 1
    }

    private func prepareIntelligentQuery() {
        intelligenceTask?.cancel()
        preparingQuery = true
        intelligenceMessage = nil
        let originalTitle = titleQuery
        let originalArtist = artistQuery
        intelligenceTask = Task { @MainActor in
            let proposal = await LyricsIntelligence.searchQuery(track: track)
            guard !Task.isCancelled else { return }
            preparingQuery = false
            // Never overwrite edits or an active input-method composition made
            // while Apple's model was working. The user submits the proposal.
            guard titleQuery == originalTitle, artistQuery == originalArtist else { return }
            if let proposal {
                titleQuery = proposal.title
                artistQuery = proposal.artist
                intelligenceMessage = tr("Search terms prepared on this Mac. Edit them before searching.",
                    "搜索词已在此 Mac 上整理，可继续修改后搜索。")
            } else {
                intelligenceMessage = tr("Could not confidently identify the recording. Keep editing the search terms.",
                    "无法可靠识别录音版本，请继续手动调整搜索词。")
            }
        }
    }

}
