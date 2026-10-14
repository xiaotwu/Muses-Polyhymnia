# Edit Info draft handoff to SearchLyricsIntent — October 14

On October 14, 2026, XW-75 accepted one bounded native handoff: an incoming SearchLyricsIntent preserved an existing unsaved Edit Info title draft; canceling the editor then presented the original recording-title query without a second dispatch. Query-field Tab and lyrics-sheet Escape worked in the exercised route. XW-75 remains In Review for its other presentation and system/device conditions.

## Candidate and evidence

The fresh signed isolated candidate was frozen to `f73a67340cff2dc49e5bca9f61307690f751761b`, whose executable source is identical to the merged `e6ae129` baseline. The current-source Release, bundled resources, helper, App Intents metadata, strict signatures and runtime isolation were qualified before the native unit. The private runner was built independently and did not launch or host the target application.

The target was `com.muses.acceptance.edit-draft-oct14`, version 0.6.0/build 20261014.7501, exact PID 72642/main window 71142. Runtime was macOS 27.0.1 (26A434), Apple silicon, a 1280 × 804pt window, Simplified Chinese, System theme and Standard text. The existing system keyboard-navigation mode remained 0 throughout this unit. Exact executable/Info/metadata hashes, launch time, current Track UUID/title, unique draft marker and request bindings are retained privately.

Private evidence: `~/.muses/tmp/engineering-oct14/edit-draft-handoff/`. The native observations are in `native-draft-observation.json` and `native-handoff-result.json`; the complete framework result and its 38-file archive proof are under `requests/edit-draft-lyrics-01/`. The runner establishes framework delivery and passive target identity; the coordinator's native AX and screenshots establish the editor, draft and subsequent sheet behavior.

## Actual native result

The existing current recording was paused at 1:00, with candidate volume 0%, Repeat One and shuffle Off. In the existing Liked detail, the focus was 122/530. The normal track Options → Edit Info route opened the verified editor. Only Title was changed to a unique unsaved marker; Save was never activated. Initial Home menu attempts failed to bind the intended route and caused no editor or playback activation; those tool attempts remain in the private observation record.

Exactly one public-framework SearchLyricsIntent was dispatched against the frozen target while that editor remained open. The full XCTest result was Passed: one test, zero failures, zero skipped tests, no runtime warnings, outer exit 0. There was no automatic retry. Its command completed in 5.03 seconds; that duration is not an interaction or playback benchmark.

After delivery, the same Edit Info sheet still contained the exact draft marker. Cancel closed only the verified editor. The pending lyrics sheet then appeared with the original stored recording title, without another Intent dispatch. The query field received focus; Tab moved to Artist. Escape closed only the lyrics sheet and returned to the same collection focus, paused time and muted volume. No metadata Save, lyrics Apply, playback or remote write was activated. No provider-match success is claimed.

## Data, restoration and cleanup

Before-business, before-Intent and after-Intent checkpoints had matching schemas and all 27 table values. Normal-app before/after checkpoints likewise had all 27 table values equal; all 45 complete normal preferences and the installed Info.plist/executable hashes matched.

Normal candidate shutdown changed lifecycle ORM/timestamps and JSON serialization order. Those changes are recorded separately rather than presented as whole-file equality. Independent read-only comparison confirmed equal decoded values for all seven queue JSON fields, equal non-lifecycle queue/session scalars, 673 Tracks and 82 listening events, and both saved-position slots remaining 60,074.648526 ms.

Temporary candidate preferences were restored, then its disposable domain was removed. The exact candidate and runner processes were absent; owned registration, candidate bundle, data/cache namespace, runner build/container and expanded result directory were removed after the complete result archive was verified. The original seed hash and 0400 mode, normal application, data/preferences and credentials were preserved. Source and other retained evidence remain available.

Final independent review found a remaining zero-key physical candidate preference plist after domain deletion. Its exact ownership, empty contents and absent candidate process/namespace were verified before removing only that file. The earlier cleanup receipt is preserved; `cleanup-empty-preference-followup.json` records this correction without re-exporting the deleted domain.

## Remaining scope

This accepts only the exercised unsaved Title draft → one external lyrics request → Cancel → original query → Tab → Escape cell. It adds no manual Siri/Shortcuts, actual macOS 26, full VoiceOver/device/appearance matrix, provider matching, playback or performance result. Earlier accepted cold/window/serial/video cells and their original failures retain their documented scope. The installed 0.6.0 was not replaced, and no production source repair was needed for this cell.
