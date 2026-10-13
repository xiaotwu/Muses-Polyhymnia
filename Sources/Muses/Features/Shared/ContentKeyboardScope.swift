import AppKit

/// Unmodified browsing/playback keys must not consume text or sheet input.
@MainActor
enum ContentKeyboardScope {
    static func acceptsShortcuts(in owningWindow: NSWindow?, event: NSEvent? = nil) -> Bool {
        guard let owningWindow else { return false }
        return acceptsShortcuts(
            firstResponderIsTextInput: owningWindow.firstResponder is NSTextView,
            hasPresentedSheet: owningWindow.sheetParent != nil || owningWindow.attachedSheet != nil,
            owningWindowIsKey: NSApp.keyWindow === owningWindow,
            eventBelongsToWindow: event.map { $0.window === owningWindow } ?? true
        )
    }

    static var acceptsShortcuts: Bool {
        guard let window = NSApp.keyWindow,
              window.sheetParent == nil, window.attachedSheet == nil else { return false }
        return acceptsShortcuts(
            firstResponderIsTextInput: window.firstResponder is NSTextView,
            hasPresentedSheet: false
        )
    }

    nonisolated static func acceptsShortcuts(
        firstResponderIsTextInput: Bool,
        hasPresentedSheet: Bool,
        owningWindowIsKey: Bool = true,
        eventBelongsToWindow: Bool = true
    ) -> Bool {
        owningWindowIsKey && eventBelongsToWindow && !firstResponderIsTextInput && !hasPresentedSheet
    }
}
