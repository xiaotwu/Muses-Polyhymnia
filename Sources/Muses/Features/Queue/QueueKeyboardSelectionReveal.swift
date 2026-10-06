import AppKit
import SwiftUI

/// Native automatic row heights can change after a far keyboard jump, including
/// during accessibility reads. Keep that selection visible as geometry settles;
/// pointer scrolling immediately takes ownership back from keyboard navigation.
struct QueueKeyboardSelectionReveal: NSViewRepresentable {
    let revision: Int

    @MainActor
    final class Coordinator {
        weak var table: NSTableView?
        private var observers: [NSObjectProtocol] = []
        private var inputMonitor: Any?
        private var previousPostsFrameChanges = false
        private var deliveredRevision = 0
        private var keyboardOwnsReveal = false
        private var pendingReveal: DispatchWorkItem?

        func attach(_ candidate: NSTableView) {
            guard table !== candidate else { return }
            detach()
            table = candidate
            previousPostsFrameChanges = candidate.postsFrameChangedNotifications
            candidate.postsFrameChangedNotifications = true
            for name in [NSView.frameDidChangeNotification, NSTableView.selectionDidChangeNotification] {
                observers.append(NotificationCenter.default.addObserver(
                    forName: name, object: candidate, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleReveal() }
                })
            }
            inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
                MainActor.assumeIsolated {
                    if let self, let window = self.table?.window, event.window === window {
                        if event.type != .keyDown || ![115, 119, 125, 126].contains(event.keyCode) {
                            self.endKeyboardOwnership()
                        }
                    }
                }
                return event
            }
        }

        func receive(revision: Int) {
            guard revision != deliveredRevision else { return }
            deliveredRevision = revision
            keyboardOwnsReveal = revision > 0
            scheduleReveal()
        }

        private func scheduleReveal() {
            guard keyboardOwnsReveal, table != nil, pendingReveal == nil else { return }
            // Coalesce native geometry/selection notifications into one layout turn.
            // Further work requires another real notification, never a timed retry.
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingReveal = nil
                self.revealIfNeeded()
            }
            pendingReveal = work
            DispatchQueue.main.async(execute: work)
        }

        func revealIfNeeded() {
            guard keyboardOwnsReveal, let table, table.selectedRow >= 0,
                  table.selectedRow < table.numberOfRows else { return }
            let row = table.rect(ofRow: table.selectedRow)
            let viewport = table.visibleRect
            guard row.height > 0, viewport.height > 0 else { return }
            // Rows taller than a compact viewport need only keep their leading edge
            // visible, rather than oscillating between incompatible top/bottom fits.
            let requiredBottom = row.minY + min(row.height, viewport.height)
            guard row.minY < viewport.minY - 0.5 || requiredBottom > viewport.maxY + 0.5 else { return }
            table.scrollRowToVisible(table.selectedRow)
        }

        func endKeyboardOwnership() {
            keyboardOwnsReveal = false
            pendingReveal?.cancel()
            pendingReveal = nil
        }

        func detach() {
            endKeyboardOwnership()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
            inputMonitor = nil
            table?.postsFrameChangedNotifications = previousPostsFrameChanges
            table = nil
        }
    }

    @MainActor
    final class Probe: NSView {
        weak var coordinator: Coordinator?
        var revision = 0
        private var resolution: DispatchWorkItem?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { cancelResolution(); coordinator?.detach() }
            else { resolve() }
        }
        override func layout() { super.layout(); resolve() }

        func resolve() {
            guard window != nil, resolution == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.resolution = nil
                guard self.window != nil else { return }
                var ancestor = self.superview
                for _ in 0..<12 {
                    guard let container = ancestor else { return }
                    if let table = self.findTable(in: container) {
                        self.coordinator?.attach(table)
                        self.coordinator?.receive(revision: self.revision)
                        return
                    }
                    ancestor = container.superview
                }
            }
            resolution = work
            DispatchQueue.main.async(execute: work)
        }
        private func findTable(in view: NSView) -> NSTableView? {
            if let table = view as? NSTableView { return table }
            for child in view.subviews where child !== self {
                if let table = findTable(in: child) { return table }
            }
            return nil
        }
        func cancelResolution() { resolution?.cancel(); resolution = nil }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.coordinator = context.coordinator
        return view
    }
    func updateNSView(_ view: Probe, context: Context) {
        view.revision = revision
        view.resolve()
    }
    static func dismantleNSView(_ view: Probe, coordinator: Coordinator) {
        view.cancelResolution()
        view.coordinator = nil
        coordinator.detach()
    }
}
