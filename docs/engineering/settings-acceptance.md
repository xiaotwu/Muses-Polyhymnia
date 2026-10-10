# Settings and App Intents acceptance

Round 2 supplements the remaining keyboard/focus cells in [Settings focus follow-up](settings-focus-followup.md); this first-round record retains its original source and observations.

The 2026-10-10 [in-process App Intent handoff repair](app-intents-handoff.md) supersedes the source's custom-URL Intent dispatch described below. The original packaging and native invocation observations remain historical evidence; the repair does not close the outstanding system acceptance cells.

2026-10-08 execution of XW-71 and XW-75, under the [feature acceptance scope](feature-acceptance.md) and [execution coordination](execution-coordination.md). This records the completed local runtime phase, not completion of every external acceptance condition. XW-25 remains open.

## Candidate and evidence

- Source: `c858f67`, including the already verified XW-69/70 baseline. No application source or tests changed in this session.
- Runtime: macOS 27.0.1, build 26A434, Apple silicon. This is not actual macOS 26 GUI acceptance.
- Candidate: version 0.5.11 (20261001.5), disposable `com.muses.acceptance.settings-xw71-oct08`, staged as `build/MusesSettingsXW71.app` and removed after validation.
- Data: SQLite backup of the existing isolated guest acceptance store. Only `test` was opened for playback; no playlist mutations, Liked actions, account writes, cookie-source changes, or output-device changes occurred.
- Appearance: existing system appearance rendered light; classic, Avenir Next and Georgia samples; standard/large text; English, Simplified Chinese and system-language restoration. Regular window: 1280 × 804pt. Compact window: 901 × 804pt, produced through native Window → Move & Resize → Top Left. The minimum-height contract constrained the requested quarter-screen height.
- Private evidence: `~/.muses/acceptance/com.muses.acceptance.settings-oct08/evidence/xw71/`. Native text trees, screenshots, metadata, preference snapshots, source checksum and cleanup results stay outside Git.

The initial sandbox wrapper omitted the existing `disable-library-validation` runtime entitlement and could not load the ad-hoc Sparkle framework. This was a disposable packaging error, not a source defect. The final candidate used the application's existing runtime entitlements, its independent acceptance namespace, no OAuth client and no registered production URL scheme. No OS grants were requested.

The CLI driver initially could not make the target window stably key for native menus, and literal bracket key delivery did not change history. After the user brought the specified acceptance instance forward, the native Cua channel with named bracket keys exercised the routes successfully. The earlier unsuccessful attempts remain evidence of tool limits, not application failures. Large Library Review tables exceeded a bounded 700-node AX snapshot; the rendered rail remained available.

## XW-71 observations

| Cell | Actual result | Evidence / remaining scope |
| --- | --- | --- |
| Ten categories | General, Shortcuts & Gestures, Playback, Appearance, Account, Lyrics, Diagnostics, Library Review, Help & Privacy and About each displayed its owning content. Order matched the contract. | `general-ready`, `category-*` trees/screenshots; Library Review required rendered rail targeting after AX truncation. |
| Ordinary Settings | Command-comma from About and Account returned to General. The sidebar Settings control from browsing also opened General. | Native command observations and final General state; no internal nested path was introduced. |
| Explicit category route | Home source menu → Account and personalized Home settings opened Account rather than General. | `native-account-deeplink.txt`. The unavailable sign-in/build state remained truthful; no consent or credential flow was entered. |
| Window history | Command-left-bracket returned About → Help; Command-right-bracket returned Help → About. Native View → Back returned Account → Home, and View → Forward restored Account. Sidebar Back also returned Appearance → About. | `native-menu-back.txt`, `native-menu-forward.txt`; native command observations. Legacy Desktop redirect was already XW-69 and was not reopened. |
| PlayerBar / playback | PlayerBar was absent in Settings and restored in browsing. The real `test` track Resonating Beats (`3yllbVl1EnY`) advanced from 0:11 before Settings to 0:32 after returning, still showing Pause. | `native-test-playing.txt`, `native-settings-during-playback.txt`, `native-playing-after-settings.txt`. Application volume was 0%; output was unchanged. Playback was then paused. |
| Font search / pointer selection | Avenir filtering exposed matching families. Pointer selection of Avenir Next and then Georgia changed the selected family and the title, track and lyrics role samples immediately. | `font-filtered`, `font-pointer-selected`, `native-georgia-large` evidence. These are the Settings specimen strings, not provider lyrics or lyric timing. |
| Font keyboard cancellation | Opening the picker focused its search field. Escape closed the popover while retaining the already selected family. | Native focused-field observation and `native-georgia-large.txt`. Cancellation is dismissal, not undoing an immediate preference change. |
| Font keyboard selection | **Not accepted.** Tab did not move from the search field to a family button. An attempted targeted Space did not select the family. | Existing global `AppleKeyboardUIMode` was 0. No system keyboard/accessibility settings changed. This is a remaining native keyboard-traversal cell, not proof of a source defect. |
| Live size / language | Large text selection updated samples; English → Simplified Chinese changed the page, rail and all three specimen roles without relaunch. Compact width retained readable controls and samples. Standard text was restored through the native control. | `native-zh-large`, `native-zh-compact-large`, `native-zh-compact-standard`. English regular and Chinese regular/compact were inspected; no complete cross-product matrix is claimed. |
| Saved preferences | After a normal quit and cold launch, the main window started at Home; Chinese persisted, and Appearance showed Georgia with Standard selected. | `native-saved-preferences.plist`, `native-cold-restoration.txt/.png`. A CLI defaults export still resolved the earlier sandbox container domain; the physical final-candidate plist and cold runtime established the actual values. |
| Help / Privacy | All four disclosures expanded and collapsed by pointer, with exposed on/off and Expanded/Collapsed state and the expected real explanatory text. | `native-help-expanded.txt/.png` and native observations. Space after pointer activation did not change the disclosure. Keyboard focus traversal remains unaccepted under the current system condition. |
| Information popover | Paged song tables information opened with readable text; Escape removed the popover and kept Appearance unchanged. | `native-info-open.txt/.png`, final Appearance state. No preference toggle was activated. Focus-return ownership was not proven; a full VoiceOver traversal was not performed. |

XW-71 is ready for review of this evidence, with font/help keyboard traversal and information-popover focus return still open. No speculative code repair was made. Actual macOS 26, VoiceOver, high contrast, Reduce Transparency and Reduce Motion matrices remain the existing separate acceptance work.

## XW-75 packaging and native boundary

The freshly packaged candidate contained `Metadata.appintents/extract.actionsdata` and `version.json`. Its extracted action declarations were inspected against the current source:

| Declaration | Packaged observations |
| --- | --- |
| `PlayYouTubeLinkIntent` | Discoverable; `openAppWhenRun = true`; URL parameter `link` titled YouTube Link; summary “Play ${link} in Muses”; Play YouTube Link shortcut with `play.rectangle` glyph and the declared application-name phrase. |
| `SearchLyricsIntent` | Discoverable; `openAppWhenRun = true`; string `query`, titled Song title or keywords, with empty default; Search Lyrics shortcut with `text.magnifyingglass` and the two declared application-name phrases. |
| Localization | English, Simplified Chinese and Traditional Chinese title, description and parameter strings were inspected in the packaging inputs. The successful packaging script copies these localization directories; native shortcut localization was not exercised. |
| Source authority | Both intents open the existing `muses://` routes. Playback uses the validated external playback router; lyrics opens the editable provider-backed search UI, with a 400-character query limit and no generated lyrics/timestamps. |

`packaged-metadata.json` and `candidate.json` record the exact candidate and declarations. The package build also ran the metadata processor and signature checks successfully. This establishes packaging, not Siri/Shortcuts runtime success.

The current `shortcuts list` completed without a permission request: three existing shortcuts, none matching Muses. The isolated candidate intentionally did not register `muses://`; executing an OpensIntent destination without an isolated handler could route to the normal application. There was no existing runnable shortcut with a proven isolated destination. Therefore no real system Intent invocation was made, no Siri state was changed, and no new OS authorization or shortcut was created. Siri authorization itself was not established and is not reported as disabled.

The real `test` playback above verifies an executable Settings interaction only; it is **not** an App Intent playback result. A real provider lyric query, system invocation, modal boundary, playback pause/restoration and unavailable-state behavior reached through `SearchLyricsIntent` remain unexercised. A direct URL or fake lyrics would not satisfy those cells. XW-75 stays open until an already authorized native invocation can target an isolated candidate safely.

## Verification and cleanup

The Release package build, metadata extraction, hardened-runtime yt-dlp startup checks and deep/strict signature verification succeeded. This session did not repeat the already passing full CI or run a redundant full test suite: no executable source or tests changed. Source inspection and compilation are not substituted for the native observations above.

Before final normal quit, the candidate was paused and restored through native controls to classic font, Standard text, system language, General and its prior 80% app volume. The complete original empty acceptance preference domain was restored during cleanup, including removal of temporary window geometry. The source guest SQLite SHA-256 and complete source preference dictionary matched their pre-session snapshots. Exact candidate processes were gone before removing files.

The disposable app registration, app bundle, isolated data/cache and task-created sandbox container were removed. The regular `build/Muses.app`, installed app, original acceptance source, Keychain and retained private evidence were preserved. The accidental sandbox-launch reports are OS-managed diagnostics and were not deleted. `cleanup.json` records exact paths and checks.

The `settings` runtime-complete marker releases this execution lane for auxiliary-window acceptance. It does not close XW-71, XW-75 or XW-25, and does not claim the remaining external matrices passed.
