# Settings information-popover Escape acceptance — October 14

XW-99 fixes Escape dismissal when a Settings information popover leaves keyboard focus on its originating button. Source `8560bab7af7312628526bde5be0f00e2eda7742f` passed local Release compilation, independent source review and the specific native keyboard/pointer/text-selection cells below. XW-99 is In Review pending remote CI and PR integration; neither gate has yet been accepted. XW-71 remains In Review for its separate system, VoiceOver and device conditions.

## Original observations and narrow repair

The source-`f73a673` isolated Settings unit ran only after the user explicitly authorized temporary Keyboard navigation 0 → 2 → 0. Four Help disclosure controls received actual Tab focus and expanded/collapsed with Space.

The About paged song tables button had reported AX focus and a visible focus ring; Space opened its information popover. Background Cua Escape while that origin retained focus did not dismiss it. Exact AX Cancel dismissed it and retained origin focus. In a separate opening, Tab reached the adjacent toggle and Escape dismissed the popover without changing the toggle. Cua Raise had not activated the candidate. The human subsequently reported that foreground Escape still left the explanation visible; root's later readback found it absent without an intervening root dismissal. That later disappearance has no attributed timing/cause and does not replace the original human report or constitute a captured physical failure/pass transition.

The repair stays inside `SettingsInfoButton`. The native origin handles unmodified Escape on key-down only while its popover is presented; otherwise it ignores the event. Popover content has a local exit-command dismissal path. No global monitor, blanket focusability, focus-state rewrite, neighboring preference change or service boundary was added.

The first Release attempt on `11957cc` failed after 17.516 seconds because the modifier-aware closure selected the wrong API overload. Its full log remains preserved. Explicit `phases: .down` selects the typed KeyPress overload in the final source, whose Release build succeeded in 66.958 seconds. Independent review of the final frozen source found no blocking issue; source review and compilation are distinct evidence.

## Final candidate and native result

The fresh signed target was `com.muses.acceptance.settings-info-escape-oct14`, version 0.6.0/build 20261014.9901, PID 75669/main window 71427. The 1280 × 804pt candidate ran on macOS 27.0.1 (26A434), Apple silicon, Simplified Chinese, System theme and Standard text. Current source hashes, executable/metadata identity and app/helper strict signatures were qualified before operation. OAuth client values were empty, Web Home was disabled and the production update feed was absent from this isolated candidate.

Under the separately authorized temporary keyboard mode 2, actual Tab reached the information origin with a visible ring. Space opened its popover; Escape closed it while the same origin focus/ring remained. Escape with the popover already closed did not prevent the next Tab from reaching the adjacent Off toggle. Shift-Tab returned to the origin. A native button click also opened the popover, followed by successful Escape dismissal.

The automated text click/Command-A attempt did not establish selected text and is retained as a tool limitation. The human then explicitly confirmed actual text selection and Escape dismissal (“文字已选中，Escape后关闭”). Root subsequently observed the popover absent and focus at the origin. This is human-assisted selected-text acceptance; the later root readback is supplementary, not an independently captured selection transition.

The 32 seeded display/behavior preferences stayed unchanged. No playback, App Intent, metadata Save, lyrics Apply or remote write was activated by this unit.

## Restoration, audit and remaining gates

General was restored. The candidate and task-started System Settings processes quit normally. Keyboard navigation was restored through native System Settings and independently read back as 0. Independent review found matching schemas and all 27 table values from before-business through the origin-Escape and final native checkpoints. Shutdown changed only lifecycle versions/timestamps, JSON object-key order and internal transaction bookkeeping; all seven decoded queue JSON values, 673 Tracks, 82 events, the 530-item queue and saved 60,074.648526 ms position remained equal. Normal before/after snapshots had all 27 table values and all 45 preferences equal; installed Info/executable hashes matched. Strict signatures, metadata, Release UUID and all 439 frozen source-file hashes were independently checked. The exact owned candidate registration, bundle, data/cache and preferences were removed after process exit. An empty own-domain plist left by preferences export was verified empty and removed; the original 0400 seed and private evidence remain protected.

Pre-repair evidence remains in `~/.muses/tmp/engineering-oct14/settings-auxiliary-oct14/`. Final-source build logs, qualification, native observations, actual SQLite checkpoints and restoration records remain in `~/.muses/tmp/engineering-oct14/settings-info-escape-oct14/`, including `attempt-1-release-build.log`, `release-build-evidence.json`, `source-review.json`, `native-final-result.json`, `keyboard-restored.json`, `independent-native-review.json` and `cleanup.json`.

This accepts the recorded local origin-focus, continued-Tab, pointer-open and human selected-text dismissal cells. It does not establish all modified-Escape combinations, full VoiceOver/device/appearance coverage or actual macOS 26 interaction. Remote CI/PR integration remains the separate gate. The installed formal 0.6.0 was not replaced.
