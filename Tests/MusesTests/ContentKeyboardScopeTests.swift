import Testing
@testable import Muses

@Suite("Content keyboard scope")
struct ContentKeyboardScopeTests {
    @Test func playbackShortcutsYieldToTextEditingAndSheets() {
        #expect(ContentKeyboardScope.acceptsShortcuts(
            firstResponderIsTextInput: false,
            hasPresentedSheet: false
        ))
        #expect(!ContentKeyboardScope.acceptsShortcuts(
            firstResponderIsTextInput: true,
            hasPresentedSheet: false
        ))
        #expect(!ContentKeyboardScope.acceptsShortcuts(
            firstResponderIsTextInput: false,
            hasPresentedSheet: true
        ))
    }

    @Test("background video keys yield to another window, a native sheet, and its text fields")
    func videoEventOwnership() {
        let cases: [(text: Bool, sheet: Bool, key: Bool, event: Bool, accepted: Bool)] = [
            (false, false, true, true, true),
            (false, false, false, true, false),
            (false, false, true, false, false),
            (false, true, true, true, false),
            (true, false, true, true, false),
            (true, true, false, false, false)
        ]
        for item in cases {
            #expect(ContentKeyboardScope.acceptsShortcuts(
                firstResponderIsTextInput: item.text,
                hasPresentedSheet: item.sheet,
                owningWindowIsKey: item.key,
                eventBelongsToWindow: item.event
            ) == item.accepted)
        }
    }
}
