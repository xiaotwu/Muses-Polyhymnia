import AppKit
import Testing
@testable import Muses

@MainActor
@Suite("Native collection table width", .serialized)
struct CollectionTableWidthObserverTests {
    @Test("Owned artwork rows use uniform sizing and restore their native policy")
    func uniformRowsRestorePolicy() {
        let table = makeTable(titleWidth: 220, detailWidth: 100)
        table.usesAutomaticRowHeights = true
        table.rowHeight = 24
        let observer = CollectionTableWidthObserver.Coordinator { _ in }
        observer.attach(table)
        #expect(!table.usesAutomaticRowHeights)
        #expect(table.rowHeight == CollectionTableWidthObserver.uniformRowHeight)

        // SwiftUI hosting updates can reset native row settings on the same table.
        table.usesAutomaticRowHeights = true
        table.rowHeight = 24
        observer.attach(table)
        #expect(!table.usesAutomaticRowHeights)
        #expect(table.rowHeight == CollectionTableWidthObserver.uniformRowHeight)
        observer.detach()
        #expect(table.usesAutomaticRowHeights)
        #expect(table.rowHeight == 24)
    }

    @Test("Rebinding restores the old table and independently manages the new table")
    func uniformRowsRebindPolicy() {
        let oldTable = makeTable(titleWidth: 220, detailWidth: 100)
        oldTable.usesAutomaticRowHeights = true
        oldTable.rowHeight = 31
        let newTable = makeTable(titleWidth: 220, detailWidth: 100)
        newTable.usesAutomaticRowHeights = false
        newTable.rowHeight = 35
        let observer = CollectionTableWidthObserver.Coordinator { _ in }
        observer.attach(oldTable)
        observer.attach(newTable)
        #expect(oldTable.usesAutomaticRowHeights)
        #expect(oldTable.rowHeight == 31)
        #expect(!newTable.usesAutomaticRowHeights)
        #expect(newTable.rowHeight == CollectionTableWidthObserver.uniformRowHeight)
        observer.detach()
        #expect(!newTable.usesAutomaticRowHeights)
        #expect(newTable.rowHeight == 35)
    }

    @Test("Native column resize grows and shrinks the reported scroll extent")
    func resizeTracksRealColumns() async throws {
        let table = makeTable(titleWidth: 220, detailWidth: 100)
        var values: [CGFloat] = []
        let observer = CollectionTableWidthObserver.Coordinator { values.append($0) }
        defer { observer.detach() }
        observer.attach(table)
        await flushMainQueue()
        let initial = try #require(values.last)

        table.tableColumns[0].width = 700
        await flushMainQueue()
        let expanded = try #require(values.last)
        #expect(expanded > initial + 400)
        #expect(expanded >= table.headerView!.headerRect(ofColumn: 1).maxX)

        table.tableColumns[0].width = 220
        await flushMainQueue()
        #expect(values.last == initial)
        #expect(values.count == 3)
    }

    @Test("Hidden columns leave the extent while showing them restores it")
    func visibilityTracksRealColumns() async throws {
        let table = makeTable(titleWidth: 220, detailWidth: 400)
        var values: [CGFloat] = []
        let observer = CollectionTableWidthObserver.Coordinator { values.append($0) }
        defer { observer.detach() }
        observer.attach(table)
        await flushMainQueue()
        let initial = try #require(values.last)

        table.tableColumns[1].isHidden = true
        table.layoutSubtreeIfNeeded()
        observer.measure() // The SwiftUI customization update also re-resolves the probe.
        await flushMainQueue()
        let hiddenExtent = try #require(values.last)
        #expect(hiddenExtent < initial)

        table.tableColumns[1].isHidden = false
        table.layoutSubtreeIfNeeded()
        observer.measure()
        await flushMainQueue()
        #expect(values.last == initial)
    }

    @Test("Detaching cancels pending delivery and restores the native notification flag")
    func detachInvalidatesOldTableDelivery() async throws {
        let oldTable = makeTable(titleWidth: 700, detailWidth: 100)
        let newTable = makeTable(titleWidth: 220, detailWidth: 100)
        oldTable.postsFrameChangedNotifications = false
        var values: [CGFloat] = []
        let observer = CollectionTableWidthObserver.Coordinator { values.append($0) }
        observer.attach(oldTable)
        #expect(oldTable.postsFrameChangedNotifications)
        observer.detach()
        #expect(!oldTable.postsFrameChangedNotifications)
        observer.attach(newTable)
        await flushMainQueue()
        #expect(values.count == 1)
        let newExtent = try #require(values.last)
        #expect(newExtent < 700)

        observer.detach()
        let count = values.count
        oldTable.tableColumns[0].width = 900
        newTable.tableColumns[0].width = 900
        await flushMainQueue()
        #expect(values.count == count)
        #expect(observer.table == nil)
    }

    @Test("A rapid resize round trip delivers only its latest measurement")
    func coalescesResizeRoundTrip() async {
        let table = makeTable(titleWidth: 220, detailWidth: 100)
        var values: [CGFloat] = []
        let observer = CollectionTableWidthObserver.Coordinator { values.append($0) }
        defer { observer.detach() }
        observer.attach(table)
        table.tableColumns[0].width = 700
        table.tableColumns[0].width = 220
        await flushMainQueue()
        #expect(values.count == 1)
        #expect(values.first.map { $0 < 700 } == true)
    }

    private func makeTable(titleWidth: CGFloat, detailWidth: CGFloat) -> NSTableView {
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 1200, height: 300))
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.intercellSpacing = NSSize(width: 17, height: 1)
        table.headerView = NSTableHeaderView(frame: NSRect(x: 0, y: 0, width: 1200, height: 28))
        for (identifier, width) in [("title", titleWidth), ("detail", detailWidth)] {
            let column = NSTableColumn(identifier: .init(identifier))
            column.minWidth = 20
            column.maxWidth = 2000
            column.width = width
            table.addTableColumn(column)
        }
        return table
    }

    private func flushMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
