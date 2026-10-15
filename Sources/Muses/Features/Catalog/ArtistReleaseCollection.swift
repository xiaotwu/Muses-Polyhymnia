import AppKit
import SwiftUI

/// SwiftUI owns the release snapshot and actions; AppKit materializes reusable cards.
@MainActor
struct ArtistReleaseCollection<Card: View>: NSViewRepresentable {
    let releases: [OnlineReleaseItem]
    let content: @MainActor (OnlineReleaseItem) -> Card

    @Environment(\.self) private var environment

    static var cardHeight: CGFloat { ArtistReleaseCollectionMetrics.itemSize.height }

    init(
        releases: [OnlineReleaseItem],
        @ViewBuilder content: @escaping @MainActor (OnlineReleaseItem) -> Card
    ) {
        self.releases = releases
        self.content = content
    }

    func makeCoordinator() -> ArtistReleaseCollectionCoordinator {
        ArtistReleaseCollectionCoordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = ArtistReleaseCollectionMetrics.itemSize
        layout.minimumLineSpacing = ArtistReleaseCollectionMetrics.spacing
        layout.minimumInteritemSpacing = ArtistReleaseCollectionMetrics.spacing
        layout.sectionInset = NSEdgeInsetsZero

        let collectionView = NSCollectionView(frame: NSRect(
            origin: .zero,
            size: NSSize(width: 1, height: Self.cardHeight)
        ))
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = false
        collectionView.register(
            ArtistReleaseCollectionItem.self,
            forItemWithIdentifier: ArtistReleaseCollectionMetrics.reuseIdentifier
        )
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        // One item fills the cross axis, so the horizontal flow has one row.
        collectionView.autoresizingMask = [.height]

        let scrollView = ArtistReleaseFocusScrollView(frame: collectionView.frame)
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = false
        scrollView.documentView = collectionView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(
            releases: releases,
            environment: environment,
            content: { AnyView(content($0)) },
            scrollView: scrollView
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSScrollView,
        context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? nsView.frame.width, height: Self.cardHeight)
    }

    static func dismantleNSView(
        _ scrollView: NSScrollView,
        coordinator: ArtistReleaseCollectionCoordinator
    ) {
        (scrollView as? ArtistReleaseFocusScrollView)?.stopObservingFocus()
        if let collectionView = scrollView.documentView as? NSCollectionView {
            collectionView.delegate = nil
            collectionView.dataSource = nil
        }
        coordinator.clear()
        scrollView.documentView = nil
    }
}

@MainActor
private enum ArtistReleaseCollectionMetrics {
    static let itemSize = NSSize(width: 140, height: 240)
    static let spacing: CGFloat = 16
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("ArtistReleaseCard")
}

/// Embedded SwiftUI focus can move without asking AppKit to reveal the whole card.
@MainActor
final class ArtistReleaseFocusScrollView: NSScrollView {
    private weak var observedWindow: NSWindow?
    private var focusObservation: NSKeyValueObservation?
    private var focusBindingID: UUID?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard observedWindow !== window || focusObservation == nil else { return }
        stopObservingFocus()
        guard let newWindow = window else { return }

        let bindingID = UUID()
        focusBindingID = bindingID
        observedWindow = newWindow
        focusObservation = newWindow.observe(\.firstResponder, options: [.initial, .new]) {
            [weak self, weak newWindow] _, _ in
            // KVO is not actor-isolated; resolve focus after AppKit commits it.
            Task { @MainActor [weak self, weak newWindow] in
                guard let self, let newWindow,
                      self.focusBindingID == bindingID,
                      self.observedWindow === newWindow,
                      self.window === newWindow else { return }
                self.revealOwnedFirstResponder(in: newWindow)
            }
        }
    }

    func stopObservingFocus() {
        // Pending work from an old window binding must not move a reused shelf.
        focusBindingID = nil
        focusObservation?.invalidate()
        focusObservation = nil
        observedWindow = nil
    }

    private func revealOwnedFirstResponder(in window: NSWindow) {
        guard let documentView,
              let responder = window.firstResponder as? NSView,
              responder.isDescendant(of: documentView) else { return }

        var cursor: NSView? = responder
        while let view = cursor, view !== documentView {
            if let card = view as? ArtistReleaseCardContainer {
                // Re-resolve current ownership and geometry after reuse/layout.
                guard card.representedStableID != nil,
                      card.window === window,
                      !card.isHiddenOrHasHiddenAncestor else { return }
                let cardRect = documentView.convert(card.bounds, from: card)
                guard !cardRect.isEmpty,
                      !documentView.visibleRect.contains(cardRect) else { return }
                documentView.scrollToVisible(cardRect)
                return
            }
            cursor = view.superview
        }
    }
}

@MainActor
final class ArtistReleaseCardContainer: NSView {
    var representedStableID: String?
}

/// This snapshot is data-source glue, replaced from SwiftUI on every update.
@MainActor
final class ArtistReleaseCollectionCoordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private var releases: [OnlineReleaseItem] = []
    private var orderedIDs: [String] = []
    private var environment: EnvironmentValues?
    private var content: (@MainActor (OnlineReleaseItem) -> AnyView)?
    private var revision: UInt = 0
    private var hasSnapshot = false
    private let hostedItems = NSHashTable<ArtistReleaseCollectionItem>.weakObjects()

    func update(
        releases: [OnlineReleaseItem],
        environment: EnvironmentValues,
        content: @escaping @MainActor (OnlineReleaseItem) -> AnyView,
        scrollView: NSScrollView
    ) {
        guard let collectionView = scrollView.documentView as? NSCollectionView else { return }
        let newIDs = releases.map(\.stableID)
        let needsReload = !hasSnapshot || newIDs != orderedIDs
        let savedOrigin = scrollView.contentView.bounds.origin

        self.releases = releases
        orderedIDs = newIDs
        self.environment = environment
        self.content = content
        revision &+= 1
        hasSnapshot = true

        if needsReload {
            collectionView.reloadData()
            collectionView.layoutSubtreeIfNeeded()
            let clipView = scrollView.contentView
            var bounds = clipView.bounds
            bounds.origin = savedOrigin
            clipView.scroll(to: clipView.constrainBoundsRect(bounds).origin)
            scrollView.reflectScrolledClipView(clipView)
        }

        // Keep same-ID hosting trees alive across metadata and environment updates.
        for case let item as ArtistReleaseCollectionItem in collectionView.visibleItems() {
            guard let indexPath = collectionView.indexPath(for: item) else { continue }
            configure(item, at: indexPath)
        }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        section == 0 ? releases.count : 0
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: ArtistReleaseCollectionMetrics.reuseIdentifier,
            for: indexPath
        )
        if let item = item as? ArtistReleaseCollectionItem {
            hostedItems.add(item)
            configure(item, at: indexPath)
        }
        return item
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        willDisplay item: NSCollectionViewItem,
        forRepresentedObjectAt indexPath: IndexPath
    ) {
        guard let item = item as? ArtistReleaseCollectionItem else { return }
        configure(item, at: indexPath)
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didEndDisplaying item: NSCollectionViewItem,
        forRepresentedObjectAt indexPath: IndexPath
    ) {
        (item as? ArtistReleaseCollectionItem)?.clear()
    }

    func clear() {
        for item in hostedItems.allObjects { item.clear() }
        hostedItems.removeAllObjects()
        releases = []
        orderedIDs = []
        environment = nil
        content = nil
        hasSnapshot = false
    }

    private func configure(_ item: ArtistReleaseCollectionItem, at indexPath: IndexPath) {
        guard indexPath.section == 0,
              releases.indices.contains(indexPath.item),
              let environment,
              let content else {
            item.clear()
            return
        }
        let release = releases[indexPath.item]
        item.setContent(stableID: release.stableID, revision: revision) {
            AnyView(content(release)
                .id(release.stableID)
                .environment(\.self, environment)
                .frame(
                    width: ArtistReleaseCollectionMetrics.itemSize.width,
                    height: ArtistReleaseCollectionMetrics.itemSize.height,
                    alignment: .top
                ))
        }
    }
}

@MainActor
private final class ArtistReleaseCollectionItem: NSCollectionViewItem {
    private var hostingView: NSHostingView<AnyView>?
    private var stableID: String?
    private var revision: UInt?

    override func loadView() {
        let container = ArtistReleaseCardContainer(frame: NSRect(origin: .zero, size: ArtistReleaseCollectionMetrics.itemSize))
        let host = NSHostingView(rootView: AnyView(EmptyView()))
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        hostingView = host
        view = container
    }

    func setContent(stableID: String, revision: UInt, content: () -> AnyView) {
        guard self.stableID != stableID || self.revision != revision else { return }
        _ = view
        (view as? ArtistReleaseCardContainer)?.representedStableID = stableID
        hostingView?.rootView = content()
        self.stableID = stableID
        self.revision = revision
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        clear()
    }

    func clear() {
        if isViewLoaded { (view as? ArtistReleaseCardContainer)?.representedStableID = nil }
        if stableID != nil { hostingView?.rootView = AnyView(EmptyView()) }
        stableID = nil
        revision = nil
    }
}
