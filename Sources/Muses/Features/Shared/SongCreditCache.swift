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
    }

    func entry(videoID: String) -> YTDlpBridge.YTDlpPlaylistEntry? { metadata[videoID] }

    func artist(snapshot: TrackSnapshot, owner: String? = nil) -> String {
        let entry = metadata[snapshot.youTubeId]
        let original = snapshot.artist
        let missing = SongDisplayInformation.isMissingCredit(original)
        let ownerDerived = original == owner || collectionOwners[snapshot.youTubeId]?.contains(original) == true
        let publisherDerived = original == entry?.uploader
        if missing || ownerDerived || publisherDerived {
            if let artist = entry?.artist, !SongDisplayInformation.isMissingCredit(artist) { return artist }
            if let publisher = entry?.uploader, !SongDisplayInformation.isMissingCredit(publisher) { return publisher }
            return tr("Artist unavailable", "艺人信息暂缺")
        }
        return original
    }
}
