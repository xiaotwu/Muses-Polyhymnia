import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("Existing queue occurrence activation", .serialized)
struct QueueActivationTests {
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
}
