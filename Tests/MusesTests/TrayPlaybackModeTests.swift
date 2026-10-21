import Testing
import Foundation
import SwiftData
@testable import Muses

@MainActor
@Suite("TrayPlaybackMode")
struct TrayPlaybackModeTests {
    private func track(_ title: String) -> TrackSnapshot {
        TrackSnapshot(id: UUID(), title: title, artist: "Artist", albumTitle: nil,
                      durationSeconds: 180, youTubeId: title, artworkUrl: nil,
                      sampleRate: nil, bitDepth: nil, codec: nil, isLossless: false)
    }

    @Test("A complete mode cycle preserves the collection, current occurrence and manual insertions")
    func cyclePreservesQueue() {
        let queue = QueueService()
        let collection = [track("a"), track("b"), track("c"), track("d")]
        queue.play(collection[1], context: collection, from: .playlist)
        queue.playNext(track("manual"))
        queue.toggleLocked(itemId: queue.items[2].id)
        let original = queue.items
        let current = queue.current()?.id
        let upNext = queue.upNext
        for expected in [TrayPlaybackMode.repeatOne, .repeatAll, .shuffle, .inOrder] {
            TrayPlaybackMode(repeatMode: queue.repeatMode, shuffle: queue.shuffle).next.apply(to: queue)
            #expect(TrayPlaybackMode(repeatMode: queue.repeatMode, shuffle: queue.shuffle) == expected)
            #expect(queue.current()?.id == current)
            #expect(queue.upNext == upNext)
            #expect(queue.history.isEmpty)
            #expect(Set(queue.items.map(\.id)) == Set(original.map(\.id)))
            #expect(queue.items[2].id == original[2].id)
            #expect(queue.items[2].locked)
        }
        #expect(queue.items == original)
        #expect(queue.currentIndex == 1)
        #expect(queue.next()?.id == upNext.first?.id)
        #expect(queue.next()?.id == original[2].id)
    }

    @Test("Changing modes while an insertion is current preserves its anchor and history")
    func activeInsertion() {
        let queue = QueueService()
        let collection = [track("a"), track("b"), track("c")]
        queue.play(collection[0], context: collection, from: .album)
        queue.playNext(track("active"))
        _ = queue.next()
        queue.playNext(track("pending"))
        let current = queue.current()
        let pending = queue.upNext
        let history = queue.history
        for mode in [TrayPlaybackMode.shuffle, .repeatOne, .repeatAll, .inOrder] {
            mode.apply(to: queue)
            #expect(queue.current() == current)
            #expect(queue.current()?.collectionAnchorID == current?.collectionAnchorID)
            #expect(queue.upNext == pending)
            #expect(queue.history == history)
            #expect(queue.history.map(\.historyState) == history.map(\.historyState))
            #expect(queue.history.map(\.historyRecordID) == history.map(\.historyRecordID))
        }
        #expect(queue.next()?.id == pending.first?.id)
        #expect(queue.next()?.track.id == collection[1].id)
    }

    @Test("Applying the active shuffle mode does not reshuffle the collection")
    func applyingActiveModeIsStable() {
        let queue = QueueService()
        let collection = [track("a"), track("b"), track("c")]
        queue.play(collection[0], context: collection, from: .album)
        TrayPlaybackMode.shuffle.apply(to: queue)
        let shuffled = queue.items.map(\.id)
        TrayPlaybackMode.shuffle.apply(to: queue)
        #expect(queue.items.map(\.id) == shuffled)
        #expect(queue.shuffle)
        #expect(queue.repeatMode == .off)
    }

    @Test("Modes reflect externally combined states and normalize only after an explicit switch")
    func externalCombinedModes() {
        let queue = QueueService()
        queue.setRepeat(.one)
        queue.toggleShuffle()
        #expect(TrayPlaybackMode(repeatMode: queue.repeatMode, shuffle: queue.shuffle) == .repeatOne)
        TrayPlaybackMode.repeatAll.apply(to: queue)
        #expect(!queue.shuffle)
        #expect(queue.repeatMode == .all)
        queue.toggleShuffle()
        #expect(TrayPlaybackMode(repeatMode: queue.repeatMode, shuffle: queue.shuffle) == .shuffle)
        TrayPlaybackMode.inOrder.apply(to: queue)
        #expect(!queue.shuffle)
        #expect(queue.repeatMode == .off)
    }

    @Test("The tray uses the shared persisted queue state, including shuffle order restoration")
    func persistence() throws {
        let container = try makeModelContainer(inMemory: true)
        let queue = QueueService()
        queue.modelContext = ModelContext(container)
        let collection = [track("a"), track("b"), track("c")]
        queue.play(collection[1], context: collection, from: .playlist)
        queue.playNext(track("manual"))
        let originalIDs = queue.items.map(\.id)
        for mode in [TrayPlaybackMode.repeatOne, .repeatAll, .shuffle, .inOrder] {
            mode.apply(to: queue)
            let restored = QueueService()
            restored.modelContext = ModelContext(container)
            restored.restore()
            #expect(TrayPlaybackMode(repeatMode: restored.repeatMode, shuffle: restored.shuffle) == mode)
            #expect(restored.current()?.id == queue.current()?.id)
            #expect(restored.upNext == queue.upNext)
            if restored.shuffle { TrayPlaybackMode.inOrder.apply(to: restored) }
            #expect(restored.items.map(\.id) == originalIDs)
        }
    }
}
