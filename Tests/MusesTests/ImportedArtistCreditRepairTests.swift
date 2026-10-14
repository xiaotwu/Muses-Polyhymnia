import CryptoKit
import Foundation
import SQLite3
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Explicit imported artist credit repair", .serialized)
struct ImportedArtistCreditRepairTests {
    private enum InjectedFailure: Error, Equatable { case write }
    private let wrong = "Retired source credit"

    private struct Fixture {
        let container: ModelContainer
        let directory: URL
        let store: URL
        let trackID: UUID
        let unresolvedID: UUID
        let manualID: UUID
        let itemID: UUID
        let credits: SongCreditCache
    }

    @Test("lost owner history reproduces the old display and preview is read-only and exact")
    func previewAndCancel() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let before = try audit(f.store)
        let storedTrack = try track(f.trackID, in: f.container)
        let snapshot = TrackSnapshot(from: storedTrack)
        #expect(f.credits.artist(snapshot: snapshot, owner: "Current owner") == wrong)
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        #expect(preview.rows.count == 2)
        let proposed = try #require(preview.rows.first { $0.id == f.trackID })
        #expect(proposed.videoID == "abcdefghijk" && proposed.after == "Video source credit")
        #expect(proposed.basis == .sourceCredit && proposed.sources.count == 1)
        #expect(!preview.rows.contains { $0.id == f.manualID })
        #expect(preview.selectedRows(includingUnresolved: false).count == 1)
        #expect(preview.selectedRows(includingUnresolved: true).count == 2)
        #expect(try audit(f.store) == before)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == nil)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        #expect(!FileManager.default.fileExists(atPath: f.directory.appending(path: "imported-artist-credit-repairs").path))
    }

    @Test("verified exact-video artist wins while source and conflicting credits remain honestly classified")
    func metadataAndConflictingSource() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let context = ModelContext(f.container)
        let existing = try #require(context.fetch(FetchDescriptor<YouTubeImportItem>()).first)
        let duplicate = YouTubeImportItem(youTubeId: existing.youTubeId, title: "Source song", artist: "Different source", order: 1)
        duplicate.track = existing.track
        duplicate.import_ = existing.import_
        context.insert(duplicate)
        try context.save()
        var preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        #expect(preview.rows.first { $0.id == f.trackID }?.basis == .unresolved)
        f.credits.store(.init(id: "abcdefghijk", title: "Source song", uploader: "Publisher", artist: "Verified performer"))
        preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        #expect(preview.rows.first { $0.id == f.trackID }?.basis == .verifiedArtist)
        #expect(preview.rows.first { $0.id == f.trackID }?.after == "Verified performer")
        #expect(try track(f.manualID, in: f.container).artist == "Independent edit")
    }

    @Test("Apply changes only reviewed artist fields and is not silently repeated")
    func applyPreservesTruth() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let before = try audit(f.store)
        let old = TrackSnapshot(from: try track(f.trackID, in: f.container))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        var saves = 0
        let library = LibraryService(modelContainer: f.container)
        let receipt = try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits, save: {
            saves += 1
            try $0.save()
        }, onCommit: { library.artistCreditRepairDidCommit() })
        #expect(saves == 1 && receipt.state == .applied && receipt.changes.count == 1)
        #expect(library.metadataRevision == 1)
        #expect(try track(f.trackID, in: f.container).artist == "Video source credit")
        #expect(try track(f.unresolvedID, in: f.container).artist == wrong)
        #expect(try track(f.manualID, in: f.container).artist == "Independent edit")
        #expect(try audit(f.store) == before)
        #expect(f.credits.artist(snapshot: old) == "Video source credit")
        #expect(f.credits.historicalArtist(videoID: old.youTubeId, storedArtist: wrong) == "Video source credit")
        let unrelated = TrackSnapshot(from: Track(title: "Other video", artist: wrong, youTubeId: "7654321zyxw"))
        #expect(f.credits.artist(snapshot: unrelated) == wrong)
        #expect(try FileManager.default.attributesOfItem(atPath: receipt.fileURL.path)[.posixPermissions] as? Int == 0o600)
        #expect(throws: ImportedArtistCreditRepairError.conflict) {
            try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits, save: { _ in saves += 1 })
        }
        #expect(saves == 1)
    }

    @Test("unresolved clearing requires inclusion and yields an explicit unavailable fallback")
    func unresolvedIsExplicit() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let old = TrackSnapshot(from: try track(f.unresolvedID, in: f.container))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        let receipt = try ImportedArtistCreditRepair.apply(preview, includingUnresolved: true, to: f.container, credits: f.credits)
        #expect(receipt.changes.count == 2)
        #expect(try track(f.unresolvedID, in: f.container).artist.isEmpty)
        #expect(f.credits.artist(snapshot: old) == tr("Artist unavailable", "艺人信息暂缺"))
        #expect(f.credits.historicalArtist(videoID: old.youTubeId, storedArtist: wrong) == tr("Artist unavailable", "艺人信息暂缺"))
        f.credits.store(.init(id: old.youTubeId, title: "Verified song", uploader: "Publisher", artist: "Resolved performer"))
        #expect(f.credits.artist(snapshot: old) == "Resolved performer")
    }

    @Test("source changes or deletion invalidate the whole preview before any write", arguments: [false, true])
    func sourceChangesRejectPreview(delete: Bool) throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        let edits = ModelContext(f.container)
        let item = try #require(edits.fetch(FetchDescriptor<YouTubeImportItem>()).first { $0.id == f.itemID })
        if delete { edits.delete(item) } else { item.artist = "New source after Pull" }
        try edits.save()
        let before = try audit(f.store)
        var saves = 0
        #expect(throws: ImportedArtistCreditRepairError.conflict) {
            try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits, save: { _ in saves += 1 })
        }
        #expect(saves == 0)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        #expect(try audit(f.store) == before)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == nil)
    }

    @Test("an artist edit or changed exact video rejects Apply before a journal or save", arguments: [false, true])
    func trackCASConflict(videoChanged: Bool) throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        let context = ModelContext(f.container)
        let changed = try #require(context.fetch(FetchDescriptor<Track>()).first { $0.id == f.trackID })
        if videoChanged { changed.youTubeId = "7654321zyxw" } else { changed.artist = "Later hand edit" }
        try context.save()
        let before = try audit(f.store)
        var saves = 0
        #expect(throws: ImportedArtistCreditRepairError.conflict) {
            try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits, save: { _ in saves += 1 })
        }
        #expect(saves == 0)
        #expect(try audit(f.store) == before)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == nil)
    }

    @Test("a failed save rolls back every artist and records no applied correction")
    func saveFailureRollsBack() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let before = try audit(f.store)
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        var commits = 0
        #expect(throws: InjectedFailure.write) {
            try ImportedArtistCreditRepair.apply(preview, includingUnresolved: true, to: f.container, credits: f.credits,
                                                save: { _ in throw InjectedFailure.write }, onCommit: { commits += 1 })
        }
        #expect(commits == 0)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        #expect(try track(f.unresolvedID, in: f.container).artist == wrong)
        #expect(try audit(f.store) == before)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container)?.state == .undone)
        #expect(!f.credits.isCollectionOwner(wrong, videoID: "abcdefghijk"))
    }

    @Test("prepared journal failure prevents any database write")
    func journalFailurePreventsSave() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        var saves = 0
        #expect(throws: InjectedFailure.write) {
            try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits,
                save: { _ in saves += 1 }, persist: { _ in throw InjectedFailure.write })
        }
        #expect(saves == 0)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
    }

    @Test("finalization failure retains recoverable committed values and blocks repeated Apply")
    func finalizationFailure() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let old = TrackSnapshot(from: try track(f.trackID, in: f.container))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        var saves = 0
        var commits = 0
        #expect(throws: ImportedArtistCreditRepairError.recoveryRequired) {
            try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits, save: {
                saves += 1
                try $0.save()
            }, onCommit: { commits += 1 }, persist: {
                if $0.state == .applied { throw InjectedFailure.write }
                try ImportedArtistCreditRepair.persistReceipt($0)
            })
        }
        #expect(saves == 1)
        #expect(commits == 1)
        #expect(try track(f.trackID, in: f.container).artist == "Video source credit")
        let pending = try #require(try ImportedArtistCreditRepair.latestReceipt(in: f.container))
        #expect(pending.state == .prepared)
        let cold = SongCreditCache()
        try ImportedArtistCreditRepair.restoreConfirmedCredits(in: f.container, credits: cold)
        #expect(cold.artist(snapshot: old) == "Video source credit")
        #expect(throws: ImportedArtistCreditRepairError.recoveryRequired) {
            try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits)
        }
        #expect(try ImportedArtistCreditRepair.undo(pending, in: f.container, credits: cold,
                                                  onCommit: { commits += 1 }).state == .undone)
        #expect(commits == 2)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        #expect(cold.artist(snapshot: old) == wrong)
    }

    @Test("Undo preserves later artist edits and performs no partial rollback")
    func undoProtectsEdits() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        let receipt = try ImportedArtistCreditRepair.apply(preview, includingUnresolved: true, to: f.container, credits: f.credits)
        let edits = ModelContext(f.container)
        let changed = try #require(edits.fetch(FetchDescriptor<Track>()).first { $0.id == f.trackID })
        changed.artist = "Later manual performer"
        changed.liked = false
        try edits.save()
        let beforeUndo = try audit(f.store)
        var saves = 0
        #expect(throws: ImportedArtistCreditRepairError.conflict) {
            try ImportedArtistCreditRepair.undo(receipt, in: f.container, credits: f.credits, save: { _ in saves += 1 })
        }
        #expect(saves == 0)
        #expect(try track(f.trackID, in: f.container).artist == "Later manual performer")
        #expect(try track(f.unresolvedID, in: f.container).artist.isEmpty)
        #expect(try audit(f.store) == beforeUndo)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container)?.state == .applied)
    }

    @Test("cold receipt restores exact old snapshot facts; Undo removes them and retains later data")
    func coldReceiptAndUndo() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let old = TrackSnapshot(from: try track(f.trackID, in: f.container))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        let receipt = try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits)
        let reopened = try makeModelContainer(storeURL: f.store)
        let library = LibraryService(modelContainer: reopened)
        let cold = SongCreditCache()
        try ImportedArtistCreditRepair.restoreConfirmedCredits(in: reopened, credits: cold)
        #expect(cold.artist(snapshot: old) == "Video source credit")
        #expect(cold.historicalArtist(videoID: old.youTubeId, storedArtist: wrong) == "Video source credit")
        cold.store(.init(id: old.youTubeId, title: old.title, uploader: "Publisher", artist: "Verified performer"))
        #expect(cold.artist(snapshot: old) == "Verified performer")
        let edits = ModelContext(reopened)
        let later = try #require(edits.fetch(FetchDescriptor<Track>()).first { $0.id == f.trackID })
        later.liked = false
        later.playCount = 19
        try edits.save()
        let beforeUndo = try audit(f.store)
        #expect(try ImportedArtistCreditRepair.undo(receipt, in: reopened, credits: cold,
                                                  onCommit: { library.artistCreditRepairDidCommit() }).state == .undone)
        #expect(library.metadataRevision == 1)
        #expect(cold.artist(snapshot: old) == wrong)
        #expect(!cold.isCollectionOwner(wrong, videoID: old.youTubeId))
        let restored = try track(f.trackID, in: reopened)
        #expect(restored.artist == wrong && !restored.liked && restored.playCount == 19)
        #expect(try audit(f.store) == beforeUndo)
        let anotherCold = SongCreditCache()
        try ImportedArtistCreditRepair.restoreConfirmedCredits(in: reopened, credits: anotherCold)
        #expect(anotherCold.artist(snapshot: old) == wrong)
    }

    @Test("an interrupted Undo finalizes explicitly without another artist write")
    func interruptedUndo() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let old = TrackSnapshot(from: try track(f.trackID, in: f.container))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        let applied = try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits)
        var commits = 0
        #expect(throws: ImportedArtistCreditRepairError.recoveryRequired) {
            try ImportedArtistCreditRepair.undo(applied, in: f.container, credits: f.credits, onCommit: { commits += 1 }, persist: {
                if $0.state == .undone { throw InjectedFailure.write }
                try ImportedArtistCreditRepair.persistReceipt($0)
            })
        }
        let pending = try #require(try ImportedArtistCreditRepair.latestReceipt(in: f.container))
        #expect(pending.state == .undoPrepared)
        #expect(commits == 1)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        let cold = SongCreditCache()
        try ImportedArtistCreditRepair.restoreConfirmedCredits(in: f.container, credits: cold)
        #expect(cold.artist(snapshot: old) == wrong)
        var saves = 0
        #expect(try ImportedArtistCreditRepair.undo(pending, in: f.container, credits: cold, save: { _ in saves += 1 },
                                                  onCommit: { commits += 1 }).state == .undone)
        #expect(saves == 0)
        #expect(commits == 1)
    }

    @Test("confirmed source fallback stays consistent with a different publisher and never becomes a lyric performer")
    func sourceProjectionAcrossSurfaces() throws {
        let f = try fixture()
        defer {
            SongCreditCache.shared.replaceConfirmedImportedArtistCredits([:])
            try? FileManager.default.removeItem(at: f.directory)
        }
        let old = TrackSnapshot(from: try track(f.trackID, in: f.container))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        _ = try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits)
        try ImportedArtistCreditRepair.restoreConfirmedCredits(in: f.container)
        let current = TrackSnapshot(from: try track(f.trackID, in: f.container))
        let publisherOnly = YTDlpBridge.YTDlpPlaylistEntry(id: old.youTubeId, title: old.title, uploader: "Different publisher")
        for snapshot in [old, current] {
            let row = CollectionTrackRow(snapshot: snapshot, canonicalIndex: 0, collectionOwner: "Current owner")
            #expect(SongDisplayInformation(row: row, metadata: publisherOnly).artist == "Video source credit")
            let prepared = LyricsPreparedRecording(row: row, metadata: publisherOnly, credits: f.credits)
            #expect(prepared.artist.isEmpty && prepared.displayArtist == "Video source credit")
            var draft = TrackArtistDraft(originalArtist: snapshot.artist, videoID: snapshot.youTubeId)
            draft.refresh(metadata: publisherOnly, isKnownOwner: false,
                confirmedArtist: f.credits.confirmedArtist(storedArtist: snapshot.artist, videoID: snapshot.youTubeId, metadata: publisherOnly))
            #expect(draft.value == "Video source credit" && draft.artistToSave == snapshot.artist)
            draft.edit("A real manual edit")
            draft.refresh(metadata: publisherOnly, isKnownOwner: true, confirmedArtist: "Video source credit")
            #expect(draft.value == "A real manual edit")
        }
        let genuine = YTDlpBridge.YTDlpPlaylistEntry(id: old.youTubeId, title: old.title,
                                                   uploader: "Different publisher", artist: "Verified performer")
        let row = CollectionTrackRow(snapshot: current, canonicalIndex: 0)
        #expect(SongDisplayInformation(row: row, metadata: genuine).artist == "Verified performer")
        #expect(LyricsPreparedRecording(row: row, metadata: genuine, credits: f.credits).artist == "Verified performer")
    }

    @Test("explicit clearing cannot resurrect the rejected name from publisher or artist metadata", arguments: [false, true])
    func rejectedMetadataDoesNotResurrect(artistField: Bool) throws {
        let f = try fixture()
        defer {
            SongCreditCache.shared.replaceConfirmedImportedArtistCredits([:])
            try? FileManager.default.removeItem(at: f.directory)
        }
        let old = TrackSnapshot(from: try track(f.unresolvedID, in: f.container))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        _ = try ImportedArtistCreditRepair.apply(preview, includingUnresolved: true, to: f.container, credits: f.credits)
        try ImportedArtistCreditRepair.restoreConfirmedCredits(in: f.container)
        let current = TrackSnapshot(from: try track(f.unresolvedID, in: f.container))
        let bad = YTDlpBridge.YTDlpPlaylistEntry(id: old.youTubeId, title: old.title,
                                               uploader: wrong, artist: artistField ? wrong : nil)
        f.credits.store(bad)
        for snapshot in [old, current] {
            #expect(f.credits.artist(snapshot: snapshot) == tr("Artist unavailable", "艺人信息暂缺"))
            #expect(f.credits.historicalArtist(videoID: snapshot.youTubeId, storedArtist: snapshot.artist) == tr("Artist unavailable", "艺人信息暂缺"))
            let row = CollectionTrackRow(snapshot: snapshot, canonicalIndex: 0)
            #expect(SongDisplayInformation(row: row, metadata: bad).artist == tr("Artist unavailable", "艺人信息暂缺"))
            #expect(LyricsPreparedRecording(row: row, metadata: bad, credits: f.credits).artist.isEmpty)
            var draft = TrackArtistDraft(originalArtist: snapshot.artist, videoID: snapshot.youTubeId)
            draft.refresh(metadata: bad, isKnownOwner: true,
                confirmedArtist: f.credits.confirmedArtist(storedArtist: snapshot.artist, videoID: snapshot.youTubeId, metadata: bad))
            #expect(draft.value.isEmpty)
        }
    }

    @Test("an oversized prepared receipt is rejected before any artist save")
    func oversizedJournalFailsBeforeSave() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let context = ModelContext(f.container)
        let item = try #require(context.fetch(FetchDescriptor<YouTubeImportItem>()).first)
        item.artist = String(repeating: "x", count: 4_200_000)
        try context.save()
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        var saves = 0
        #expect(throws: ImportedArtistCreditRepairError.invalidReceipt) {
            try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits, save: { _ in saves += 1 })
        }
        #expect(saves == 0)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == nil)
    }

    @Test("new or changed exact-video artist proof invalidates the reviewed proposal before any write",
          arguments: [ImportedArtistCreditPreview.Basis.verifiedArtist, .sourceCredit, .unresolved])
    func metadataProposalChanges(basis: ImportedArtistCreditPreview.Basis) throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let videoID = basis == .unresolved ? "lmnopqrstuv" : "abcdefghijk"
        if basis == .verifiedArtist {
            f.credits.store(.init(id: videoID, title: "Song", uploader: "Publisher", artist: "First verified artist"))
        }
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        #expect(preview.rows.first { $0.videoID == videoID }?.basis == basis)
        f.credits.store(.init(id: videoID, title: "Song", uploader: "Publisher", artist: "New verified artist"))
        var saves = 0
        #expect(throws: ImportedArtistCreditRepairError.conflict) {
            try ImportedArtistCreditRepair.apply(preview, includingUnresolved: true, to: f.container,
                                                credits: f.credits, save: { _ in saves += 1 })
        }
        #expect(saves == 0)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        #expect(try track(f.unresolvedID, in: f.container).artist == wrong)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == nil)
    }

    @Test("ordinary metadata eviction does not revoke an already reviewed genuine artist proof")
    func metadataEvictionPreservesReviewedProof() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        f.credits.store(.init(id: "abcdefghijk", title: "Song", uploader: "Publisher", artist: "Reviewed performer"))
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        for index in 0..<512 {
            f.credits.store(.init(id: "eviction-\(index)", title: "Other song", uploader: "Other publisher"))
        }
        #expect(f.credits.entry(videoID: "abcdefghijk") == nil)
        let receipt = try ImportedArtistCreditRepair.apply(preview, to: f.container, credits: f.credits)
        #expect(receipt.changes.first?.basis == .verifiedArtist)
        #expect(try track(f.trackID, in: f.container).artist == "Reviewed performer")
    }

    @Test("one exact receipt is read back and atomically rewritten through its journal states")
    func journalReadAndRewrite() throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        var receipt = ImportedArtistCreditRepairReceipt(version: 1, id: UUID(), createdAt: Date(), store: f.store,
            changes: preview.selectedRows(includingUnresolved: false), state: .prepared)
        try ImportedArtistCreditRepair.persistReceipt(receipt)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == receipt)
        receipt.state = .applied
        try ImportedArtistCreditRepair.persistReceipt(receipt)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == receipt)
        receipt.state = .undone
        try ImportedArtistCreditRepair.persistReceipt(receipt)
        #expect(try ImportedArtistCreditRepair.latestReceipt(in: f.container) == receipt)
        #expect(try track(f.trackID, in: f.container).artist == wrong)
        let directory = receipt.fileURL.deletingLastPathComponent()
        #expect(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).count == 1)
        #expect(try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int == 0o700)
        #expect(try FileManager.default.attributesOfItem(atPath: receipt.fileURL.path)[.posixPermissions] as? Int == 0o600)
    }

    @Test("normalized receipt paths still reject another store, host or mismatched UUID filename",
          arguments: ["store", "host", "filename"])
    func journalRejectsForeignLocation(location: String) throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let preview = try ImportedArtistCreditRepair.preview(incorrectArtist: wrong, in: f.container, credits: f.credits)
        let receipt = ImportedArtistCreditRepairReceipt(version: 1, id: UUID(), createdAt: Date(), store: f.store,
            changes: preview.selectedRows(includingUnresolved: false), state: .prepared)
        try ImportedArtistCreditRepair.persistReceipt(receipt)
        if location != "filename" {
            let foreignStore: URL
            if location == "host" {
                var components = try #require(URLComponents(url: f.store, resolvingAgainstBaseURL: true))
                components.host = "foreign-host"
                foreignStore = try #require(components.url)
            } else {
                foreignStore = f.directory.appending(path: "another-library.sqlite")
            }
            let foreign = ImportedArtistCreditRepairReceipt(version: receipt.version, id: receipt.id,
                createdAt: receipt.createdAt, store: foreignStore,
                changes: receipt.changes, state: receipt.state)
            try JSONEncoder().encode(foreign).write(to: receipt.fileURL, options: .atomic)
        } else {
            try FileManager.default.moveItem(at: receipt.fileURL,
                to: receipt.fileURL.deletingLastPathComponent().appending(path: "\(UUID().uuidString).json"))
        }
        #expect(throws: ImportedArtistCreditRepairError.invalidReceipt) {
            try ImportedArtistCreditRepair.latestReceipt(in: f.container)
        }
        #expect(try track(f.trackID, in: f.container).artist == wrong)
    }

    private func fixture() throws -> Fixture {
        let directory = isolatedHomeTestDirectory("muses-imported-credit-repair-")
        let store = directory.appending(path: "library.sqlite")
        let container = try makeModelContainer(storeURL: store)
        let context = ModelContext(container)
        let track = Track(title: "Stored song", artist: wrong, genre: "User genre", youTubeId: "abcdefghijk",
                          lyrics: "User lyrics", playCount: 7, liked: true)
        let unresolved = Track(title: "No retained source", artist: wrong, youTubeId: "lmnopqrstuv")
        let manual = Track(title: "Manual song", artist: "Independent edit", youTubeId: "wxyz1234567")
        context.insert(track)
        context.insert(unresolved)
        context.insert(manual)
        let imported = YouTubeImport(playlistId: "PL_current", url: "https://www.youtube.com/playlist?list=PL_current",
                                     title: "Current collection", channel: "Current owner")
        context.insert(imported)
        let item = YouTubeImportItem(youTubeId: track.youTubeId, title: "Source song", artist: "Video source credit", order: 3)
        item.track = track
        item.import_ = imported
        context.insert(item)
        context.insert(PlaylistItem(order: 4, track: track))
        context.insert(TrackNote(trackId: track.id, content: "Keep note"))
        context.insert(ListeningEvent(trackId: track.id, trackTitle: track.title, artist: wrong,
                                      startedAt: Date(), listenedMs: 42_000, outcome: .completed))
        try context.save()
        return .init(container: container, directory: directory, store: store, trackID: track.id,
                     unresolvedID: unresolved.id, manualID: manual.id, itemID: item.id, credits: SongCreditCache())
    }

    private func track(_ id: UUID, in container: ModelContainer) throws -> Track {
        try #require(ModelContext(container).fetch(FetchDescriptor<Track>()).first { $0.id == id })
    }

    /// Full logical user-data digest, excluding only the changed artist column
    /// and that Track row's Core Data optimistic-lock counter.
    private func audit(_ store: URL) throws -> String {
        let database = try StoreUpgradeSnapshot.openForReading(store)
        defer { sqlite3_close(database) }
        func rows(_ sql: String) throws -> [[String]] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw InjectedFailure.write }
            defer { sqlite3_finalize(statement) }
            var values: [[String]] = []
            var status = sqlite3_step(statement)
            while status == SQLITE_ROW {
                values.append((0..<sqlite3_column_count(statement)).map { column in
                    guard let bytes = sqlite3_column_text(statement, column) else { return "NULL" }
                    return String(decoding: UnsafeBufferPointer(start: bytes, count: Int(sqlite3_column_bytes(statement, column))), as: UTF8.self)
                })
                status = sqlite3_step(statement)
            }
            guard status == SQLITE_DONE else { throw InjectedFailure.write }
            return values
        }
        func quoted(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var digest = SHA256()
        let internalTables: Set<String> = ["Z_METADATA", "Z_PRIMARYKEY", "Z_MODELCACHE"]
        for table in try rows("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Z%' ORDER BY name").map({ $0[0] }) where !internalTables.contains(table) {
            let columns = try rows("PRAGMA table_info(\(quoted(table)))").map { $0[1] }.filter {
                !(table == "ZTRACK" && ["ZARTIST", "Z_OPT"].contains($0))
            }
            digest.update(data: try JSONEncoder().encode([table] + columns))
            let projection = columns.map { "quote(\(quoted($0)))" }.joined(separator: ",")
            let ordering = columns.contains("Z_PK") ? quoted("Z_PK") : "rowid"
            digest.update(data: try JSONEncoder().encode(rows("SELECT \(projection) FROM \(quoted(table)) ORDER BY \(ordering)")))
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
