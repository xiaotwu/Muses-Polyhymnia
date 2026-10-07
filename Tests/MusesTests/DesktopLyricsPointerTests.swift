import AppKit
import SwiftUI
import Testing
@testable import Muses

@Suite("Desktop lyrics native pointer routing", .serialized)
@MainActor
struct DesktopLyricsPointerTests {
    private final class DragWindow: NSPanel {
        var dragEvents: [NSEvent] = []
        override func performDrag(with event: NSEvent) { dragEvents.append(event) }
    }

    @Test func textAndBackgroundBothStartOneNativeWindowDrag() throws {
        _ = NSApplication.shared
        let window = DragWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 120),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        let host = DesktopLyricsHostingView(rootView: Text("No lyrics")
            .frame(maxWidth: .infinity, maxHeight: .infinity))
        host.sizingOptions = []
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        defer { window.close() }
        let originalKeyWindow = NSApp.keyWindow
        for point in [NSPoint(x: 350, y: 60), NSPoint(x: 20, y: 20)] {
            let target = try #require(host.hitTest(point))
            let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                modifierFlags: [], timestamp: 1, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            #expect(target.acceptsFirstMouse(for: event))
            target.mouseDown(with: event)
        }
        #expect(window.dragEvents.count == 2)
        #expect(window.dragEvents.map(\.locationInWindow) == [NSPoint(x: 350, y: 60), NSPoint(x: 20, y: 20)])
        #expect(NSApp.keyWindow === originalKeyWindow)
        #expect(host.hitTest(NSPoint(x: -1, y: -1)) == nil)
    }
}
