import Darwin
import Foundation
import SQLite3
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Pull persistence boundary", .serialized)
struct PlaylistPullPersistenceTests {
    enum Failure: Error { case save }

    @Test("Pull stages revision pruning and Local/Base in one save")
    func oneCommitIncludesPruning() throws {
        let (container, preview, oldIDs) = try fixture()
        var saves = 0
        let service = makeService(container) { context in
            saves += 1
            if saves > 1 { throw Failure.save }
            try context.save()
        }
        try service.applyPull(preview)
        #expect(saves == 1)
        let context = ModelContext(container)
        let stored = try #require(context.fetch(FetchDescriptor<YouTubeImport>()).first)
        #expect(stored.baseRevisionID != preview.baseRevisionID)
        #expect(YouTubePlaylistSyncService.localSnapshot(stored).items.map(\.videoID) == ["new-video"])
        let remaining = try context.fetch(FetchDescriptor<YouTubePlaylistRevision>())
        #expect(remaining.count == 50)
        #expect(Set(remaining.map(\.id)).intersection(oldIDs).count < oldIDs.count)
    }

    @Test("Failed Pull rolls back all staged rows and remains retryable on the same service")
    func failedCommitThenRetry() throws {
        let (container, preview, _) = try fixture()
        var saves = 0
        var failedContext: ModelContext?
        let service = makeService(container) { context in
            saves += 1
            if saves == 1 { failedContext = context; throw Failure.save }
            try context.save()
        }
        nonisolated(unsafe) var notifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .musesPlaylistsChanged, object: nil, queue: .main
        ) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        #expect(throws: Failure.self) { try service.applyPull(preview) }
        #expect(failedContext?.hasChanges == false)
        #expect(failedContext?.autosaveEnabled == false)
        #expect(notifications == 0)
        let beforeRetry = ModelContext(container)
        let original = try #require(beforeRetry.fetch(FetchDescriptor<YouTubeImport>()).first)
        #expect(original.baseRevisionID == preview.baseRevisionID)
        #expect(original.lastSyncedAt == nil)
        #expect(YouTubePlaylistSyncService.localSnapshot(original).items.map(\.videoID) == ["old-video"])
        #expect(try beforeRetry.fetchCount(FetchDescriptor<YouTubePlaylistRevision>()) == 63)
        #expect(try beforeRetry.fetchCount(FetchDescriptor<Track>()) == 0)
        try service.applyPull(preview)
        #expect(saves == 2)
        #expect(notifications == 1)
        let afterRetry = ModelContext(container)
        let changed = try #require(afterRetry.fetch(FetchDescriptor<YouTubeImport>()).first)
        #expect(changed.baseRevisionID != preview.baseRevisionID)
        #expect(YouTubePlaylistSyncService.localSnapshot(changed).items.map(\.videoID) == ["new-video"])
        #expect(try afterRetry.fetchCount(FetchDescriptor<YouTubePlaylistRevision>()) == 50)
    }

    // This process-wide fault must run alone in a dedicated test process.
    // MUSES_PULL_DISK_FAILURE_TEST=1 swift test --no-parallel --filter PlaylistPullPersistenceTests/diskFailureThenRetry
    @Test("A real disk write error rolls back Pull and permits the same preview to retry",
          .enabled(if: ProcessInfo.processInfo.environment["MUSES_PULL_DISK_FAILURE_TEST"] == "1"))
    func diskFailureThenRetry() throws {
        let filters = zip(CommandLine.arguments, CommandLine.arguments.dropFirst())
            .filter { $0.0 == "--filter" }.map(\.1)
        try #require(filters == ["PlaylistPullPersistenceTests/diskFailureThenRetry"],
                     "The disk fault must be the only selected test")
        try #require(CommandLine.arguments.contains("--no-parallel"))
        try #require(!CommandLine.arguments.contains { argument in
            argument.hasPrefix("--filter=") ||
                ["--parallel", "--skip", "--repetitions", "--repeat-until", "--maximum-repetitions"]
                    .contains { argument == $0 || argument.hasPrefix($0 + "=") }
        })
        let testID = try #require(Test.current?.id)
        try #require(testID.moduleName == "MusesTests")
        try #require(testID.nameComponents == ["PlaylistPullPersistenceTests", "diskFailureThenRetry()"])
        let directory = URL.homeDirectory.appending(path: ".muses/tmp")
            .appending(path: "pull-disk-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove the owned disk-test fixture") }
        }
        let store = directory.appending(path: "pull.sqlite")
        let expected = try autoreleasepool {
            let (container, preview, _) = try fixture(storeURL: store)
            let account = YouTubeAccountService(session: GoogleOAuthSession(keychain: InMemoryKeychain()))
            // Use the production save closure, with no injected Swift error.
            let service = YouTubePlaylistSyncService(modelContainer: container, account: account,
                                                     accountImportPreferences: nil)
            let original = try diskState(container)
            let originalRows = try persistedRows(store)
            try #require(original.revisions.count == 63)
            try #require(original.tracks.isEmpty)
            try #require(FileManager.default.fileExists(atPath: store.path + "-wal"))
            nonisolated(unsafe) var notifications = 0
            let observer = NotificationCenter.default.addObserver(
                forName: .musesPlaylistsChanged, object: nil, queue: .main
            ) { _ in notifications += 1 }
            defer { NotificationCenter.default.removeObserver(observer) }

            var failure: NSError?
            do {
                try withFileWritesDenied {
                    try service.applyPull(preview, resolvedSnapshot: preview.remote)
                }
            } catch { failure = error as NSError }
            let error = try #require(failure, "The actual persistent-store save must fail")
            #expect(error.domain == "NSSQLiteErrorDomain")
            #expect(error.code == 778) // SQLITE_IOERR_WRITE, not a busy lock or a read-only configuration.
            #expect(error.userInfo["NSFilePath"] as? String == store.path)
            #expect(try persistedRows(store) == originalRows)
            #expect(try diskState(container) == original)
            #expect(notifications == 0)

            try service.applyPull(preview, resolvedSnapshot: preview.remote)
            let saved = try diskState(container)
            #expect(notifications == 1)
            #expect(saved.baseID != original.baseID)
            #expect(saved.remoteID == original.remoteID)
            #expect(saved.lastSyncedAt != nil)
            #expect(saved.items == preview.remote.normalizedItems)
            #expect(saved.revisions.count == 50)
            #expect(saved.revisions.values.filter { $0.kind == "beforePull" }.count == 1)
            #expect(saved.tracks.values.map(\.videoID) == ["new-video"])
            #expect(saved.tracks.values.allSatisfy { $0.libraryMember == true })
            return saved
        }
        // A new container must reconstruct the successful commit from disk.
        try autoreleasepool {
            let reopened = try makeModelContainer(storeURL: store)
            #expect(try diskState(reopened) == expected)
        }
    }

    private func withFileWritesDenied(_ operation: () throws -> Void) throws {
        var originalLimit = rlimit()
        try #require(getrlimit(RLIMIT_FSIZE, &originalLimit) == 0)
        var originalSignal = sigaction()
        try #require(sigaction(SIGXFSZ, nil, &originalSignal) == 0)
        var ignoredSignal = sigaction()
        ignoredSignal.__sigaction_u.__sa_handler = SIG_IGN
        sigemptyset(&ignoredSignal.sa_mask)
        try #require(sigaction(SIGXFSZ, &ignoredSignal, nil) == 0)
        defer { #expect(sigaction(SIGXFSZ, &originalSignal, nil) == 0) }
        // Zero also rejects writes to an existing WAL, even if it reuses pages.
        // The hard limit is unchanged, so restoring the soft limit needs no privilege.
        var deniedLimit = rlimit(rlim_cur: 0, rlim_max: originalLimit.rlim_max)
        try #require(setrlimit(RLIMIT_FSIZE, &deniedLimit) == 0)
        defer { #expect(setrlimit(RLIMIT_FSIZE, &originalLimit) == 0) }
        try operation()
    }

    private struct SQLiteCell: Equatable {
        let type: Int32
        let bytes: Data
    }

    /// Read committed rows through an independent read-only SQLite connection,
    /// so the failure audit cannot be satisfied by SwiftData's in-process cache.
    private func persistedRows(_ store: URL) throws -> [String: [[SQLiteCell]]] {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(store.path, &database, SQLITE_OPEN_READONLY, nil)
        defer { sqlite3_close(database) }
        try #require(result == SQLITE_OK)
        var tables: [String: [[SQLiteCell]]] = [:]
        for table in ["ZYOUTUBEIMPORT", "ZYOUTUBEIMPORTITEM", "ZYOUTUBEPLAYLISTREVISION", "ZTRACK"] {
            var statement: OpaquePointer?
            try #require(sqlite3_prepare_v2(database, "SELECT * FROM \(table) ORDER BY Z_PK",
                                           -1, &statement, nil) == SQLITE_OK)
            defer { sqlite3_finalize(statement) }
            var rows: [[SQLiteCell]] = []
            var step = sqlite3_step(statement)
            while step == SQLITE_ROW {
                rows.append((0..<sqlite3_column_count(statement)).map { index in
                    let type = sqlite3_column_type(statement, index)
                    let value = sqlite3_column_blob(statement, index)
                    let data = value.map { Data(bytes: $0, count: Int(sqlite3_column_bytes(statement, index))) }
                    return SQLiteCell(type: type, bytes: data ?? Data())
                })
                step = sqlite3_step(statement)
            }
            try #require(step == SQLITE_DONE)
            tables[table] = rows
        }
        return tables
    }

    private struct DiskState: Equatable {
        struct StoredRevision: Equatable {
            let importID: UUID
            let accountChannelID: String?
            let kind: String
            let createdAt: Date
            let snapshotData: Data
            let fingerprint: String
            let pinned: Bool
        }
        struct StoredTrack: Equatable {
            let videoID: String?
            let title: String
            let libraryMember: Bool?
        }
        let importID: UUID
        let baseID: UUID?
        let remoteID: UUID?
        let lastSyncedAt: Date?
        let items: [YouTubePlaylistItemSnapshot]
        let itemIDs: Set<UUID>
        let itemTracks: [UUID: UUID]
        let revisions: [UUID: StoredRevision]
        let tracks: [UUID: StoredTrack]
    }

    private func diskState(_ container: ModelContainer) throws -> DiskState {
        let context = ModelContext(container)
        let imports = try context.fetch(FetchDescriptor<YouTubeImport>())
        try #require(imports.count == 1)
        let imported = try #require(imports.first)
        let items = try context.fetch(FetchDescriptor<YouTubeImportItem>())
        let revisions = try context.fetch(FetchDescriptor<YouTubePlaylistRevision>())
        let tracks = try context.fetch(FetchDescriptor<Track>())
        return DiskState(importID: imported.id, baseID: imported.baseRevisionID,
            remoteID: imported.remoteShadowRevisionID, lastSyncedAt: imported.lastSyncedAt,
            items: YouTubePlaylistSyncService.localSnapshot(imported).normalizedItems,
            itemIDs: Set(items.map(\.id)),
            itemTracks: Dictionary(uniqueKeysWithValues: items.compactMap { item in
                item.track.map { (item.id, $0.id) }
            }),
            revisions: Dictionary(uniqueKeysWithValues: revisions.map {
                ($0.id, .init(importID: $0.importID, accountChannelID: $0.accountChannelID,
                             kind: $0.kindRaw, createdAt: $0.createdAt, snapshotData: $0.snapshotData,
                             fingerprint: $0.fingerprint, pinned: $0.pinned))
            }),
            tracks: Dictionary(uniqueKeysWithValues: tracks.map {
                ($0.id, .init(videoID: $0.youTubeId, title: $0.title, libraryMember: $0.libraryMember))
            }))
    }

    private func makeService(_ container: ModelContainer,
                             save: @escaping (ModelContext) throws -> Void) -> YouTubePlaylistSyncService {
        YouTubePlaylistSyncService(modelContainer: container,
            account: YouTubeAccountService(session: GoogleOAuthSession(keychain: InMemoryKeychain())),
            accountImportPreferences: nil, savePullContext: save)
    }

    private func fixture(storeURL: URL? = nil) throws -> (ModelContainer, YouTubePullPreview, Set<UUID>) {
        let container = try makeModelContainer(inMemory: storeURL == nil, storeURL: storeURL)
        let context = ModelContext(container)
        let imported = YouTubeImport(playlistId: "PL-pull-persistence", url: "", title: "Test", channel: "Owner")
        let old = YouTubeImportItem(youTubeId: "old-video", title: "Old", artist: "Artist", order: 0)
        old.import_ = imported; imported.items = [old]
        context.insert(imported); context.insert(old)
        let local = YouTubePlaylistSyncService.localSnapshot(imported)
        var remote = local
        remote.items = [.init(id: UUID(), playlistItemID: "pi-new", videoID: "new-video",
            title: "New", artist: "Artist", durationMs: 1, order: 0, availability: .available)]
        remote.pagination = .init(completeness: .complete, pageCount: 1, nextPageToken: nil, itemCount: 1)
        func revision(_ kind: YouTubePlaylistRevisionKind, _ value: YouTubePlaylistSnapshot,
                      createdAt: Date = .init()) throws -> YouTubePlaylistRevision {
            let result = YouTubePlaylistRevision(importID: imported.id, accountChannelID: nil,
                kind: kind, createdAt: createdAt, snapshotData: try JSONEncoder().encode(value),
                fingerprint: value.fingerprint)
            context.insert(result)
            return result
        }
        let base = try revision(.base, local)
        let draft = try revision(.local, local)
        let shadow = try revision(.remoteShadow, remote)
        var oldIDs = Set<UUID>()
        for index in 0..<60 {
            oldIDs.insert(try revision(.local, local,
                createdAt: Date(timeIntervalSince1970: Double(index))).id)
        }
        imported.baseRevisionID = base.id; imported.remoteShadowRevisionID = shadow.id
        try context.save()
        let preview = YouTubePullPreview(importID: imported.id, baseRevisionID: base.id,
            localRevisionID: draft.id, remoteRevisionID: shadow.id, base: local, local: local,
            remote: remote, automaticResult: remote,
            mergePlan: YouTubePlaylistThreeWayMerge.plan(base: local, local: local, remote: remote))
        return (container, preview, oldIDs)
    }
}
