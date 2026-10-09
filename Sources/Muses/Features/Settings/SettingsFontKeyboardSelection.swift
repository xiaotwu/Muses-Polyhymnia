import SwiftUI

/// A pending keyboard choice is separate from the applied typography preference.
struct SettingsFontKeyboardSelection {
    private(set) var candidate: String?

    /// macOS arrow events can carry numeric-pad and function flags without a held modifier.
    static func acceptsModifiers(_ modifiers: EventModifiers) -> Bool {
        modifiers.intersection([.command, .control, .option, .shift]).isEmpty
    }

    mutating func move(by offset: Int, within families: [String]) {
        guard !families.isEmpty else { candidate = nil; return }
        if let candidate, let index = families.firstIndex(of: candidate) {
            self.candidate = families[min(max(index + offset, 0), families.count - 1)]
        } else {
            candidate = offset < 0 ? families.last : families.first
        }
    }

    mutating func reset() { candidate = nil }

    func confirmedFamily(within families: [String]) -> String? {
        guard let candidate, families.contains(candidate) else { return nil }
        return candidate
    }
}
