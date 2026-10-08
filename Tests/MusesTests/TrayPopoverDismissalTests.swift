import AppKit
import Testing
@testable import Muses

@MainActor
private final class DismissalPopover: NSPopover {
    private var open = true
    private(set) var closeCount = 0
    override var isShown: Bool { open }
    override func performClose(_ sender: Any?) { closeCount += 1; open = false }
}

@MainActor
@Suite("Tray popover dismissal", .serialized)
struct TrayPopoverDismissalTests {
    @Test("Escape closes only its own player and is consumed before window command routing")
    func ownedEscapeDoesNotOpenMain() throws {
        _ = NSApplication.shared
        let main = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        let compact = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 50),
            styleMask: [.borderless], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false; compact.isReleasedWhenClosed = false
        defer { compact.close(); main.close() }
        let controller = NSViewController()
        let content = try #require(compact.contentView)
        controller.view = NSView(frame: content.bounds)
        compact.contentView = controller.view
        let popover = DismissalPopover()
        popover.contentViewController = controller
        let escape = try key(53, window: compact)
        #expect(!main.isVisible)
        let consumed = TrayController.consumePopoverEvent(escape, popover: popover, statusWindow: nil)
        #expect(consumed)
        #expect(!popover.isShown)
        #expect(popover.closeCount == 1)
        #expect(!main.isVisible)
        // A late copy must not close or promote another surface.
        #expect(!TrayController.consumePopoverEvent(escape, popover: popover, statusWindow: nil))
        #expect(popover.closeCount == 1)
    }

    @Test("Arrow input and Escape from native menus or another window retain their owners")
    func preservesUnownedInput() throws {
        _ = NSApplication.shared
        let compact = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        let foreign = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        compact.isReleasedWhenClosed = false; foreign.isReleasedWhenClosed = false
        defer { foreign.close(); compact.close() }
        let controller = NSViewController()
        controller.view = NSView()
        compact.contentView = controller.view
        let popover = DismissalPopover()
        popover.contentViewController = controller
        let left = try key(123, window: compact)
        #expect(!TrayController.consumePopoverEvent(left, popover: popover, statusWindow: nil))
        let outside = try key(53, window: foreign)
        #expect(!TrayController.consumePopoverEvent(outside, popover: popover, statusWindow: nil))
        foreign.level = .popUpMenu
        let menuEscape = try key(53, window: foreign)
        #expect(!TrayController.consumePopoverEvent(menuEscape, popover: popover, statusWindow: nil))
        #expect(popover.isShown && popover.closeCount == 0)
    }

    private func key(_ code: UInt16, window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 1, windowNumber: window.windowNumber, context: nil,
            characters: code == 53 ? "\u{1b}" : "\u{f702}", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: code))
    }
}
