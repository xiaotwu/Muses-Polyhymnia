import AppKit
import Testing
@testable import Muses

@Suite("Queue keyboard selection reveal")
@MainActor
struct QueueKeyboardSelectionRevealTests {
    private final class Table: NSTableView {
        var selection = 659
        var count = 662
        var selectedRect = NSRect(x: 0, y: 30_920, width: 360, height: 52)
        var viewport = NSRect(x: 0, y: 30_294, width: 360, height: 710)
        var revealed: [Int] = []
        override var selectedRow: Int { selection }
        override var numberOfRows: Int { count }
        override var visibleRect: NSRect { viewport }
        override func rect(ofRow row: Int) -> NSRect { selectedRect }
        override func scrollRowToVisible(_ row: Int) { revealed.append(row) }
    }

    @Test func documentGrowthRevealsTheSameSelectedOccurrence() {
        let table = Table()
        let originalAutomaticHeights = table.usesAutomaticRowHeights
        let coordinator = QueueKeyboardSelectionReveal.Coordinator()
        coordinator.attach(table)
        defer { coordinator.detach() }
        coordinator.receive(revision: 1)
        coordinator.revealIfNeeded()
        #expect(table.revealed.isEmpty)
        // Reproduce measured estimated-height replacement, without changing selection.
        table.selectedRect.origin.y = 31_638
        coordinator.revealIfNeeded()
        #expect(table.revealed == [659])
        #expect(table.selection == 659)
        #expect(table.usesAutomaticRowHeights == originalAutomaticHeights)
    }

    @Test func pointerOwnershipAndUnchangedRevisionDoNotPullScrollBack() {
        let table = Table()
        let coordinator = QueueKeyboardSelectionReveal.Coordinator()
        coordinator.attach(table)
        defer { coordinator.detach() }
        coordinator.receive(revision: 1)
        coordinator.endKeyboardOwnership()
        table.viewport.origin.y = 0
        coordinator.receive(revision: 1)
        coordinator.revealIfNeeded()
        #expect(table.revealed.isEmpty)
        coordinator.receive(revision: 2)
        coordinator.revealIfNeeded()
        #expect(table.revealed == [659])
    }

    @Test func invalidSelectionAndDetachedTableNeverScroll() {
        let table = Table()
        table.postsFrameChangedNotifications = false
        let coordinator = QueueKeyboardSelectionReveal.Coordinator()
        coordinator.attach(table)
        coordinator.receive(revision: 1)
        table.selection = -1
        coordinator.revealIfNeeded()
        table.selection = table.count
        coordinator.revealIfNeeded()
        #expect(table.revealed.isEmpty)
        coordinator.detach()
        table.selection = 659
        coordinator.revealIfNeeded()
        #expect(table.revealed.isEmpty)
        #expect(!table.postsFrameChangedNotifications)
    }

    @Test func preservesNativeAutomaticHeightConfiguration() {
        let table = NSTableView()
        table.usesAutomaticRowHeights = true
        let coordinator = QueueKeyboardSelectionReveal.Coordinator()
        coordinator.attach(table)
        #expect(table.usesAutomaticRowHeights)
        coordinator.detach()
        #expect(table.usesAutomaticRowHeights)
    }

    @Test func nativeGeometryNotificationSchedulesAnotherReveal() async {
        let table = Table()
        let coordinator = QueueKeyboardSelectionReveal.Coordinator()
        coordinator.attach(table)
        defer { coordinator.detach() }
        coordinator.receive(revision: 1)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(table.revealed.isEmpty)
        table.selectedRect.origin.y = 31_638
        table.frame.size.height = 31_741
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(table.revealed == [659])
    }

    @Test func oversizedRowDoesNotOscillateWhenItsLeadingEdgeIsVisible() {
        let table = Table()
        table.selectedRect = NSRect(x: 0, y: 100, width: 360, height: 200)
        table.viewport = NSRect(x: 0, y: 100, width: 360, height: 80)
        let coordinator = QueueKeyboardSelectionReveal.Coordinator()
        coordinator.attach(table)
        defer { coordinator.detach() }
        coordinator.receive(revision: 1)
        coordinator.revealIfNeeded()
        #expect(table.revealed.isEmpty)
    }
}
