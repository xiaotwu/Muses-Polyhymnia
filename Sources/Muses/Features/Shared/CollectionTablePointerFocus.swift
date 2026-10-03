import AppKit

/// Retained SwiftUI table hosts do not always participate in the owning
/// window's pointer focus transfer. Restore that transfer only for owned rows;
/// NSTableView still handles selection, modifiers, menus and keyboard input.
@MainActor
final class CollectionTablePointerFocus {
    private weak var table: NSTableView?
    private var monitor: Any?

    func attach(_ table: NSTableView) {
        guard self.table !== table else { return }
        detach()
        self.table = table
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.focusRow(at: event.locationInWindow, in: event.window)
            return event
        }
    }

    func focusRow(at point: NSPoint, in window: NSWindow?) {
        guard let table, let window, table.window === window,
              window.isKeyWindow, table.isEnabled, !table.isHiddenOrHasHiddenAncestor,
              let content = window.contentView else { return }
        let localPoint = table.convert(point, from: nil)
        guard table.visibleRect.contains(localPoint), table.row(at: localPoint) >= 0 else { return }
        // Reject overlapping chrome and other controls even when their screen
        // position happens to coincide with a table row.
        let hitPoint = content.superview.map { $0.convert(point, from: nil) } ?? point
        guard let hit = content.hitTest(hitPoint), hit.isDescendant(of: table) else { return }
        if window.firstResponder !== table { window.makeFirstResponder(table) }
    }

    func detach() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        table = nil
    }
}
