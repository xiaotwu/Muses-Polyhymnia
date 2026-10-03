import AppKit
import SwiftUI

/// Measure the owned native table's columns without asking its subtree for a fitting size.
/// The outer horizontal scroll view uses this extent while Table retains vertical scrolling.
struct CollectionTableWidthObserver: NSViewRepresentable {
    let onWidth: (CGFloat) -> Void

    @MainActor
    final class Coordinator {
        var onWidth: (CGFloat) -> Void
        weak var table: NSTableView?
        private let pointerFocus = CollectionTablePointerFocus()
        private var observers: [NSObjectProtocol] = []
        private var previousPostsFrameChanges = false
        private var lastWidth: CGFloat = -1
        private var generation = 0
        private var measurementRevision = 0

        init(onWidth: @escaping (CGFloat) -> Void) { self.onWidth = onWidth }

        func attach(_ candidate: NSTableView) {
            guard table !== candidate else { measure(); return }
            detach()
            table = candidate
            pointerFocus.attach(candidate)
            previousPostsFrameChanges = candidate.postsFrameChangedNotifications
            candidate.postsFrameChangedNotifications = true
            observers = [NSTableView.columnDidResizeNotification,
                         NSTableView.columnDidMoveNotification,
                         NSView.frameDidChangeNotification].map { name in
                NotificationCenter.default.addObserver(forName: name, object: candidate, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.measure() }
                }
            }
            measure()
        }

        func measure() {
            guard let table else { return }
            let visible = table.tableColumns.enumerated().filter { !$0.element.isHidden }
            guard !visible.isEmpty else { return }
            let columnWidths = visible.reduce(CGFloat.zero) { $0 + $1.element.width }
            let gaps = table.intercellSpacing.width * CGFloat(max(0, visible.count - 1))
            let headerRects = visible.compactMap { table.headerView?.headerRect(ofColumn: $0.offset) }
            let leadingInset = max(0, headerRects.map(\.minX).min() ?? 0)
            let headerExtent = (headerRects.map(\.maxX).max() ?? 0) + leadingInset
            let width = max(columnWidths + gaps, headerExtent).rounded(.up)
            guard width.isFinite, width > 0, abs(width - lastWidth) > 0.5 else { return }
            lastWidth = width
            measurementRevision += 1
            let expectedRevision = measurementRevision
            let expectedGeneration = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == expectedGeneration, self.table != nil,
                      self.measurementRevision == expectedRevision else { return }
                self.onWidth(width)
            }
        }

        func detach() {
            pointerFocus.detach()
            generation += 1
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            table?.postsFrameChangedNotifications = previousPostsFrameChanges
            table = nil
            lastWidth = -1
        }
    }

    @MainActor
    final class ProbeView: NSView {
        weak var coordinator: Coordinator?
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
                // Start at the nearest owned container; never inspect another window.
                for _ in 0..<12 {
                    guard let container = ancestor else { return }
                    if let table = self.findTable(in: container) {
                        self.coordinator?.attach(table)
                        return
                    }
                    ancestor = container.superview
                }
            }
            resolution = work
            DispatchQueue.main.async(execute: work)
        }

        func cancelResolution() { resolution?.cancel(); resolution = nil }

        private func findTable(in view: NSView) -> NSTableView? {
            if let table = view as? NSTableView { return table }
            for child in view.subviews where child !== self {
                if let table = findTable(in: child) { return table }
            }
            return nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onWidth: onWidth) }

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: ProbeView, context: Context) {
        context.coordinator.onWidth = onWidth
        view.resolve()
    }

    static func dismantleNSView(_ view: ProbeView, coordinator: Coordinator) {
        view.cancelResolution()
        view.coordinator = nil
        coordinator.detach()
    }
}
