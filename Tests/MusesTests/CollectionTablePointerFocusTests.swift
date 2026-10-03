import AppKit
import Testing
@testable import Muses

@MainActor
@Suite("Collection table pointer focus", .serialized)
struct CollectionTablePointerFocusTests {
    @Test("Owned row transfers focus without changing native selection")
    func ownedRowFocus() {
        let fixture = Fixture()
        let bridge = CollectionTablePointerFocus()
        defer { bridge.detach(); fixture.window.close() }
        bridge.attach(fixture.table)
        fixture.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        bridge.focusRow(at: fixture.rowPoint, in: fixture.window)
        #expect(fixture.window.firstResponder === fixture.table)
        #expect(fixture.table.selectedRowIndexes == IndexSet(integer: 1))
    }

    @Test("Overlapping controls and another window cannot steal focus")
    func rejectsOtherControls() {
        let fixture = Fixture()
        let other = Fixture()
        let bridge = CollectionTablePointerFocus()
        defer { bridge.detach(); fixture.window.close(); other.window.close() }
        bridge.attach(fixture.table)
        fixture.window.makeFirstResponder(fixture.field)
        let original = fixture.window.firstResponder
        bridge.focusRow(at: other.rowPoint, in: other.window)
        #expect(fixture.window.firstResponder === original)
        let cover = NSButton(frame: NSRect(origin: NSPoint(x: fixture.rowPoint.x - 5, y: fixture.rowPoint.y - 5), size: NSSize(width: 40, height: 20)))
        fixture.window.contentView!.addSubview(cover)
        bridge.focusRow(at: fixture.rowPoint, in: fixture.window)
        #expect(fixture.window.firstResponder === original)
    }

    @Test("Blank space, hidden or disabled tables and inactive windows retain focus")
    func rejectsInactiveTargets() {
        let fixture = Fixture()
        let bridge = CollectionTablePointerFocus()
        defer { bridge.detach(); fixture.window.close() }
        bridge.attach(fixture.table)
        fixture.window.makeFirstResponder(fixture.field)
        let original = fixture.window.firstResponder
        bridge.focusRow(at: fixture.table.convert(NSPoint(x: 10, y: 180), to: nil), in: fixture.window)
        #expect(fixture.window.firstResponder === original)
        fixture.table.isHidden = true
        bridge.focusRow(at: fixture.rowPoint, in: fixture.window)
        #expect(fixture.window.firstResponder === original)
        fixture.table.isHidden = false
        fixture.table.isEnabled = false
        bridge.focusRow(at: fixture.rowPoint, in: fixture.window)
        #expect(fixture.window.firstResponder === original)
        fixture.table.isEnabled = true
        fixture.window.keyForTest = false
        bridge.focusRow(at: fixture.rowPoint, in: fixture.window)
        #expect(fixture.window.firstResponder === original)
    }

    @Test("Reattachment and detachment release the old table boundary")
    func lifecycle() {
        let old = Fixture()
        let next = Fixture()
        let bridge = CollectionTablePointerFocus()
        defer { bridge.detach(); old.window.close(); next.window.close() }
        bridge.attach(old.table)
        bridge.attach(next.table)
        bridge.focusRow(at: old.rowPoint, in: old.window)
        #expect(old.window.firstResponder !== old.table)
        bridge.focusRow(at: next.rowPoint, in: next.window)
        #expect(next.window.firstResponder === next.table)
        next.window.makeFirstResponder(next.field)
        let original = next.window.firstResponder
        bridge.detach()
        bridge.focusRow(at: next.rowPoint, in: next.window)
        #expect(next.window.firstResponder === original)
    }

    private final class TestWindow: NSWindow {
        var keyForTest = true
        override var isKeyWindow: Bool { keyForTest }
    }

    private final class Rows: NSObject, NSTableViewDataSource {
        func numberOfRows(in tableView: NSTableView) -> Int { 3 }
    }

    @MainActor
    private final class Fixture {
        let window = TestWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        let field = NSTextField(frame: NSRect(x: 0, y: 220, width: 200, height: 24))
        let rows = Rows()
        var rowPoint: NSPoint { table.convert(NSPoint(x: 10, y: 10), to: nil) }

        init() {
            window.isReleasedWhenClosed = false
            table.addTableColumn(NSTableColumn(identifier: .init("title")))
            table.dataSource = rows
            window.contentView!.addSubview(table)
            window.contentView!.addSubview(field)
            table.reloadData()
        }
    }
}
