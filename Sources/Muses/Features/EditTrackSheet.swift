import SwiftUI

/// Blank fields intentionally clear metadata; invalid nonblank drafts must not.
struct TrackMetadataNumbers {
    enum Field: Error, Equatable {
        case track, disc, year

        var message: String {
            switch self {
            case .track: tr("Enter a whole number for Track No., or leave it blank.", "曲目号请输入整数，或留空。")
            case .disc: tr("Enter a whole number for Disc No., or leave it blank.", "碟号请输入整数，或留空。")
            case .year: tr("Enter a whole number for Year, or leave it blank.", "年份请输入整数，或留空。")
            }
        }
    }

    let trackNo: Int?
    let discNo: Int?
    let year: Int?

    init(trackNo: String, discNo: String, year: String) throws {
        func parse(_ draft: String, field: Field) throws -> Int? {
            let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            guard let number = Int(value) else { throw field }
            return number
        }
        self.trackNo = try parse(trackNo, field: .track)
        self.discNo = try parse(discNo, field: .disc)
        self.year = try parse(year, field: .year)
    }
}

/// Verified presentation credits are suggestions, not implicit metadata edits.
struct TrackArtistDraft {
    let originalArtist: String
    let videoID: String
    private(set) var value: String
    private(set) var wasEdited = false

    init(originalArtist: String, videoID: String,
         metadata: YTDlpBridge.YTDlpPlaylistEntry? = nil, isKnownOwner: Bool = false) {
        self.originalArtist = originalArtist
        self.videoID = videoID
        value = originalArtist
        refresh(metadata: metadata, isKnownOwner: isKnownOwner)
    }

    mutating func edit(_ value: String) {
        self.value = value
        wasEdited = true
    }

    mutating func refresh(metadata: YTDlpBridge.YTDlpPlaylistEntry?, isKnownOwner: Bool) {
        guard !wasEdited else { return }
        let verified = metadata.flatMap { $0.id == videoID ? $0 : nil }
        let derived = isKnownOwner || SongDisplayInformation.isMissingCredit(originalArtist)
            || originalArtist == verified?.uploader
        guard derived else { value = originalArtist; return }
        value = [verified?.artist, verified?.uploader].compactMap { $0 }
            .first { !SongDisplayInformation.isMissingCredit($0) } ?? ""
    }

    var artistToSave: String { wasEdited ? value : originalArtist }
}

/// Track metadata editing form. Modifies the DB only; never writes file tags (personal use).
struct EditTrackSheet: View {
    let track: Track
    @Environment(LibraryService.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var saveError: String?
    @State private var title = ""
    @State private var artistDraft = TrackArtistDraft(originalArtist: "", videoID: "")
    @State private var fieldsLoaded = false
    @State private var albumTitle = ""
    @State private var albumArtist = ""
    @State private var trackNo = ""
    @State private var discNo = ""
    @State private var year = ""
    @State private var genre = ""
    @State private var lyrics = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(tr("Edit Info", "编辑信息")).font(MusesTypography.headline).foregroundStyle(BrandColors.textPrimary)
                Spacer()
                Button(tr("Cancel", "取消")) { dismiss() }
                    .foregroundStyle(BrandColors.textSecondary)
                    .keyboardShortcut(.cancelAction)
                Button(tr("Save", "保存")) { save() }
                    .musesAction(prominent: true)
                    .tint(BrandColors.accent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider().background(BrandColors.hairline)

            if let saveError { Text(saveError).font(.callout).foregroundStyle(.red).padding(16) }
            Form {
                Section(tr("Basic Info", "基本信息")) {
                    TextField(tr("Title", "标题"), text: $title)
                    TextField(tr("Artist", "艺术家"), text: Binding(
                        get: { artistDraft.value }, set: { artistDraft.edit($0) }
                    ), prompt: Text(tr("Artist unavailable", "艺人信息暂缺")))
                    TextField(tr("Album", "专辑"), text: $albumTitle)
                    TextField(tr("Album Artist", "专辑艺术家"), text: $albumArtist)
                }
                Section(tr("Track Info", "曲目信息")) {
                    TextField(tr("Track No.", "曲目号"), text: $trackNo)
                    TextField(tr("Disc No.", "碟号"), text: $discNo)
                    TextField(tr("Year", "年份"), text: $year)
                    TextField(tr("Genre", "流派"), text: $genre)
                }
                Section(tr("Lyrics", "歌词")) {
                    TextEditor(text: $lyrics)
                        .font(MusesTypography.caption)
                        .frame(minHeight: 80)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 480)
        .frame(maxHeight: 560)
        .onAppear { loadFields() }
        .onChange(of: SongCreditCache.shared.revision) { _, _ in refreshArtistSuggestion() }
    }

    private func loadFields() {
        guard !fieldsLoaded else { return }
        fieldsLoaded = true
        title = track.title
        artistDraft = TrackArtistDraft(originalArtist: track.artist, videoID: track.youTubeId)
        refreshArtistSuggestion()
        albumTitle = track.albumTitle ?? ""
        albumArtist = track.albumArtist ?? ""
        trackNo = track.trackNo.map(String.init) ?? ""
        discNo = track.discNo.map(String.init) ?? ""
        year = track.year.map(String.init) ?? ""
        genre = track.genre ?? ""
        lyrics = track.lyrics ?? ""
    }

    private func refreshArtistSuggestion() {
        guard fieldsLoaded else { return }
        let cache = SongCreditCache.shared
        artistDraft.refresh(metadata: cache.entry(videoID: artistDraft.videoID),
                            isKnownOwner: cache.isCollectionOwner(artistDraft.originalArtist, videoID: artistDraft.videoID))
    }

    private func save() {
        let numbers: TrackMetadataNumbers
        do { numbers = try TrackMetadataNumbers(trackNo: trackNo, discNo: discNo, year: year) }
        catch let field as TrackMetadataNumbers.Field { saveError = field.message; return }
        catch { return }
        let saved = library.updateTrack(
            id: track.id,
            title: title,
            artist: artistDraft.artistToSave,
            albumTitle: albumTitle.isEmpty ? nil : albumTitle,
            albumArtist: albumArtist.isEmpty ? nil : albumArtist,
            trackNo: numbers.trackNo,
            discNo: numbers.discNo,
            year: numbers.year,
            genre: genre.isEmpty ? nil : genre,
            lyrics: lyrics.isEmpty ? nil : lyrics
        )
        if saved { dismiss() }
        else { saveError = tr("Changes could not be saved. Your draft is kept; try again.", "无法保存更改，草稿已保留，请重试。") }
    }
}
