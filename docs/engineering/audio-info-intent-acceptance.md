# Audio Info handoff to SearchLyricsIntent — October 15

On October 15, 2026, XW-75 accepted one bounded native cell: with Audio Info open, a public-framework SearchLyricsIntent presented the requested lyrics sheet above it. Tab reached Artist; Escape closed only the lyrics sheet and returned to Audio Info. Audio Info's own Close then returned to the same paused, muted recording. No product repair was needed for this presentation. XW-75 remains In Review.

## Source and new clean baseline

[CI 38694351482](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38694351482) passed every stage on exact source `03f7328fffccbcdb7d2105bf7fdf495768906f2a`: 974 tests / 132 suites, 14 release checks, the separate disk-recovery case, Release/App Intents metadata, preview packaging and upload. The isolated candidate froze 443 inputs at that source with an empty patch, bundle `com.muses.acceptance.audio-info-oct15`, build `20261015.7501`. Release compilation, metadata, resources and strict signatures were qualified before native execution.

The user had intentionally removed the previous application, data and private evidence, then explicitly authorized a clean installation from the official GitHub 0.6.0 release. The download matched both the published checksum and asset digest; strict signature and Gatekeeper checks passed. The complete 207-entry installed inventory matched the extracted application, including types, modes, file bytes and symlinks. The newly installed formal application was not launched by this task. This establishes a new baseline rather than restoring the former library or evidence.

The candidate started with an empty isolated store. Through the real Search → Add Link UI, the public video `YfY82CJjyII` was imported, found through Library-source search and played through its track menu, then paused and normally quit. The resulting whole SQLite seed is mode 0400: one Track, zero listening events, title **Avant-garde HISTORY**, artist **Roselia - Topic**, Track UUID `31736fca-c147-42c6-a9bb-20b32509c49b`, play count 1. Both saved-position slots contain 8,693.356009 ms. Native playback/Pause established the seed; no rows were injected. This bootstrap is not a separate import or playback acceptance.

## Runner failures and qualification correction

The initial runner command was rejected before XCTest launched and reported zero tests. Omitting the unsupported repetition argument allowed the hostless unit-test bundle to execute. Request `audio-info-lyrics-01` then entered the source's single `run()` call but failed with `transportCancelled`; the complete failure remains retained. Scoped framework logs show two internal transport attempts inside that one source call. Neither a successful delivery nor a product query-loss defect is established by that failure.

Apple's [App Intents Testing documentation](https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code) and [WWDC26 session](https://developer.apple.com/videos/play/wwdc2026/295/) require a UI testing bundle and the same signing team as the app. A new independent UI-testing target corrected that runner qualification defect. Its relationship to the earlier cancellation remains an inference, not a proven cause.

The new generated runner host and embedded test had matching team signatures and strict verification. It designated no product application under test and contained no UI automation, target launch, activation or termination calls. Its sandbox retained all generated entitlements, adding write access only to the exact new request directory. The frozen test source kept passive candidate identity checks, exclusive attempt consumption and one public-framework call. The old request was not replayed.

## Actual a2 native result

Request `audio-info-lyrics-02` completed Passed: one test, zero failures, outer exit 0; the test case took 0.754 seconds. This is a test duration, not a performance benchmark. The source entered `run()` once and returned with exact candidate PID 54282 and launch identity preserved; internal system attempt counts were not measured for a2.

The coordinator's native AX and screenshot observations establish the presentation sequence:

1. Open Audio Info through Playback while the recording is paused at 0:09, volume 0%.
2. Submit the one external query `Avant-garde HISTORY`; Match Lyrics becomes the top sheet with that query and the current recording.
3. Move focus from Query to Artist with one Tab. Escape closes only Match Lyrics; the retained Audio Info becomes topmost again, with its source, Flat EQ, 0% volume, displayed output device and collapsed technical details preserved.
4. Activate Audio Info's own Close; the main window retains the same recording, paused time and muted volume. Normal Command-Q and exact process absence follow.

There was no second dispatch or menu reopening. The initial private plan incorrectly assumed lyrics would wait until Audio Info closed. The existing source has independent lyrics and Audio Info sheet bindings and does not clear Audio Info when receiving a lyrics request. The observed layered presentation corrects that plan assumption; temporary absence from the top-level AX tree was not evidence that Audio Info had been dismissed. No user or documented product requirement mandated the assumed delay.

## Closed data and protection audit

The restored, after-delivery and after-modal-close backups have identical SQLite bytes, all 27 typed table values and all 64 schema entries. Across normal shutdown, 22 tables remain typed-equal; differences are confined to `ACHANGE`, `ATRANSACTION`, `Z_PRIMARYKEY`, `ZQUEUESTATE` and `ZLISTENINGSESSION` lifecycle/checkpoint serialization. The stopped database is therefore not claimed byte-identical to the seed. All seven queue JSON fields and both session JSON fields are canonically equal after decoding; non-checkpoint queue/session values, the complete Track, one-item queue, empty history/Up Next and both saved positions remain preserved.

All 21 candidate preference keys remain. Only the EQ JSON data bytes differ through object-key ordering; the decoded ten bands are equal. Native paused state comes from observation, not an interpretation of the persisted transport-status field. The clean formal application's full 207-entry inventory remains equal, normal data and its physical preference file remain absent, and keyboard-navigation mode remains 0.

At `2026-10-15T22:48:49.795914Z`, the independent source check rehashed all 443 inputs and found them equal to the qualified a2 freeze. Later user-authorized fuzzy/exact lyrics-search work belongs to XW-101 and is outside this completed native unit.

Private evidence is under `~/.muses/tmp/engineering-oct15/audio-info-intent/`, including both request records, the new seed, closed backups, `independent-review/a2-ui-runner-result-review.json`, `a2-closed-protection-review.json` and the source-timing receipt. Independent review corroborated the closed framework/data evidence; native visual observations are attributed to the coordinator.

The completed candidate, both runner products and isolated namespace were archived as 298 entries, then independently compared against the still-present originals before exact cleanup. The UI runner's own system container has a separate verified archive. Both request records and all raw results remain at their original paths; the whole paused seed remains 0400 and the other twelve closed backups remain 0600. Candidate/runner builds, namespace and the verified runner container were removed, old logical preferences and registrations are empty or absent, and an empty physical candidate plist remains. Independent cleanup review reconfirmed the formal application's 207 entries, absent normal data/preferences and mode 0. These archives cover POSIX metadata, file bytes and literal symlink targets; no ACL, extended-attribute or resource-fork equivalence is claimed.

## Remaining scope

This accepts only the exercised Audio Info → external lyrics → Query/Artist focus → Escape back to Audio Info → own Close/normal Quit cell. No lyrics were applied; a no-match display does not establish provider matching success. EQ/output-device changes, manual Siri/Shortcuts, actual macOS 26, full VoiceOver/device/appearance matrices and performance remain outside this result. XW-75 remains In Review, and a2 supplies no native acceptance for the separate XW-101 fuzzy/exact enhancement.
