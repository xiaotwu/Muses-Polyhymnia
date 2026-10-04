import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Existing queue occurrence activation", .serialized)
struct QueueActivationTests {
    @Test("Repeated occurrence history actions target the selected older record, not its newer snapshot", arguments: [false, true])
    func repeatedHistoryRecordTarget(restore: Bool) throws {
        let queue = QueueService()
        let recording = track("repeated")
        queue.play(recording, context: [recording], from: .playlist)
        let firstGroup = queue.addGroup("First"), secondGroup = queue.addGroup("Second")
        let occurrenceID = try #require(queue.current()).id
        queue.setRepeat(.one)
        queue.setGroupId(itemId: occurrenceID, to: firstGroup)
        _ = queue.next(as: .skipped)
        let selected = try #require(queue.history.first)
        queue.toggleLocked(itemId: occurrenceID)
        queue.setGroupId(itemId: occurrenceID, to: secondGroup)
        _ = queue.next(as: .played)
        #expect(queue.history.map(\.id) == [occurrenceID, occurrenceID])
        let selectedRecordID = try #require(selected.historyRecordID)
        #expect(Set(queue.history.compactMap(\.historyRecordID)).count == 2)
        if restore {
            queue.restoreHistoryRecord(id: selectedRecordID)
            #expect(queue.upNext.last?.locked == false)
            #expect(queue.upNext.last?.groupId == firstGroup)
            #expect(queue.upNext.last?.historyRecordID == nil)
        } else {
            queue.removeHistoryRecord(id: selectedRecordID)
            #expect(queue.upNext.isEmpty)
        }
        #expect(queue.history.first?.historyState == .played)
        #expect(queue.current()?.id == occurrenceID)
        #expect(queue.current()?.locked == true)
        #expect(queue.current()?.groupId == secondGroup)
        let remainingRecordID = try #require(queue.history.first?.historyRecordID)
        queue.removeHistoryRecord(id: selectedRecordID) // A delayed confirmation for the consumed record is stale.
        queue.restoreHistoryRecord(id: selectedRecordID)
        #expect(queue.history.first?.historyRecordID == remainingRecordID)
        #expect(queue.history.count == 1)
        queue.removeHistoryRecord(id: remainingRecordID)
        #expect(queue.history.isEmpty)
    }

    @Test("legacy repeated history gains stable record identities without changing occurrence truth", arguments: [false, true])
    func legacyHistoryRecordIdentity(duplicateRecordID: Bool) throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let recording = track("repeated")
        queue.play(recording, context: [recording], from: .playlist)
        let occurrenceID = try #require(queue.current()).id
        let group = queue.addGroup("Group")
        queue.setRepeat(.one)
        _ = queue.next(as: .skipped)
        queue.toggleLocked(itemId: occurrenceID)
        queue.setGroupId(itemId: occurrenceID, to: group)
        _ = queue.next(as: .played)
        let context = ModelContext(container)
        let saved = try #require(context.fetch(FetchDescriptor<QueueState>()).first)
        var legacy = try #require(JSONSerialization.jsonObject(with: Data(saved.historyJSON.utf8)) as? [[String: Any]])
        let sharedRecordID = UUID().uuidString
        for index in legacy.indices {
            if duplicateRecordID { legacy[index]["historyRecordID"] = sharedRecordID }
            else { legacy[index].removeValue(forKey: "historyRecordID") }
        }
        let canonicalJSON = saved.itemsJSON, groupsJSON = saved.groupsJSON
        let savedAt = saved.savedAt
        saved.historyJSON = String(decoding: try JSONSerialization.data(withJSONObject: legacy), as: UTF8.self)
        try context.save()
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        let records = restored.history.compactMap(\.historyRecordID)
        #expect(records.count == 2 && Set(records).count == 2)
        #expect(restored.history.map(\.id) == [occurrenceID, occurrenceID])
        #expect(restored.history.map(\.historyState) == [.played, .skipped])
        #expect(restored.history.map(\.locked) == [true, false])
        #expect(restored.history.map(\.groupId) == [group, nil])
        #expect(restored.items.map(\.id) == [occurrenceID])
        #expect(restored.current()?.historyRecordID == nil)
        let persisted = try #require(ModelContext(container).fetch(FetchDescriptor<QueueState>()).first)
        #expect(persisted.itemsJSON == canonicalJSON)
        #expect(persisted.groupsJSON == groupsJSON)
        #expect(persisted.savedAt == savedAt)
        let reopened = QueueService()
        reopened.modelContext = ModelContext(container)
        reopened.restore()
        #expect(reopened.history.compactMap(\.historyRecordID) == records)
        reopened.restoreHistoryRecord(id: records[1])
        #expect(reopened.upNext.first?.historyRecordID == nil)
        #expect(reopened.upNext.first?.id != occurrenceID)
        #expect(reopened.upNext.first?.locked == false)
        #expect(reopened.upNext.first?.groupId == nil)
        #expect(reopened.history.first?.historyRecordID == records[0])
    }

    @Test("Previous clears a consumed history record identity before an insertion plays again")
    func previousClearsHistoryRecord() throws {
        let queue = QueueService()
        let first = track("first")
        queue.play(first, context: [first], from: .playlist)
        queue.playNext(track("inserted"))
        _ = queue.next()
        let insertionID = try #require(queue.current()).id
        queue.setRepeat(.one)
        _ = queue.next()
        let recordID = try #require(queue.history.first?.historyRecordID)
        _ = queue.previous()
        #expect(queue.current()?.id == insertionID)
        #expect(queue.current()?.historyRecordID == nil)
        _ = queue.next()
        #expect(queue.history.first?.id == insertionID)
        #expect(queue.history.first?.historyRecordID != recordID)
    }

    private func track(_ title: String) -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: title, artist: "Artist", albumTitle: nil,
                      durationSeconds: 120, youTubeId: title, artworkUrl: nil,
                      sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
    }

    @Test("Repeated collection tracks retain occurrence identity, groups, locks and insertions")
    func collectionOccurrence() {
        let queue = QueueService()
        let repeated = track("repeat")
        queue.play(repeated, context: [repeated, track("middle"), repeated], from: .playlist)
        let group = UUID()
        queue.items[2].groupId = group
        queue.items[2].locked = true
        queue.playNext(track("insertion"))
        let ids = queue.items.map(\.id)
        let insertionID = queue.upNext[0].id
        let priorHistory = QueueItem(track: track("prior"), historyState: .played)
        queue.history = [priorHistory]
        _ = queue.activateItem(id: ids[2])
        #expect(queue.current()?.id == ids[2])
        #expect(queue.items.map(\.id) == ids)
        #expect(queue.current()?.groupId == group)
        #expect(queue.current()?.locked == true)
        #expect(queue.upNext.map(\.id) == [insertionID])
        #expect(queue.history.map(\.id) == [priorHistory.id])
        #expect(queue.history.first?.historyState == .played)
    }

    @Test("Selected insertion alone is consumed; remaining insertion and collection resume survive restart")
    func insertionRoundTrip() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let first = track("first"), second = track("second"), repeated = track("inserted")
        queue.play(first, context: [first, second], from: .playlist)
        queue.addToQueue(repeated)
        queue.addToQueue(repeated)
        let firstInsertion = queue.upNext[0].id
        let selectedID = queue.upNext[1].id
        let group = UUID()
        queue.upNext[1].locked = true
        queue.upNext[1].groupId = group
        let collectionIDs = queue.items.map(\.id)
        _ = queue.activateItem(id: selectedID)
        #expect(queue.current()?.id == selectedID)
        #expect(queue.current()?.collectionAnchorID == collectionIDs[0])
        #expect(queue.current()?.locked == true)
        #expect(queue.current()?.groupId == group)
        #expect(queue.upNext.map(\.id) == [firstInsertion])
        #expect(queue.items.map(\.id) == collectionIDs)
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        #expect(restored.current()?.id == selectedID)
        #expect(restored.current()?.groupId == group)
        #expect(restored.next()?.id == firstInsertion)
        #expect(restored.next()?.id == collectionIDs[1])
        #expect(restored.history.map(\.id) == [firstInsertion, selectedID])
    }

    @Test("Stale identities do not mutate the queue and selecting current does not duplicate history")
    func staleAndCurrent() {
        let queue = QueueService()
        let first = track("first")
        queue.play(first, context: [first], from: .songs)
        queue.playNext(track("insertion"))
        let currentID = queue.current()!.id
        let insertionID = queue.upNext[0].id
        #expect(queue.activateItem(id: UUID()) == nil)
        #expect(queue.activateItem(id: currentID)?.id == currentID)
        #expect(queue.history.isEmpty)
        #expect(queue.upNext.map(\.id) == [insertionID])
    }

    @Test("Facade loads the selected duplicate occurrence and ignores a stale activation")
    func facadeActivation() async {
        let engine = RecordingEngine()
        let queue = QueueService()
        let playback = PlaybackService(engine: engine, queue: queue)
        let repeated = track("repeat")
        playback.playTrack(repeated, context: [repeated, repeated], from: .playlist)
        for _ in 0..<200 where engine.loadCallCount == 0 { await Task.yield() }
        queue.playNext(track("insertion"))
        let ids = queue.items.map(\.id)
        playback.playQueueItem(id: ids[1])
        for _ in 0..<200 where engine.loadCallCount < 2 { await Task.yield() }
        #expect(queue.current()?.id == ids[1])
        #expect(queue.items.map(\.id) == ids)
        #expect(queue.upNext.count == 1)
        #expect(engine.loadCallCount == 2)
        let historyIDs = queue.history.map(\.id)
        playback.playQueueItem(id: UUID())
        for _ in 0..<20 { await Task.yield() }
        #expect(engine.loadCallCount == 2)
        #expect(queue.history.map(\.id) == historyIDs)
    }

    @Test("Queue menu toggles only the current occurrence; other surfaces retain track matching")
    func menuOccurrenceIdentity() {
        let trackID = UUID(), currentID = UUID(), duplicateID = UUID()
        #expect(TrackContextMenuPlaybackPolicy.isCurrent(
            snapshotID: trackID, currentTrackID: trackID,
            queueItemID: currentID, currentQueueItemID: currentID))
        #expect(!TrackContextMenuPlaybackPolicy.isCurrent(
            snapshotID: trackID, currentTrackID: trackID,
            queueItemID: duplicateID, currentQueueItemID: currentID))
        #expect(!TrackContextMenuPlaybackPolicy.isCurrent(
            snapshotID: trackID, currentTrackID: trackID,
            queueItemID: duplicateID, currentQueueItemID: nil))
        #expect(TrackContextMenuPlaybackPolicy.isCurrent(
            snapshotID: trackID, currentTrackID: trackID,
            queueItemID: nil, currentQueueItemID: nil))
        #expect(!TrackContextMenuPlaybackPolicy.isCurrent(
            snapshotID: UUID(), currentTrackID: trackID,
            queueItemID: nil, currentQueueItemID: nil))
        #expect(!TrackContextMenuPlaybackPolicy.isCurrent(
            snapshotID: trackID, currentTrackID: trackID,
            queueItemID: currentID, currentQueueItemID: currentID,
            allowsCurrentPlaybackAction: false))
    }

    @Test("Moving and deleting a group preserves the active insertion and unlinks restored history")
    func deletingActiveInsertionGroup() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let group = queue.addGroup("Selected"), remaining = queue.addGroup("Remaining")
        let first = track("first"), removed = track("removed")
        queue.play(first, context: [first, removed], from: .playlist)
        let anchorID = queue.items[0].id
        queue.items[1].groupId = group
        queue.items[1].locked = true
        let historyID = queue.items[1].id
        queue.removeItem(at: 1)
        queue.addToQueue(track("insertion"))
        queue.upNext[0].groupId = group
        queue.upNext[0].locked = true
        let insertionID = queue.upNext[0].id
        _ = queue.activateItem(id: insertionID)
        queue.moveGroup(from: 0, to: 1)
        #expect(queue.current()?.id == insertionID)
        #expect(queue.current()?.groupId == group)
        #expect(queue.current()?.locked == true)
        queue.removeGroup(id: group)
        #expect(queue.groups.map(\.id) == [remaining])
        #expect(queue.current()?.id == insertionID)
        #expect(queue.current()?.groupId == nil)
        #expect(queue.current()?.locked == true)
        #expect(queue.current()?.collectionAnchorID == anchorID)
        #expect(queue.history.first?.id == historyID)
        #expect(queue.history.first?.historyState == .removed)
        #expect(queue.history.first?.locked == true)
        #expect(queue.history.first?.groupId == nil)
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        #expect(restored.current()?.id == insertionID)
        #expect(restored.current()?.groupId == nil)
        #expect(restored.current()?.locked == true)
        #expect(restored.current()?.collectionAnchorID == anchorID)
        restored.restoreFromHistory(at: 0)
        #expect(restored.upNext.first?.id == historyID)
        #expect(restored.upNext.first?.locked == true)
        #expect(restored.upNext.first?.groupId == nil)
        restored.playAfterCurrentGroup(track("new"))
        #expect(restored.items.map(\.id) == [anchorID])
        #expect(restored.upNext.first?.track.title == "new")
    }

    @Test("Restoring played collection history creates an independent insertion occurrence")
    func restoredCollectionCollision() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let first = track("first"), second = track("second")
        queue.play(first, context: [first, second], from: .playlist)
        let originalID = queue.items[0].id
        let group = queue.addGroup("Group")
        queue.items[0].groupId = group
        queue.items[0].locked = true
        queue.items[0].priority = 7
        let queuedAt = queue.items[0].queuedAt
        _ = queue.next()
        queue.restoreFromHistory(at: 0)
        let insertion = try #require(queue.upNext.first)
        #expect(insertion.id != originalID)
        #expect(insertion.track == first)
        #expect(insertion.fromContext == .playlist)
        #expect(insertion.queuedAt == queuedAt)
        #expect(insertion.groupId == group)
        #expect(insertion.locked)
        #expect(insertion.priority == 7)
        #expect(insertion.historyState == nil)
        _ = queue.activateItem(id: insertion.id)
        #expect(queue.currentIndex == 1)
        #expect(queue.current()?.id == insertion.id)
        #expect(queue.upNext.isEmpty)
        #expect(queue.items[0].id == originalID)
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        #expect(restored.current()?.id == insertion.id)
        #expect(restored.currentIndex == 1)
        #expect(restored.items[0].id == originalID)
    }

    @Test("Restore rekeys collisions with Up Next or active insertion but keeps removed identities")
    func restoredOtherCollisions() throws {
        let queue = QueueService()
        let first = track("first")
        queue.play(first, context: [first], from: .songs)
        queue.playNext(track("inserted"))
        let insertionID = queue.upNext[0].id
        var historical = queue.upNext[0]
        historical.historyState = .played
        historical.collectionAnchorID = queue.items[0].id
        historical.recommendationSourceVideoID = "old-recommendation"
        queue.history = [historical]
        queue.restoreFromHistory(at: 0)
        let restoredInsertion = try #require(queue.upNext.last)
        #expect(restoredInsertion.id != insertionID)
        #expect(restoredInsertion.collectionAnchorID == historical.collectionAnchorID)
        #expect(restoredInsertion.recommendationSourceVideoID == nil)
        _ = queue.activateItem(id: insertionID)
        queue.history = [historical]
        queue.restoreFromHistory(at: 0)
        #expect(queue.upNext.last?.id != insertionID)
        #expect(queue.current()?.id == insertionID)
        let removedID = try #require(queue.upNext.last).id
        queue.removeUpNext(at: queue.upNext.count - 1)
        queue.restoreFromHistory(at: 0)
        #expect(queue.upNext.last?.id == removedID)
        #expect(queue.upNext.last?.historyState == nil)
    }

    @Test("Previous after repeating an insertion does not also enqueue the same occurrence")
    func previousRepeatedInsertion() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let first = track("first"), second = track("second")
        queue.play(first, context: [first, second], from: .playlist)
        let anchorID = queue.items[0].id
        let group = queue.addGroup("Group")
        queue.playNext(track("inserted"))
        queue.upNext[0].locked = true
        queue.upNext[0].groupId = group
        let insertionID = queue.upNext[0].id
        #expect(queue.next()?.id == insertionID)
        queue.setRepeat(.one)
        #expect(queue.next()?.id == insertionID)
        #expect(queue.history.map(\.id) == [insertionID, anchorID])
        #expect(queue.previous()?.id == insertionID)
        #expect(queue.upNext.isEmpty)
        #expect(queue.history.map(\.id) == [anchorID])
        #expect(queue.current()?.locked == true)
        #expect(queue.current()?.groupId == group)
        #expect(queue.current()?.collectionAnchorID == anchorID)
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        #expect(restored.repeatMode == .one)
        #expect(restored.current()?.id == insertionID)
        #expect(restored.current()?.locked == true)
        #expect(restored.current()?.groupId == group)
        #expect(restored.current()?.collectionAnchorID == anchorID)
        #expect(restored.upNext.isEmpty)
        #expect(restored.previous()?.id == anchorID)
        #expect(restored.upNext.map(\.id) == [insertionID])
        #expect(restored.next()?.id == insertionID)
        #expect(restored.upNext.isEmpty)
    }

    @Test("Previous with empty history returns a directly selected insertion to its collection anchor", arguments: [0, 1])
    func previousDirectInsertion(anchorIndex: Int) throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let tracks = [track("first"), track("second")]
        queue.play(tracks[anchorIndex], context: tracks, from: .playlist)
        let collectionIDs = queue.items.map(\.id)
        let group = queue.addGroup("Group")
        queue.addToQueue(track("insertion"))
        queue.upNext[0].locked = true
        queue.upNext[0].groupId = group
        let insertionID = queue.upNext[0].id
        _ = queue.activateItem(id: insertionID)
        #expect(queue.history.isEmpty)
        #expect(queue.previous()?.id == collectionIDs[anchorIndex])
        #expect(queue.currentIndex == anchorIndex)
        #expect(queue.upNext.map(\.id) == [insertionID])
        #expect(queue.upNext.first?.locked == true)
        #expect(queue.upNext.first?.groupId == group)
        #expect(queue.history.isEmpty)
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        #expect(restored.current()?.id == collectionIDs[anchorIndex])
        #expect(restored.items.map(\.id) == collectionIDs)
        #expect(restored.next()?.id == insertionID)
        #expect(restored.current()?.collectionAnchorID == collectionIDs[anchorIndex])
    }

    @Test("Facade Previous loads a different occurrence of the same track at anchor zero")
    func facadePreviousDuplicateInsertion() async {
        let engine = RecordingEngine()
        let queue = QueueService()
        let playback = PlaybackService(engine: engine, queue: queue)
        let repeated = track("repeat")
        playback.playTrack(repeated, context: [repeated], from: .playlist)
        for _ in 0..<200 where engine.loadCallCount < 1 { await Task.yield() }
        let anchorID = queue.current()!.id
        queue.playNext(repeated)
        let insertionID = queue.upNext[0].id
        playback.playQueueItem(id: insertionID)
        for _ in 0..<200 where engine.loadCallCount < 2 { await Task.yield() }
        playback.previous()
        for _ in 0..<200 where engine.loadCallCount < 3 { await Task.yield() }
        #expect(queue.current()?.id == anchorID)
        #expect(queue.upNext.map(\.id) == [insertionID])
        #expect(engine.loadCallCount == 3)
        #expect(queue.history.isEmpty)
    }

    @Test("Locking an active insertion targets its occurrence and survives restart")
    func activeInsertionLock() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let first = track("first"), second = track("second")
        queue.play(second, context: [first, second], from: .playlist)
        let anchorID = queue.current()!.id
        let collectionIDs = queue.items.map(\.id)
        queue.playNext(second)
        let insertionID = queue.upNext[0].id
        _ = queue.activateItem(id: insertionID)
        queue.toggleLocked(itemId: insertionID)
        #expect(queue.current()?.locked == true)
        #expect(queue.current()?.id == insertionID)
        #expect(queue.current()?.collectionAnchorID == anchorID)
        #expect(queue.items.map(\.id) == collectionIDs)
        #expect(queue.items.allSatisfy { !$0.locked })
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        #expect(restored.current()?.id == insertionID)
        #expect(restored.current()?.locked == true)
        #expect(restored.current()?.collectionAnchorID == anchorID)
        restored.toggleLocked(itemId: UUID())
        #expect(restored.current()?.locked == true)
        restored.toggleLocked(itemId: insertionID)
        #expect(restored.current()?.locked == false)
    }

    @Test("Active insertion group edits reject stale references and retain identity through reorder and restart")
    func activeInsertionGroup() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let first = track("first"), second = track("second")
        queue.play(second, context: [first, second], from: .playlist)
        let collectionIDs = queue.items.map(\.id)
        let anchorID = queue.current()!.id
        let deletedGroup = queue.addGroup("Deleted"), targetGroup = queue.addGroup("Target")
        let otherGroup = queue.addGroup("Other")
        queue.playNext(second)
        let insertionID = queue.upNext[0].id
        queue.setGroupId(itemId: insertionID, to: deletedGroup)
        #expect(queue.upNext.first?.groupId == deletedGroup)
        _ = queue.activateItem(id: insertionID)
        queue.toggleLocked(itemId: insertionID)
        queue.setGroupId(itemId: insertionID, to: targetGroup)
        queue.removeGroup(id: deletedGroup)
        queue.setGroupId(itemId: insertionID, to: deletedGroup)
        queue.setGroupId(itemId: UUID(), to: targetGroup)
        #expect(queue.current()?.groupId == targetGroup)
        #expect(queue.items.allSatisfy { $0.groupId == nil })
        queue.move(from: 1, to: 0)
        queue.moveGroup(from: 0, to: 1)
        #expect(queue.current()?.id == insertionID)
        #expect(queue.current()?.collectionAnchorID == anchorID)
        #expect(queue.items.map(\.id) == Array(collectionIDs.reversed()))
        #expect(queue.groups.map(\.id) == [otherGroup, targetGroup])
        let restored = QueueService()
        restored.modelContext = ModelContext(container)
        restored.restore()
        #expect(restored.current()?.id == insertionID)
        #expect(restored.current()?.groupId == targetGroup)
        #expect(restored.current()?.locked == true)
        #expect(restored.current()?.collectionAnchorID == anchorID)
        #expect(restored.currentIndex == 0)
        #expect(restored.groups.map(\.id) == [otherGroup, targetGroup])
        restored.setGroupId(itemId: insertionID, to: nil)
        #expect(restored.current()?.groupId == nil)
        #expect(restored.current()?.locked == true)
        #expect(restored.items.map(\.id) == Array(collectionIDs.reversed()))
        #expect(restored.upNext.isEmpty)
        #expect(restored.history.isEmpty)
    }
}
