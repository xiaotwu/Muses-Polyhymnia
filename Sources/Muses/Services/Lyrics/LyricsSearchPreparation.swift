import Foundation
import Observation

/// Search fields are presentation values, separate from persisted recording
/// identity. A publisher can describe the recording without being its performer.
struct LyricsPreparedRecording: Sendable {
    let title: String
    let artist: String
    let displayTitle: String
    let displayArtist: String

    var query: LyricsSearchQuery { LyricsSearchQuery(title: title, artist: artist) }

    @MainActor
    init(row: CollectionTrackRow, metadata: YTDlpBridge.YTDlpPlaylistEntry?,
         credits: SongCreditCache = .shared) {
        let track = row.snapshot
        let metadata = metadata.flatMap { $0.id == track.youTubeId ? $0 : nil }
        let information = SongDisplayInformation(row: row, metadata: metadata)
        displayArtist = information.artist
        let originalArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerDerived = originalArtist == row.collectionOwner
            || credits.isCollectionOwner(originalArtist, videoID: track.youTubeId)
            || credits.isConfirmedImportedSourceCredit(originalArtist, videoID: track.youTubeId)
        let publisherDerived = originalArtist == metadata?.uploader
        if SongDisplayInformation.isMissingCredit(originalArtist) || ownerDerived || publisherDerived {
            artist = metadata?.artist.flatMap {
                SongDisplayInformation.isMissingCredit($0)
                    || credits.isConfirmedIncorrectArtist($0, videoID: track.youTubeId)
                    ? nil : LyricsMatchPolicy.queryArtist($0)
            } ?? ""
        } else {
            artist = LyricsMatchPolicy.queryArtist(originalArtist)
        }

        let originalTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPlaceholder = Self.isPlaceholder(originalTitle, videoID: track.youTubeId)
        let recordingTitle = isPlaceholder ? metadata?.title ?? "" : originalTitle
        var searchTitle = Self.isPlaceholder(recordingTitle, videoID: track.youTubeId) ? "" : recordingTitle
        if let metadata, (isPlaceholder || originalTitle == metadata.title),
           let song = metadata.track?.trimmingCharacters(in: .whitespacesAndNewlines), !song.isEmpty,
           !Self.isPlaceholder(song, videoID: track.youTubeId),
           LyricsMatchPolicy.versions(song) == LyricsMatchPolicy.versions(recordingTitle) {
            searchTitle = song
        }
        let versions = LyricsMatchPolicy.versions(recordingTitle)
        title = LyricsService.queryTitles(searchTitle, artist: artist).first {
            LyricsMatchPolicy.versions($0) == versions
        } ?? searchTitle
        displayTitle = isPlaceholder && !searchTitle.isEmpty ? searchTitle : information.title
    }

    private static func isPlaceholder(_ title: String, videoID: String) -> Bool {
        title.isEmpty || (!videoID.isEmpty && title == videoID)
            || ["youtube video", "unknown title", "未知标题", "未知標題"].contains(title.lowercased())
    }
}

/// One editable sheet owns one preparation. A submitted query remains fixed
/// while shared metadata work finishes; closing or changing recordings invalidates it.
@MainActor
@Observable
final class LyricsSearchPreparation {
    var titleQuery = "" {
        didSet { if titleQuery != oldValue { fieldEdited() } }
    }
    var artistQuery = "" {
        didSet { if artistQuery != oldValue { fieldEdited() } }
    }
    private(set) var displayTitle = ""
    private(set) var displayArtist = ""
    private(set) var recordingID: UUID?
    private(set) var isPreparing = false
    private(set) var isReady = false
    private(set) var searchRevision = 0
    private(set) var hasUnsubmittedEdits = false
    @ObservationIgnored private var operationID = UUID()
    @ObservationIgnored private var assigningDefaults = false
    @ObservationIgnored private var editRevision = 0
    @ObservationIgnored private var submitted = false

    func prepare(track: TrackSnapshot, initialQuery: String, using lyrics: LyricsService) async {
        let operation = UUID()
        operationID = operation
        recordingID = track.id
        submitted = false
        editRevision = 0
        hasUnsubmittedEdits = false
        isPreparing = true
        let explicit = !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let cached = lyrics.cachedSearchPreparation(for: track)
        setDefaults(title: explicit ? initialQuery : cached.title, artist: explicit ? "" : cached.artist)
        displayTitle = cached.displayTitle
        displayArtist = cached.displayArtist
        isReady = explicit
        let revision = editRevision
        let prepared = await lyrics.prepareSearch(for: track)
        guard !Task.isCancelled, operation == operationID, recordingID == track.id else { return }
        isPreparing = false
        guard let prepared else { return }
        displayTitle = prepared.displayTitle
        displayArtist = prepared.displayArtist
        if !explicit, !submitted, editRevision == revision {
            setDefaults(title: prepared.title, artist: prepared.artist)
        }
        // Metadata completion is not a submission of a partially edited draft.
        isReady = editRevision == revision || submitted
    }

    @discardableResult
    func submit() -> Bool {
        guard !titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        submitted = true
        hasUnsubmittedEdits = false
        isReady = true
        searchRevision += 1
        return true
    }

    func searchTrack(for track: TrackSnapshot) -> TrackSnapshot? {
        guard isReady, recordingID == track.id,
              !titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return LyricsSearchQuery(title: titleQuery, artist: artistQuery).applying(to: track)
    }

    func restoreDefaults(for track: TrackSnapshot, using lyrics: LyricsService) {
        guard recordingID == track.id else { return }
        let prepared = lyrics.cachedSearchPreparation(for: track)
        setDefaults(title: prepared.title, artist: prepared.artist)
        submit()
    }

    func invalidate() {
        operationID = UUID()
        recordingID = nil
        isPreparing = false
        isReady = false
    }

    private func setDefaults(title: String, artist: String) {
        assigningDefaults = true
        titleQuery = title
        artistQuery = artist
        assigningDefaults = false
    }

    private func fieldEdited() {
        guard !assigningDefaults else { return }
        editRevision += 1
        submitted = false
        hasUnsubmittedEdits = true
        isReady = false
    }
}
