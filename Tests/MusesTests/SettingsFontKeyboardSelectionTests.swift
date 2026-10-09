import Testing
import SwiftUI
@testable import Muses

@Suite("Settings font keyboard choices")
struct SettingsFontKeyboardSelectionTests {
    @Test func nativeArrowFlagsDoNotDisableNavigation() {
        #expect(SettingsFontKeyboardSelection.acceptsModifiers([]))
        #expect(SettingsFontKeyboardSelection.acceptsModifiers([.numericPad, .capsLock]))
        for held in [EventModifiers.command, .control, .option, .shift] {
            #expect(!SettingsFontKeyboardSelection.acceptsModifiers([.numericPad, held]))
        }
    }

    @Test func navigationIncludesDefaultsAndClampsAtBoundaries() {
        let families = ["system", "", "Georgia"]
        var selection = SettingsFontKeyboardSelection()
        #expect(selection.confirmedFamily(within: families) == nil)
        selection.move(by: 1, within: families)
        #expect(selection.candidate == "system")
        selection.move(by: 1, within: families)
        #expect(selection.confirmedFamily(within: families) == "")
        selection.move(by: 1, within: families)
        selection.move(by: 1, within: families)
        #expect(selection.candidate == "Georgia")
        selection.move(by: -1, within: families)
        #expect(selection.candidate == "")
        selection.move(by: -1, within: families)
        selection.move(by: -1, within: families)
        #expect(selection.candidate == "system")
    }

    @Test func queryChangesAndRemovedChoicesCannotConfirmStaleFamilies() {
        var selection = SettingsFontKeyboardSelection()
        selection.move(by: -1, within: ["system", "", "Georgia"])
        #expect(selection.candidate == "Georgia")
        #expect(selection.confirmedFamily(within: ["system", "", "Avenir"]) == nil)
        selection.reset()
        #expect(selection.confirmedFamily(within: ["system", "", "Avenir"]) == nil)
        selection.move(by: -1, within: ["system", "", "Avenir"])
        #expect(selection.candidate == "Avenir")
        selection.move(by: 1, within: [])
        #expect(selection.candidate == nil)
    }
}
