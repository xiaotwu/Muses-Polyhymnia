import AppKit
import SwiftUI
import Testing
@testable import Muses

@MainActor
@Suite("Artist release collection coordinator", .serialized)
struct ArtistReleaseCollectionCoordinatorTests {
    @Test("Same ordered IDs preserve the viewport without reloading")
    func sameIDsKeepNativeState() throws {
        let fixture = Fixture()
        defer { fixture.detach() }
        let initial = [
            OnlineReleaseItem(stableID: "playlist:one", title: "One", year: 2020),
            OnlineReleaseItem(stableID: "playlist:two", title: "Two", year: 2021)
        ]
        fixture.update(initial)
        #expect(fixture.collectionView.reloadCount == 1)
        fixture.scroll(toX: 425)
        let originalOrigin = fixture.scrollView.contentView.bounds.origin
        try #require(originalOrigin.x > 0)
        let clip = fixture.scrollView.contentView
        try #require(clip.documentRect.width == 2_000 && clip.bounds.width == 500)
        try #require(clip.constrainBoundsRect(clip.bounds).origin == originalOrigin)

        let updated = [
            OnlineReleaseItem(stableID: "playlist:one", title: "Updated One", artworkURL: "https://example.invalid/one.jpg", year: 2026),
            OnlineReleaseItem(stableID: "playlist:two", title: "Updated Two", year: 2025)
        ]
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        environment.locale = Locale(identifier: "zh-Hant")
        environment.layoutDirection = .rightToLeft
        fixture.update(updated, environment: environment)

        #expect(fixture.collectionView.reloadCount == 1)
        #expect(fixture.scrollView.contentView.bounds.origin == originalOrigin)
    }

    @Test("Structural reloads restore and constrain the viewport using a fixed document layout")
    func structuralChangesReloadAndConstrainTheViewport() throws {
        let fixture = Fixture()
        defer { fixture.detach() }
        let first = OnlineReleaseItem(stableID: "playlist:first", title: "First")
        let second = OnlineReleaseItem(stableID: "playlist:second", title: "Second")
        let third = OnlineReleaseItem(stableID: "playlist:third", title: "Third")
        fixture.update([first, second, third])
        fixture.scroll(toX: 900)
        let originalOrigin = fixture.scrollView.contentView.bounds.origin
        try #require(originalOrigin.x > 0)

        let clipBeforeReload = fixture.scrollView.contentView
        try #require(clipBeforeReload.documentRect.width == 2_000 && clipBeforeReload.bounds.width == 500)
        try #require(clipBeforeReload.constrainBoundsRect(clipBeforeReload.bounds).origin == originalOrigin)

        fixture.update([third, first, second])
        #expect(fixture.collectionView.reloadCount == 2)
        #expect(fixture.scrollView.contentView.bounds.origin == originalOrigin)

        // The zero-item fixture supplies document geometry, not card layout.
        // A real NSClipView constrains the coordinator's restored origin.
        fixture.collectionView.widthAfterReload = 760
        fixture.update([third, first])
        #expect(fixture.collectionView.reloadCount == 3)
        let clipView = fixture.scrollView.contentView
        try #require(clipView.documentRect.width == 760)
        try #require(clipView.bounds.width == 500)
        #expect(abs(clipView.bounds.origin.x - 260) < 0.01)

        fixture.collectionView.widthAfterReload = 200
        fixture.update([third])
        #expect(fixture.collectionView.reloadCount == 4)
        try #require(clipView.documentRect.width == clipView.bounds.width)
        #expect(fixture.collectionView.frame.width <= clipView.bounds.width)
        #expect(abs(clipView.bounds.origin.x) < 0.01)
    }

    @Test("Clear releases the content callback capture and invalidates the data-source snapshot")
    func clearReleasesSnapshotAndCallbacks() {
        let fixture = Fixture()
        defer { fixture.detach() }
        weak var retainedCapture: CallbackCapture?
        do {
            let capture = CallbackCapture()
            retainedCapture = capture
            let callback: @MainActor () -> Void = { capture.calls += 1 }
            fixture.coordinator.update(
                releases: [OnlineReleaseItem(stableID: "playlist:one", title: "One")],
                environment: EnvironmentValues(),
                content: { _ in
                    callback()
                    return AnyView(EmptyView())
                },
                scrollView: fixture.scrollView
            )
        }
        #expect(retainedCapture != nil)
        // With no requested items, storing the snapshot leaves content unevaluated.
        #expect(retainedCapture?.calls == 0)
        #expect(fixture.snapshotCount == 1)

        fixture.coordinator.clear()
        #expect(retainedCapture == nil)
        #expect(fixture.snapshotCount == 0)

        // Even an empty next snapshot is a fresh installation after clear().
        fixture.update([])
        #expect(fixture.collectionView.reloadCount == 2)
        #expect(fixture.snapshotCount == 0)
    }

    @MainActor
    private final class CallbackCapture {
        var calls = 0
    }

    @MainActor
    private final class FixedDocumentLayout: NSCollectionViewLayout {
        var documentSize = NSSize(width: 2_000, height: 240)

        override var collectionViewContentSize: NSSize { documentSize }

        override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
            []
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
            nil
        }
    }

    @MainActor
    private final class ZeroItemsDataSource: NSObject, NSCollectionViewDataSource {
        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            0
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            itemForRepresentedObjectAt indexPath: IndexPath
        ) -> NSCollectionViewItem {
            preconditionFailure("The zero-item geometry fixture must not request an item")
        }
    }

    @MainActor
    private final class RecordingCollectionView: NSCollectionView {
        let documentLayout = FixedDocumentLayout()
        var reloadCount = 0
        var widthAfterReload: CGFloat = 2_000

        override func reloadData() {
            reloadCount += 1
            documentLayout.documentSize = NSSize(width: widthAfterReload, height: 240)
            documentLayout.invalidateLayout()
            super.reloadData()
            // There are no visible items to trigger a detached layout resize.
            setFrameSize(documentLayout.documentSize)
        }
    }

    @MainActor
    private final class Fixture {
        let coordinator = ArtistReleaseCollectionCoordinator()
        private let geometryDataSource = ZeroItemsDataSource()
        let collectionView = RecordingCollectionView(frame: NSRect(x: 0, y: 0, width: 2_000, height: 240))
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 240))

        var snapshotCount: Int {
            coordinator.collectionView(collectionView, numberOfItemsInSection: 0)
        }

        init() {
            scrollView.borderType = .noBorder
            scrollView.hasHorizontalScroller = true
            scrollView.hasVerticalScroller = false
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = false
            // Keep the modern data-source/layout path active without creating cards.
            // This source describes only fixture geometry, not the coordinator's snapshot.
            collectionView.collectionViewLayout = collectionView.documentLayout
            collectionView.dataSource = geometryDataSource
            scrollView.contentView.automaticallyAdjustsContentInsets = false
            scrollView.contentView.contentInsets = NSEdgeInsetsZero
            scrollView.documentView = collectionView
            collectionView.reloadCount = 0
        }

        func update(_ releases: [OnlineReleaseItem], environment: EnvironmentValues = EnvironmentValues()) {
            coordinator.update(
                releases: releases,
                environment: environment,
                content: { _ in AnyView(EmptyView()) },
                scrollView: scrollView
            )
        }

        func scroll(toX x: CGFloat) {
            scrollView.contentView.scroll(to: NSPoint(x: x, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        func detach() {
            collectionView.dataSource = nil
            coordinator.clear()
            scrollView.documentView = nil
        }
    }
}
