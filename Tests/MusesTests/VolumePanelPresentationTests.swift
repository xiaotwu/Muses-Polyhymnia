import AppKit
import SwiftUI
import Testing
@testable import Muses

@Suite("Volume panel presentation", .serialized)
@MainActor
struct VolumePanelPresentationTests {
    @Test func firstPresentationReceivesKeyboardWithoutTouchingTheScale() {
        _ = NSApplication.shared
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        parent.alphaValue = 0
        let anchor = VolumePanelHost<EmptyView>.AnchorView(frame: NSRect(x: 10, y: 10, width: 90, height: 32))
        parent.contentView?.addSubview(anchor)
        let coordinator = VolumePanelHost<EmptyView>.Coordinator(
            width: 90, height: 32, anchorsToSpeaker: false, speakerGlobalFrame: .zero,
            dismiss: {}, keyAction: { _ in false })
        coordinator.anchor = anchor
        coordinator.panel.alphaValue = 0
        let other = VolumePanelHost<EmptyView>.CapsulePanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.alphaValue = 0
        defer {
            other.close()
            coordinator.stop()
            parent.close()
        }
        parent.orderFront(nil)
        #expect(!coordinator.panel.isVisible)
        coordinator.position()
        #expect(coordinator.panel.parent === parent)
        #expect(coordinator.panel.isVisible)
        #expect(coordinator.panel.isKeyWindow)
        // Layout updates must preserve a subsequent native focus handoff.
        other.makeKeyAndOrderFront(nil)
        #expect(other.isKeyWindow)
        coordinator.position()
        #expect(!coordinator.panel.isKeyWindow)
        #expect(other.isKeyWindow)
    }
}
