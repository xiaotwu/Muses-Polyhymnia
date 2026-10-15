import AppKit
import Testing
@testable import Muses

@MainActor
@Suite("Artist release focus observation", .serialized)
struct ArtistReleaseFocusScrollViewTests {
    @Test("Current owned responder reveals its represented card without transferring focus")
    func revealsOwnedResponder() async throws {
        _ = NSApplication.shared
        let fixture = Fixture()
        defer { fixture.close() }
        try await deferredWorkQuietPeriod()
        try fixture.requireScrollableGeometry()
        try #require(!fixture.cardIsFullyVisible)

        let oldOrigin = fixture.clipView.bounds.origin
        try fixture.focus(fixture.ownedButton)
        // Reject a false positive if this platform's ordinary button already
        // scrolls synchronously, before the observer's deferred work can run.
        try #require(fixture.clipView.bounds.origin == oldOrigin)

        let revealed = try await eventually { fixture.cardIsFullyVisible }
        #expect(revealed)
        #expect(fixture.clipView.bounds.origin.x > oldOrigin.x)
        #expect(fixture.window.firstResponder === fixture.ownedButton)
    }

    @Test("A current responder outside this scroll view does not move its viewport")
    func ignoresForeignResponder() async throws {
        _ = NSApplication.shared
        let fixture = Fixture()
        defer { fixture.close() }
        try await deferredWorkQuietPeriod()
        try fixture.requireScrollableGeometry()
        fixture.scroll(toX: 600)
        let oldOrigin = fixture.clipView.bounds.origin
        try #require(!fixture.cardIsFullyVisible)
        try #require(fixture.window.firstResponder === fixture.foreignButtonA)

        // This is a real first-responder change, rather than reselecting the
        // same foreign control and accidentally producing no KVO notification.
        try fixture.focus(fixture.foreignButtonB)
        try await deferredWorkQuietPeriod()

        #expect(fixture.window.firstResponder === fixture.foreignButtonB)
        #expect(fixture.clipView.bounds.origin == oldOrigin)
        #expect(!fixture.cardIsFullyVisible)
    }

    @Test("Stopping observation invalidates an already queued focus reveal")
    func stopInvalidatesPendingReveal() async throws {
        _ = NSApplication.shared
        let fixture = Fixture()
        defer { fixture.close() }
        try await deferredWorkQuietPeriod()
        try fixture.requireScrollableGeometry()

        // Positive control: this fixture really observes and reveals owned focus.
        let initialOrigin = fixture.clipView.bounds.origin
        try fixture.focus(fixture.ownedButton)
        try #require(fixture.clipView.bounds.origin == initialOrigin)
        let initiallyRevealed = try await eventually { fixture.cardIsFullyVisible }
        try #require(initiallyRevealed)

        try fixture.focus(fixture.foreignButtonA)
        try await deferredWorkQuietPeriod()
        fixture.scroll(toX: 0)
        let originBeforePendingReveal = fixture.clipView.bounds.origin
        try #require(!fixture.cardIsFullyVisible)

        // No suspension between makeFirstResponder and stop: the synchronous
        // KVO callback has queued its MainActor work, but it cannot run on this
        // actor until this test yields. stop must invalidate that old binding.
        try fixture.focus(fixture.ownedButton)
        try #require(fixture.clipView.bounds.origin == originBeforePendingReveal)
        fixture.scrollView.stopObservingFocus()
        try await deferredWorkQuietPeriod()

        #expect(fixture.window.firstResponder === fixture.ownedButton)
        #expect(fixture.clipView.bounds.origin == originBeforePendingReveal)
        #expect(!fixture.cardIsFullyVisible)
    }

    private func eventually(_ predicate: @MainActor () -> Bool) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while clock.now < deadline {
            if predicate() { return true }
            try await Task.sleep(for: .milliseconds(10))
        }
        return predicate()
    }

    private func deferredWorkQuietPeriod() async throws {
        // Yield the main actor for the observation actor hop. This is an asynchronous wait, not a blocked run loop.
        try await Task.sleep(for: .milliseconds(100))
    }

    @MainActor
    private final class Fixture {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 360),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let scrollView = ArtistReleaseFocusScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 240))
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 2_000, height: 240))
        let card = ArtistReleaseCardContainer(frame: NSRect(x: 1_400, y: 0, width: 140, height: 240))
        let ownedButton = NSButton(frame: NSRect(x: 10, y: 100, width: 110, height: 28))
        let foreignButtonA = NSButton(frame: NSRect(x: 540, y: 270, width: 110, height: 28))
        let foreignButtonB = NSButton(frame: NSRect(x: 660, y: 270, width: 110, height: 28))

        var clipView: NSClipView { scrollView.contentView }
        var cardIsFullyVisible: Bool {
            let cardRect = document.convert(card.bounds, from: card)
            return clipView.documentVisibleRect.contains(cardRect)
        }

        init() {
            window.isReleasedWhenClosed = false
            scrollView.borderType = .noBorder
            scrollView.hasHorizontalScroller = true
            scrollView.hasVerticalScroller = false
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = false
            clipView.automaticallyAdjustsContentInsets = false
            clipView.contentInsets = NSEdgeInsetsZero
            card.representedStableID = "playlist:focus-contract"
            ownedButton.title = "Owned"
            foreignButtonA.title = "Foreign A"
            foreignButtonB.title = "Foreign B"
            card.addSubview(ownedButton)
            document.addSubview(card)
            scrollView.documentView = document
            // Establish foreign focus before attachment triggers the initial KVO.
            window.contentView!.addSubview(foreignButtonA)
            window.contentView!.addSubview(foreignButtonB)
            window.makeFirstResponder(foreignButtonA)
            window.contentView!.addSubview(scrollView)
        }

        func requireScrollableGeometry() throws {
            try #require(scrollView.window === window)
            try #require(clipView.documentRect.width == 2_000)
            try #require(clipView.bounds.width == 500)
            try #require(card.representedStableID != nil)
            try #require(!window.isVisible)
        }

        func focus(_ button: NSButton) throws {
            try #require(window.makeFirstResponder(button))
            try #require(window.firstResponder === button)
        }

        func scroll(toX x: CGFloat) {
            var proposed = clipView.bounds
            proposed.origin.x = x
            clipView.scroll(to: clipView.constrainBoundsRect(proposed).origin)
            scrollView.reflectScrolledClipView(clipView)
        }

        func close() {
            scrollView.stopObservingFocus()
            window.makeFirstResponder(nil)
            scrollView.removeFromSuperview()
            window.close()
        }
    }
}
