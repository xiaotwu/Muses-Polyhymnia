import Foundation
import SwiftData

enum ImportedArtistCreditRepairError: LocalizedError, Equatable {
    case persistentStoreRequired, pendingEdits, missingCredit, noCandidates, conflict, recoveryRequired, invalidReceipt

    var errorDescription: String? {
        switch self {
        case .persistentStoreRequired: tr("Artist credit repair requires an on-disk library.", "署名修复需要磁盘资料库。")
        case .pendingEdits: tr("Save your current edits before repairing artist credits.", "请先保存当前编辑，再修复署名。")
        case .missingCredit: tr("Enter the exact incorrect artist credit to review.", "请输入要核对的完整错误署名。")
        case .noCandidates: tr("There are no selected artist credits to repair.", "没有选中的可修复署名。")
        case .conflict: tr("A reviewed track or its source changed. No changes were made. Refresh the preview.", "核对过的曲目或来源已变化，未做任何修改。请刷新预览。")
        case .recoveryRequired: tr("A repair is unfinished. Review its recovery record before continuing.", "有一项修复尚未完成，请先查看恢复记录。")
        case .invalidReceipt: tr("The artist credit recovery record could not be verified.", "无法核实署名恢复记录。")
        }
    }
}

struct ImportedArtistCreditPreview: Equatable, Sendable {
    enum Basis: String, Codable, Sendable { case verifiedArtist, sourceCredit, unresolved }
    struct Source: Codable, Equatable, Sendable {
        let itemID: UUID
        let importID: UUID
        let artist: String
        let owner: String
    }
    struct Row: Identifiable, Codable, Equatable, Sendable {
        let id: UUID
        let videoID: String
        let title: String
        let before: String
        let after: String
        let basis: Basis
        let sources: [Source]
    }
    let store: URL
    let incorrectArtist: String
    let rows: [Row]

    func selectedRows(includingUnresolved: Bool) -> [Row] {
        rows.filter { includingUnresolved || $0.basis != .unresolved }
    }
}

struct ImportedArtistCreditRepairReceipt: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable { case prepared, applied, undoPrepared, undone }
    let version: Int
    let id: UUID
    let createdAt: Date
    let store: URL
    let changes: [ImportedArtistCreditPreview.Row]
    var state: State

    var fileURL: URL {
        store.deletingLastPathComponent().appending(path: "imported-artist-credit-repairs", directoryHint: .isDirectory)
            .appending(path: "\(id.uuidString).json")
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version && lhs.id == rhs.id && lhs.createdAt == rhs.createdAt
            && lhs.store.isFileURL && rhs.store.isFileURL
            && lhs.store.host == rhs.store.host
            && lhs.store.standardizedFileURL.path == rhs.store.standardizedFileURL.path
            && lhs.changes == rhs.changes && lhs.state == rhs.state
    }
}

/// Explicit, recoverable correction of a user-identified incorrect credit.
/// Neither source differences nor old display strings authorize an automatic repair.
@MainActor
enum ImportedArtistCreditRepair {
    typealias Receipt = ImportedArtistCreditRepairReceipt

    static func preview(incorrectArtist: String, in container: ModelContainer,
                        credits: SongCreditCache = .shared) throws -> ImportedArtistCreditPreview {
        let store = try storeURL(container)
        guard !incorrectArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportedArtistCreditRepairError.missingCredit
        }
        let context = ModelContext(container)
        let tracks = try context.fetch(FetchDescriptor<Track>())
        let items = try context.fetch(FetchDescriptor<YouTubeImportItem>())
        let rows = tracks.filter { $0.artist == incorrectArtist }.compactMap { track -> ImportedArtistCreditPreview.Row? in
            guard validVideoID(track.youTubeId) else { return nil }
            let sources = sourceEvidence(for: track, items: items)
            let metadata = credits.entry(videoID: track.youTubeId)
            let verified = metadata.flatMap { $0.id == track.youTubeId ? nonMissing($0.artist) : nil }
            let values = Set(sources.compactMap { nonMissing($0.artist) })
            let owners = Set(items.filter { $0.track?.id == track.id && $0.youTubeId == track.youTubeId }
                .compactMap { $0.import_?.channel })
            let source = values.count == 1 ? values.first : nil
            let after: String
            let basis: ImportedArtistCreditPreview.Basis
            if let verified, verified != incorrectArtist,
               !credits.isConfirmedIncorrectArtist(verified, videoID: track.youTubeId) {
                after = verified
                basis = .verifiedArtist
            } else if let source, source != incorrectArtist, !owners.contains(source) {
                after = source
                basis = .sourceCredit
            } else {
                after = ""
                basis = .unresolved
            }
            return .init(id: track.id, videoID: track.youTubeId, title: track.title,
                         before: track.artist, after: after, basis: basis, sources: sources)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        return .init(store: store, incorrectArtist: incorrectArtist, rows: rows)
    }

    static func apply(_ preview: ImportedArtistCreditPreview, includingUnresolved: Bool = false,
                      to container: ModelContainer, credits: SongCreditCache = .shared,
                      save: (ModelContext) throws -> Void = { try $0.save() },
                      onCommit: () -> Void = {},
                      persist: @MainActor (Receipt) throws -> Void = persistReceipt) throws -> Receipt {
        let store = try storeURL(container)
        guard preview.store == store else { throw ImportedArtistCreditRepairError.conflict }
        let previous = try receipts(in: container)
        guard !previous.contains(where: { $0.state == .prepared || $0.state == .undoPrepared }) else {
            throw ImportedArtistCreditRepairError.recoveryRequired
        }
        let changes = preview.selectedRows(includingUnresolved: includingUnresolved)
        guard !changes.isEmpty else { throw ImportedArtistCreditRepairError.noCandidates }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let tracks = try checkedTracks(changes, expectedAfter: false, in: context)
        let items = try context.fetch(FetchDescriptor<YouTubeImportItem>())
        guard changes.allSatisfy({ row in
            guard let track = tracks[row.id] else { return false }
            return track.title == row.title && sourceEvidence(for: track, items: items) == row.sources
        }) else { throw ImportedArtistCreditRepairError.conflict }
        let current = try Self.preview(incorrectArtist: preview.incorrectArtist, in: container, credits: credits)
        let proposals = Dictionary(uniqueKeysWithValues: current.rows.map { ($0.id, $0) })
        guard changes.allSatisfy({ row in
            guard let proposal = proposals[row.id] else { return false }
            // Eviction does not retract an exact artist value the user already
            // reviewed. A newly available or changed proof does require review.
            let proofWasEvicted = row.basis == .verifiedArtist
                && nonMissing(credits.entry(videoID: row.videoID)?.artist) == nil
            return proofWasEvicted || (proposal.after == row.after && proposal.basis == row.basis)
        }) else { throw ImportedArtistCreditRepairError.conflict }
        var receipt = Receipt(version: 1, id: UUID(), createdAt: Date(), store: store, changes: changes, state: .prepared)
        try validate(receipt, store: store)
        try persist(receipt)
        for change in changes { tracks[change.id]?.artist = change.after }
        do { try save(context) }
        catch {
            context.rollback()
            receipt.state = .undone
            try? persist(receipt)
            throw error
        }
        onCommit()
        // A finalization failure must retain the prepared record. The database
        // already committed; only an explicit Undo may write the old values back.
        receipt.state = .applied
        do { try persist(receipt) }
        catch {
            try? restoreConfirmedCredits(in: container, credits: credits)
            throw ImportedArtistCreditRepairError.recoveryRequired
        }
        try restoreConfirmedCredits(in: container, credits: credits)
        return receipt
    }

    static func undo(_ receipt: Receipt, in container: ModelContainer,
                     credits: SongCreditCache = .shared,
                     save: (ModelContext) throws -> Void = { try $0.save() },
                     onCommit: () -> Void = {},
                     persist: @MainActor (Receipt) throws -> Void = persistReceipt) throws -> Receipt {
        guard let stored = try receipts(in: container).first(where: { $0.id == receipt.id }),
              stored == receipt, receipt.state != .undone else { throw ImportedArtistCreditRepairError.conflict }
        var result = receipt
        let context = ModelContext(container)
        context.autosaveEnabled = false
        // Crash before Apply committed, or after Undo committed: finalize the
        // journal only. Startup itself never performs this write or a Track edit.
        if receipt.state != .applied,
           (try? checkedTracks(receipt.changes, expectedAfter: false, in: context)) != nil {
            result.state = .undone
            try persist(result)
            try restoreConfirmedCredits(in: container, credits: credits)
            return result
        }
        let tracks = try checkedTracks(receipt.changes, expectedAfter: true, in: context)
        result.state = .undoPrepared
        try persist(result)
        for change in receipt.changes { tracks[change.id]?.artist = change.before }
        do { try save(context) }
        catch {
            context.rollback()
            try? persist(receipt)
            throw error
        }
        onCommit()
        result.state = .undone
        do { try persist(result) }
        catch {
            try? restoreConfirmedCredits(in: container, credits: credits)
            throw ImportedArtistCreditRepairError.recoveryRequired
        }
        try restoreConfirmedCredits(in: container, credits: credits)
        return result
    }

    static func latestReceipt(in container: ModelContainer) throws -> Receipt? {
        let all = try receipts(in: container).sorted { $0.createdAt > $1.createdAt }
        return all.first { $0.state == .prepared || $0.state == .undoPrepared }
            ?? all.first { $0.state == .applied } ?? all.first
    }

    /// Read-only startup reconciliation. Applied receipts are durable evidence;
    /// a pending transaction proves a result only when every exact row agrees.
    static func restoreConfirmedCredits(in container: ModelContainer,
                                        credits: SongCreditCache = .shared) throws {
        let all: [Receipt]
        do { all = try receipts(in: container).sorted { $0.createdAt < $1.createdAt } }
        catch {
            credits.replaceConfirmedImportedArtistCredits([:])
            throw error
        }
        let context = ModelContext(container)
        let tracks = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Track>()).map { ($0.id, $0) })
        var confirmed: [String: [String: String]] = [:]
        var sourceCredits: [String: Set<String>] = [:]
        for receipt in all {
            let allBefore = receipt.changes.allSatisfy { tracks[$0.id]?.youTubeId == $0.videoID && tracks[$0.id]?.artist == $0.before }
            let allAfter = receipt.changes.allSatisfy { tracks[$0.id]?.youTubeId == $0.videoID && tracks[$0.id]?.artist == $0.after }
            let include: Bool
            switch receipt.state {
            case .applied: include = true
            case .undone: include = false
            case .prepared, .undoPrepared:
                guard allBefore || allAfter else {
                    credits.replaceConfirmedImportedArtistCredits([:])
                    throw ImportedArtistCreditRepairError.recoveryRequired
                }
                include = allAfter
            }
            guard include else { continue }
            for row in receipt.changes where tracks[row.id]?.youTubeId == row.videoID {
                confirmed[row.videoID, default: [:]][row.before] = row.after
                if row.basis == .sourceCredit { sourceCredits[row.videoID, default: []].insert(row.after) }
            }
        }
        credits.replaceConfirmedImportedArtistCredits(confirmed, sourceCredits: sourceCredits)
    }

    static func persistReceipt(_ receipt: Receipt) throws {
        try validate(receipt, store: receipt.store.standardizedFileURL)
        let data = try JSONEncoder().encode(receipt)
        guard data.count <= 8_388_608 else { throw ImportedArtistCreditRepairError.invalidReceipt }
        let directory = receipt.fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                   attributes: [.posixPermissions: 0o700])
        }
        let directoryValues = try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard directoryValues.isSymbolicLink != true, directoryValues.isDirectory == true else {
            throw ImportedArtistCreditRepairError.invalidReceipt
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        if FileManager.default.fileExists(atPath: receipt.fileURL.path) {
            let fileValues = try receipt.fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            guard fileValues.isSymbolicLink != true, fileValues.isRegularFile == true else {
                throw ImportedArtistCreditRepairError.invalidReceipt
            }
        }
        try data.write(to: receipt.fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: receipt.fileURL.path)
    }

    private static func storeURL(_ container: ModelContainer) throws -> URL {
        guard container.configurations.count == 1, let config = container.configurations.first,
              !config.isStoredInMemoryOnly else { throw ImportedArtistCreditRepairError.persistentStoreRequired }
        guard !container.mainContext.hasChanges else { throw ImportedArtistCreditRepairError.pendingEdits }
        return config.url.standardizedFileURL
    }

    private static func receipts(in container: ModelContainer) throws -> [Receipt] {
        let store = try storeURL(container)
        let directory = store.deletingLastPathComponent().appending(path: "imported-artist-credit-repairs", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let directoryValues = try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard directoryValues.isSymbolicLink != true, directoryValues.isDirectory == true else {
            throw ImportedArtistCreditRepairError.invalidReceipt
        }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            .filter { $0.pathExtension == "json" }.map { file in
                let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
                guard values.isSymbolicLink != true, values.isRegularFile == true,
                      let size = values.fileSize, size <= 8_388_608 else {
                    throw ImportedArtistCreditRepairError.invalidReceipt
                }
                let receipt = try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: file))
                try validate(receipt, store: store)
                guard sameFileLocation(receipt.fileURL, file) else { throw ImportedArtistCreditRepairError.invalidReceipt }
                return receipt
            }
    }

    private static func validate(_ receipt: Receipt, store: URL) throws {
        guard receipt.version == 1, sameFileLocation(receipt.store, store),
              !receipt.changes.isEmpty, receipt.changes.count <= 100_000,
              Set(receipt.changes.map(\.id)).count == receipt.changes.count,
              receipt.changes.allSatisfy({ validVideoID($0.videoID) && !$0.before.isEmpty && $0.before != $0.after
                  && (($0.basis == .unresolved) == $0.after.isEmpty) }) else {
            throw ImportedArtistCreditRepairError.invalidReceipt
        }
    }

    /// FileManager enumeration may produce relative/base-backed URL values.
    /// Compare the exact standardized absolute path, without following links.
    private static func sameFileLocation(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.isFileURL && rhs.isFileURL
            && lhs.host == rhs.host
            && lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }

    private static func checkedTracks(_ changes: [ImportedArtistCreditPreview.Row], expectedAfter: Bool,
                                      in context: ModelContext) throws -> [UUID: Track] {
        let tracks = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Track>()).map { ($0.id, $0) })
        guard changes.allSatisfy({ row in
            tracks[row.id]?.youTubeId == row.videoID && tracks[row.id]?.artist == (expectedAfter ? row.after : row.before)
        }) else { throw ImportedArtistCreditRepairError.conflict }
        return tracks
    }

    private static func sourceEvidence(for track: Track, items: [YouTubeImportItem]) -> [ImportedArtistCreditPreview.Source] {
        items.compactMap { item -> ImportedArtistCreditPreview.Source? in
            guard item.track?.id == track.id, item.youTubeId == track.youTubeId, let owner = item.import_ else { return nil }
            return .init(itemID: item.id, importID: owner.id, artist: item.artist, owner: owner.channel)
        }.sorted { $0.itemID.uuidString < $1.itemID.uuidString }
    }

    private static func validVideoID(_ value: String) -> Bool {
        YTDlpBridge.YTDlpPlaylistEntry(id: value, title: "").resourceKind == .video
    }

    private static func nonMissing(_ value: String?) -> String? {
        guard let value, !SongDisplayInformation.isMissingCredit(value) else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
