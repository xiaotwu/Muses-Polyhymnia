# Auxiliary focus and genuine lyrics follow-up

2026-10-08, second-round XW-72 acceptance. Preserve [the first-round lifecycle, Pin and shared-volume results](auxiliary-acceptance.md); those were not rerun as a matrix. XW-72 remains In Review and XW-25 remains open.

## Candidate and conditions

- Source `a814d74`, including the XW-80 font repair. The reviewed MiniPlayer, desktop lyrics, keyboard-scope and button-style fingerprints remained unchanged. This session modified documentation only.
- Native runtime: macOS 27.0.1 (26A434), Apple silicon, existing `AppleKeyboardUIMode=0`. No OS keyboard, accessibility, appearance, permission or output setting changed.
- Disposable candidate `com.muses.acceptance.auxiliary-focus-oct08`, staged as `build/MusesAuxiliaryFocus.app`; ad-hoc/current runtime entitlements, no sandbox, OAuth client or production URL scheme. Separate guest-store backup, preferences and data/cache; app playback was muted and yt-dlp cookie source was None.
- Private evidence: `~/.muses/acceptance/com.muses.acceptance.auxiliary-focus-oct08/evidence/`. `candidate.json`, `observations.json`, source/preference snapshots, owned-window captures, provider provenance and `cleanup.json` remain outside Git. The exact genuine provider document was retained privately before deleting the disposable cache.

The second-round Settings completion marker preceded acquisition of the global runtime lock. The workspace lock was briefly held by the scrolling documentation lane; staging waited for it rather than stealing it. Both locks remained owned through runtime, restoration, cleanup and submission.

## MiniPlayer keyboard observations

The initial pointer accessibility action on the MiniPlayer transport did not change its Pause state. A fresh image located the same button; pixel input paused it successfully. Command-P then changed Play → Pause → Play. This is an observed delivery difference, not a confirmed application defect.

The restored queue used Repeat One. Command-Right retained the current Resonating Beats item and resumed playback, consistent with current `QueueService.next` and its existing repeat-one test. No queue rewrite was made. With Repeat Off temporarily selected in the disposable copy, Command-Right changed to test's second item, 酸橙色信箋; Command-Left returned to Resonating Beats; Command-P paused. Second-item identity selection is established, not its audible playback.

Tab and Shift-Tab left the reported focused element at the MiniPlayer window. Space did not activate a control or reveal a button focus state. Under the unchanged keyboard mode, control traversal/Space activation remains unaccepted. The successful application-menu shortcuts do not substitute for that cell or for full VoiceOver/physical keyboard traversal.

## Genuine desktop lyrics and handoff

Read-only membership inspection confirmed the previously accepted lyric recording **A Head Full of Dreams** (`rwdwb5Fkgso`) is in `test`, canonical zero-based order 359. Only this known recording was queried for the additional lyric branch; no whole-library network search or uncertain stored text was used.

Library search opened that existing item. It actually played and was paused, displaying Coldplay, the matching album and 3:44 duration. Automatic lookup truthfully returned the Find Lyrics prompt. The native Match Lyrics workbench returned 21 real LRCLIB candidates, all labeled Synced. The matching Coldplay / A Head Full of Dreams album / 3:44 recording was selected and applied. Its UI reported LRCLIB Synced. No alternate live/instrumental recording was chosen to fill a matrix, no timing was removed, and no lyrics were injected into SwiftData.

The retrieved document has 41 actual time tags, beginning 32.24 and 35.39 seconds. Native first-line activation sought the paused player to 32.24. The existing desktop panel then rendered that genuine line in both application Light and Dark conditions, with readable white text over its intentional black surface. This adds real content evidence to the first round's truthful No lyrics branch.

The desktop surface is a read-only nonactivating panel with no transport controls. Its exact owned window was 55759, 700 × 120pt. An exact-window background drag returned `background_unavailable` and did not move it. The reactionary foreground retry moved it +50pt / −10pt, verified through independent frame and rendered readback. The subsequent Cua state still identified the existing MiniPlayer as the focused window; Command-P resumed, then paused. That establishes the exercised mediated handoff. Foreground delivery and targeted key dispatch may rebind focus, so it is not an uninterrupted physical nonactivation proof.

An exploratory playback-time capture was not a controlled continuous timing assay. A later native read was interrupted by the locked Mac; manual unlock was requested, GUI actions stopped, and the live instance/locks were retained. A later successful native read re-established availability before continuing. The track was then at its natural 3:44 end. That incidental one-item search completion is not a queue-tail/wrap acceptance result.

After reopening the retained LRCLIB document, the paused position control was set to **the document's genuine second tag, 35.39**. The slider read 35.39 with Play still shown; the desktop immediately rendered the matching second line. `desktop-paused-seek-second-line` records this reliable paused-seek result. This does not claim every timing, translation, provider or background-display condition.

No genuine unsynced candidate was selected in this bounded recording search. The uncertain existing stored plain-text item was not used merely because it existed. The unsynced desktop branch remains open.

## Concrete 64-area mapping

| Area | Added evidence | Retained boundary |
| --- | --- | --- |
| 46 Auxiliary players/lyrics | Post-pointer MiniPlayer Command-P; Repeat-Off next/previous within test; genuine LRCLIB desktop rendering, paused line change and mediated drag/key handoff. | Button traversal/Space, uninterrupted physical handoff, genuine unsynced content and remaining auxiliary states. First-round lifecycle/Pin/volume stays accepted. |
| 63 Keyboard/focus/VoiceOver | Native supported playback shortcuts and reported MiniPlayer focus after the exercised desktop drag. | Full control-focus loop/physical traversal/VoiceOver; no OS setting was enabled to create these conditions. |
| 40 Lyrics/timing/modes | Real selected recording/provider provenance and actual 32.24/35.39 tags displayed on the desktop surface. | No fabricated timing; no complete continuous synchronization, translation or all-provider pass. Existing XW-68 evidence remains separate. |
| 06 Light/Dark/accessibility | Genuine desktop lyric and Dark MiniPlayer rendered under application appearance settings. | System-Dark tray was not reached or retested; no OS appearance setting changed. Full contrast/transparency/motion matrix and actual macOS 26 remain open. |

No confirmed auxiliary source defect was found, so no speculative patch or duplicate defect child was created. The native switch/action no-op, stale element ID, unavailable background delivery and locked-Mac interruption are tool/condition evidence, not automatically application failures.

## Verification, restoration and cleanup

Release packaging succeeded with incremental compilation (0.39s), App Intents metadata processing, helper/yt-dlp checks and deep/strict signing. No source/tests changed and no redundant local test suite ran. Source inspection and compilation do not replace the native observations above.

Before cooperative Command-Q, the player was paused at 35.39, Repeat One and 80% app volume were restored, MiniPlayer was normally closed, both auxiliary switches were Off, Menu bar was On, and language/theme followed System. The 1280 × 804pt main geometry was unchanged. The full original empty candidate preference domain was restored after exit, including physical plist removal.

Exact PID 60271 and its bundle/helper subprocesses were absent, as were all owned WindowServer levels. Source guest SQLite SHA-256 and complete source preference dictionary matched the pre-session snapshots; keyboard mode remained 0. Identifier, ownership, canonical-path and stopped-process guards preceded removal of the disposable app registration/bundle, isolated data/cache and inspection module cache. Normal/installed apps, source data/preferences, Keychain, current shared Release build and necessary private evidence were preserved. No tests ran, so no test fixture cleanup was needed.

The second-round `auxiliary-focus` completion marker releases this currently executable lane for flows. It does not close XW-72/XW-25 or convert the remaining system-Dark, unsynced, control-focus, VoiceOver and macOS 26 conditions into passes.
