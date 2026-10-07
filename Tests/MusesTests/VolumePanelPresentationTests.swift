import AppKit
import SwiftUI
import Testing
@testable import Muses

@Suite("Volume panel presentation", .serialized)
@MainActor
struct VolumePanelPresentationTests {
    @Test func scalePointerReclaimsKeyboardAfterNativeFocusHandoff() async throws {
        _ = NSApplication.shared
        let suite = "com.muses.test.volume-pointer-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let playback = PlaybackService(engine: RecordingEngine(), queue: QueueService(), volumeDefaults: defaults)
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        parent.alphaValue = 0
        let anchor = VolumePanelHost<EmptyView>.AnchorView(frame: NSRect(x: 10, y: 10, width: 230, height: 44))
        parent.contentView?.addSubview(anchor)
        let coordinator = VolumePanelHost<EmptyView>.Coordinator(
            width: 230, height: 44, anchorsToSpeaker: false, speakerGlobalFrame: .zero,
            dismiss: {}, keyAction: { _ in false })
        coordinator.anchor = anchor
        coordinator.panel.alphaValue = 0
        let host = NSHostingView(rootView: MusesGlassGroup {
            LiquidGlassVolumeBar(width: 230, height: 44, focusesScaleOnAppear: true)
                .environment(playback)
                .preferredColorScheme(.light)
        }.frame(width: 230, height: 44))
        coordinator.panel.contentView = host
        let other = VolumePanelHost<EmptyView>.CapsulePanel(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 40),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.alphaValue = 0
        defer { other.close(); coordinator.stop(); parent.close() }
        parent.orderFront(nil)
        coordinator.position()
        host.layoutSubtreeIfNeeded()
        await Task.yield()
        other.makeKeyAndOrderFront(nil)
        #expect(other.isKeyWindow)
        #expect(!coordinator.panel.isKeyWindow)
        let point = NSPoint(x: 110, y: 22)
        #expect(host.hitTest(host.convert(point, from: nil)) != nil)
        let down = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
            modifierFlags: [], timestamp: 0, windowNumber: coordinator.panel.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try #require(NSEvent.mouseEvent(with: .leftMouseUp, location: point,
            modifierFlags: [], timestamp: 0.01, windowNumber: coordinator.panel.windowNumber,
            context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        coordinator.panel.sendEvent(down)
        coordinator.panel.sendEvent(up)
        #expect(coordinator.panel.isKeyWindow)
        #expect(!other.isKeyWindow)
    }

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
