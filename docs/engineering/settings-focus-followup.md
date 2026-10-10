# Settings keyboard and focus follow-up

2026-10-08, round 2 of XW-71. This supplements [the first Settings acceptance](settings-acceptance.md); the accepted category, route, pointer, playback and language-restoration cells were not repeated. XW-75 remains Backlog and its metadata and external routes were not retested.

## Scope and native conditions

Source baseline `676e53d`; macOS 27.0.1 (26A434); 1280 × 804pt main window; existing system appearance rendered light; English, classic font and Standard text. The independent `com.muses.acceptance.settings-focus-oct08` candidate used a SQLite backup of the retained isolated guest source, no OAuth client and no production URL handler. No playlist edits or playback were performed in this round.

Private evidence is retained under `~/.muses/acceptance/com.muses.acceptance.settings-focus-oct08/evidence/`. Both global locks were held during builds, tests, native operation and cleanup; round-2 status/completion files use the `settings-focus` key.

The existing `AppleKeyboardUIMode` was 0. Apple distinguishes editing focus from activation focus: button-like controls do not obtain focus by a pointer click and need system Keyboard navigation for Tab traversal. See [the SwiftUI focus cookbook](https://developer.apple.com/videos/play/wwdc2023/10162/) and [focus interactions](https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)). This explains the remaining Help/button traversal condition; it does not prevent a focused search field from handling result navigation. No system keyboard, accessibility, authorization or output setting was changed.

A Cua `typeText` call dismissed the transient font popover. The query was therefore prepared with the native field's AX settable value, then actual Down/Return/Escape key calls were evaluated with the focused element and rendered state. This transport limitation is separate from the application behavior.

## Confirmed defect and repair: XW-80

Before repair, opening the font picker focused Search system fonts. A Georgia query exposed the installed Georgia result. Down left the field focused without a result highlight; Return selected the query text and left Classic Muses applied. Escape dismissed the unconfirmed query. `before-arrow`, `after-down` and `after-return` preserve the native observations.

`SettingsFontPicker` only had search-field focus and `onExitCommand`; there was no arrow or submit path. XW-80 records this reproducible custom-picker defect separately from system-conditioned Tab navigation.

The narrow repair handles unmodified Up/Down in the already focused search field. It tracks a pending candidate independently of the saved family, draws an outline on that candidate, exposes “Ready to apply”, and scrolls the row into view without animation. Return applies a still-visible candidate. Query changes discard the candidate; pointer selection still applies immediately and clears it. Escape closes without applying an unconfirmed choice. System and Classic remain the first two rows. Command/Control/Option/Shift arrows retain native text-editing behavior. Native numeric-pad/caps-lock flags do not disable result navigation. No additional `focusable` control, global key monitor or shared service was introduced.

## Help and information focus boundary

Help & Privacy contains activation controls with no owning editable-field focus. Under the unchanged system condition, Tab and Space did not expose focused disclosure controls or change their values. This is not accepted as keyboard traversal and is not evidence that pointer activation established a keyboard focus to restore. No bypass or blanket focus modifier was added.

The Paged song tables information popover opened and Escape removed it. The subsequent tree retained Appearance and its controls, and the rendered capture had no origin-button focus ring. The native capture did not report a focused originating button before or after cancellation; origin-button focus return remains unproven. This round does not count window presence or a successful dismissal as that stronger focus result. The existing source uses native Button/popover semantics and has no explicit origin-focus binding; no new defect was inferred from the current system-limited traversal.

`info-open`, `info-after-close-focus` and `help-keyboard-after` preserve these boundaries. Full native activation-control traversal/focus return with existing authorized Keyboard navigation, actual macOS 26, VoiceOver and deferred accessibility matrices remain open in XW-71/XW-25.

## Validation and cleanup

The final repaired candidate passed native Up/Down and Return verification with the system keyboard mode unchanged. With a Georgia query, Down visited System, Classic and Georgia in displayed order. Up returned to Classic and Down returned to Georgia. The pending Georgia row had a visible outline and “Ready to apply”; Classic remained applied until Return changed the preference and specimens to Georgia. AX reported the search field as the focused element during navigation (`repaired-georgia-pending`).

Changing the query to Avenir cleared the pending choice; Return without a new choice retained Georgia (`repaired-query-reset`). In a freshly focused picker, Up exposed Avenir Next Condensed as the pending choice, and Escape closed without applying it (`repaired-before-cancel`, `repaired-after-cancel`). These are real installed system fonts and native key events, not invented results. The first trial's broad empty-modifier check rejected native arrow flags; the final handler distinguishes held command modifiers from native arrow flags. Apple documents the [numeric-pad flag for arrow events](https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.struct/numericpad).

Three focused tests passed: native arrow flags versus held modifiers, default/Classic choices and navigation bounds, and query-reset/stale/empty choices. The final Release build completed in 63.72 seconds; deep/strict candidate signature verification passed. No full test suite or App Intents acceptance was repeated. Compilation and pure state tests complement the rendered native verification.

Classic font was restored through the native control before returning to General and normal quit. Standard text, English and the preconfigured independent feature flags were retained. The complete original empty preference domain was restored after process exit. Source SQLite SHA-256 and the complete source preference dictionary matched their initial snapshots; `AppleKeyboardUIMode` remained 0. The exact owned process was gone before removing the disposable bundle registration, app, data and cache. Normal application/build, source data, Keychain and both rounds of private evidence were retained. `cleanup.json` records exact checks and paths.

XW-80's repaired search-field keyboard path is accepted locally. XW-71 remains In Review for the Help/activation-control focus conditions and the existing macOS 26/VoiceOver/accessibility matrices. The round-2 runtime-complete marker releases the owned executable phase to `auxiliary-focus`, without asserting those external cells passed.

## Dark compact visual follow-up — October 10

The isolated `com.muses.acceptance.settings-darkcompact-20261010` candidate reused the source-equivalent `e44a058` Release. Its main window remained 840 × 804 pt, in application Dark appearance. No source, build, tests, authentication, output or OS permission changed. Three new visual cells passed:

| Cell | Accepted rendered evidence |
| --- | --- |
| Standard font picker | The first Avenir candidate had a distinct pending outline while Classic retained its complete checkmark and selected marker. The search field was focused; Title, Track and Lyrics samples were complete. |
| Large font picker | The same pending/current states and all three larger role samples remained readable without truncation or overlap. Navigation stayed available. |
| Large Help | Account & browser access and Playback & cache expanded with complete text. Scrolling reached the end and all four Support rows; both explanations then collapsed, with navigation visible. No support link was opened. |

`cell1-final`, `cell2-final`, `cell3-expanded-top`, `cell3-expanded-bottom` and `cell3-collapsed` retain native images and AX state. The root coordinator independently inspected the final Standard/Large and Help-bottom captures. Pending-state arrows only prepared the required visual state; Return was not used to apply a family, and no new functional keyboard or VoiceOver pass is claimed.

An initial parent-window capture excluded the part of the native popover extending beyond that parent. The isolated window was reopened at the screen's right edge, keeping its size, and the complete popover became visible in the main-window capture. Large geometry was main x960/y39/840×804 pt and popup x1394/y72/406×386 pt, with the right edge at screen x1800. A separate popup-target capture returned `ax_window_unresolved` and inconsistent image/geometry; it remains tool evidence, not proof of application clipping. The final acceptance uses coherent main-window images and typed geometry. No foreground escalation was used.

Standard text was restored through native UI and Classic was never changed. The app quit normally; the complete original empty preferences and physical-file absence were restored. All 309 protected source files, four normal-app entries and full donor preferences matched. The coordinator independently checked these hashes, donor preferences and removal of the exact app, data/cache and preference file. Owned registration and obsolete candidate material were removed; evidence, normal applications, source seeds and the current Release remain. Both locks were released in `settings-dark-compact-20261010`.

Private evidence: `~/.muses/acceptance/com.muses.acceptance.settings-darkcompact-20261010/evidence/`. These three visual cells are complete. XW-71 and its parents retain activation-control/origin-focus, actual macOS 26, VoiceOver and the other explicitly deferred matrices.
