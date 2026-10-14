import Foundation
import Observation

/// Shared display enrichment, keyed by exact video identity. It does not
/// rewrite playlist sync truth or user-edited Track fields.
@MainActor
@Observable
final class SongCreditCache {
    static let shared = SongCreditCache()
    private var metadata: [String: YTDlpBridge.YTDlpPlaylistEntry] = [:]
    private var collectionOwners: [String: Set<String>] = [:]
    /// User-confirmed corrections outlive ordinary metadata cache eviction.
    /// The empty replacement is intentional, distinct from no correction.
    private var confirmedImportedArtistCredits: [String: [String: String]] = [:]
    private var confirmedImportedSourceCredits: [String: Set<String>] = [:]
    private(set) var revision: UInt64 = 0

    func recordOwner(_ owner: String, videoID: String) {
        guard !owner.isEmpty, collectionOwners[videoID]?.contains(owner) != true else { return }
        collectionOwners[videoID, default: []].insert(owner)
        revision &+= 1
    }

    func store(_ entry: YTDlpBridge.YTDlpPlaylistEntry) {
        let previous = metadata[entry.id]
        let resolved = YTDlpBridge.YTDlpPlaylistEntry(
            id: entry.id, title: entry.title,
            uploader: nonMissing(entry.uploader) ?? previous?.uploader,
            duration: entry.duration ?? previous?.duration,
            playlistTitle: entry.playlistTitle ?? previous?.playlistTitle,
            channelID: entry.channelID ?? previous?.channelID,
            track: entry.track ?? previous?.track,
            album: entry.album ?? previous?.album,
            releaseYear: entry.releaseYear ?? previous?.releaseYear,
            artist: nonMissing(entry.artist) ?? previous?.artist)
        guard previous != resolved else { return }
        if metadata.count >= 512 { metadata.removeAll() }
        metadata[entry.id] = resolved
        revision &+= 1
    }

    private func nonMissing(_ value: String?) -> String? {
        guard let value, !SongDisplayInformation.isMissingCredit(value) else { return nil }
        return value
    }

    func isCollectionOwner(_ name: String, videoID: String) -> Bool {
        collectionOwners[videoID]?.contains(name) == true
            || confirmedImportedArtistCredits[videoID]?[name] != nil
    }

    func replaceConfirmedImportedArtistCredits(_ values: [String: [String: String]],
                                              sourceCredits: [String: Set<String>] = [:]) {
        guard values != confirmedImportedArtistCredits || sourceCredits != confirmedImportedSourceCredits else { return }
        confirmedImportedArtistCredits = values
        confirmedImportedSourceCredits = sourceCredits
        revision &+= 1
    }

    func isConfirmedIncorrectArtist(_ name: String, videoID: String) -> Bool {
        confirmedImportedArtistCredits[videoID]?[name] != nil
    }

    func isConfirmedImportedSourceCredit(_ name: String, videoID: String) -> Bool {
        confirmedImportedSourceCredits[videoID]?.contains(name) == true
    }

    /// Nil means no correction applies. An empty value deliberately suppresses
    /// publisher fallback until genuine, non-rejected artist metadata arrives.
    func confirmedArtist(storedArtist: String, videoID: String,
                         metadata supplied: YTDlpBridge.YTDlpPlaylistEntry? = nil) -> String? {
        let replacements = confirmedImportedArtistCredits[videoID] ?? [:]
        let replacement = replacements[storedArtist]
            ?? (storedArtist.isEmpty && replacements.values.contains("") ? "" : nil)
        let sourceDerived = isConfirmedImportedSourceCredit(storedArtist, videoID: videoID)
        guard replacement != nil || sourceDerived else { return nil }
        let entry = supplied.flatMap { $0.id == videoID ? $0 : nil } ?? metadata[videoID]
        if let artist = usableCredit(entry?.artist, videoID: videoID) { return artist }
        return replacement ?? storedArtist
    }

    private func usableCredit(_ value: String?, videoID: String) -> String? {
        guard let value = nonMissing(value), !isConfirmedIncorrectArtist(value, videoID: videoID) else { return nil }
        return value
    }

    func entry(videoID: String) -> YTDlpBridge.YTDlpPlaylistEntry? { metadata[videoID] }

    /// Resolve missing or exact owner-derived display credits without rewriting
    /// immutable historical events or replacing legitimate historical credits.
    func historicalArtist(videoID: String, storedArtist: String) -> String {
        if let correction = confirmedArtist(storedArtist: storedArtist, videoID: videoID) {
            return nonMissing(correction) ?? tr("Artist unavailable", "艺人信息暂缺")
        }
        guard SongDisplayInformation.isMissingCredit(storedArtist)
                || isCollectionOwner(storedArtist, videoID: videoID) else { return storedArtist }
        let entry = metadata[videoID]
        if let artist = usableCredit(entry?.artist, videoID: videoID) { return artist }
        if let publisher = usableCredit(entry?.uploader, videoID: videoID) { return publisher }
        return tr("Artist unavailable", "艺人信息暂缺")
    }

    func artist(snapshot: TrackSnapshot, owner: String? = nil) -> String {
        if let correction = confirmedArtist(storedArtist: snapshot.artist, videoID: snapshot.youTubeId) {
            return nonMissing(correction) ?? tr("Artist unavailable", "艺人信息暂缺")
        }
        let entry = metadata[snapshot.youTubeId]
        let original = snapshot.artist
        let missing = SongDisplayInformation.isMissingCredit(original)
        let ownerDerived = original == owner || isCollectionOwner(original, videoID: snapshot.youTubeId)
        let publisherDerived = original == entry?.uploader
        if missing || ownerDerived || publisherDerived {
            if let artist = usableCredit(entry?.artist, videoID: snapshot.youTubeId) { return artist }
            if let publisher = usableCredit(entry?.uploader, videoID: snapshot.youTubeId) { return publisher }
            return tr("Artist unavailable", "艺人信息暂缺")
        }
        return original
    }
}
