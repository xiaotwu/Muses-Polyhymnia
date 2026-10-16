# Import and Notes draft handoffs to SearchLyricsIntent — October 15

On October 15, 2026, XW-75 accepted two bounded native cells. A nonempty Add Link draft survived an external lyrics sheet and its own Close. An unsaved Notes draft remained intact while an external lyrics request waited; the editor's explicit Cancel then released the pending lyrics presentation without another dispatch. No product repair was needed. XW-75 remains In Review.

## Qualified source and isolation

Before this continuation, exact documentation commit `691cf1770fa8949ef3d7f502161701f99f5e3baa` had passed all 11 stages of [CI 38836293957](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38836293957): 998 tests / 134 suites, 9 opt-in skips, 14 release checks, the separate disk-recovery test, Release/App Intents metadata, preview packaging and upload. Parent reference `9a2deec` was pushed. This was documentation integration, not a formal application release.

The new candidate froze 446 inputs at that commit with an empty patch. It reused the qualified Release executable, helper and two compiler constvalues files; it did not rebuild the product or claim new constvalues emission. Fresh candidate App Intents metadata, resources, signatures and runtime isolation were qualified independently. Candidate `com.muses.acceptance.import-draft-oct15`, build `20261015.7503`, ran once as unit `i1`, PID 99979, on macOS 27.0.1 / Apple silicon. Keyboard-navigation mode remained 0.

The whole genuine paused seed from the [Audio Info unit](audio-info-intent-acceptance.md) was copied into a new writable isolated namespace. The original seed remained 0400. It contains one recording, **Avant-garde HISTORY / Roselia - Topic**, YouTube ID `YfY82CJjyII`, Track UUID `31736fca-c147-42c6-a9bb-20b32509c49b`, play count 1 and no listening events. No rows were injected. The official installed 0.6.0 application remained the existing clean, unlaunched baseline.

Two separate UI-testing helpers used public AppIntentsTesting. Each retained the generated sandbox and matching team signatures, adding write access only to its own exact request directory. Neither designated a product application under test nor contained UI automation, target launch or activation. Each first checked the running candidate and published readiness; only then did the coordinator establish the native draft, save the fixed checkpoint and explicitly approve that request's nonce, ready hash, PID and launch identity. Exclusive attempt consumption preceded one source `run()` call. Both complete results were Passed 1/0, outer exit 0, with no request replay. One source call does not establish the number of internal system transport attempts.

## Nonempty Import draft

After helper readiness, the real Search → Add YouTube music route opened AddYouTubeLinkSheet. The coordinator pasted exactly `https://www.youtube.com/watch?v=YfY82CJjyII&t=9s`. AX and screenshot readback showed the same URL, Single detection and an enabled Import button. Import was never activated.

The one external `Avant-garde HISTORY` query presented Match Lyrics above the draft. Query was focused; one Tab reached Artist. All sources and the default Fuzzy mode were visible, with no candidate selected and Apply disabled. Lyrics' own xmark Close returned to the original Add Link overlay with the exact same nonempty URL and parser state. Its real Cancel then closed the draft. The same recording remained paused at 0:09, volume 0%, Repeat Off and Shuffle Off.

This accepts preservation of an active nonempty URL draft across this lyrics presentation. It adds no completed-import, provider-match, lyrics-Apply or draft-restoration-after-Cancel result.

## Unsaved Notes draft

The second helper became ready in the same application process after the Import cell had closed. Songs showed its empty state, so no row was activated there. The coordinator returned to Home and opened the visible recording's More → Notes & Bookmarks menu. This route correction is retained; it is not a Songs-content acceptance or a product repair.

The real editable Notes TextEditor received the following two unsaved lines, verified in AX and a screenshot:

```text
XW75 Notes i1 / 7503 / PID 99979
Unsaved handoff draft: preserve this exact text.
```

After the one external request returned, the same Notes editor remained topmost with both exact lines and editing focus preserved. Lyrics did not appear above it. The real Notes Cancel explicitly discarded the draft, as described by the product's visible cancellation text. Match Lyrics then appeared automatically with `Avant-garde HISTORY`, empty Artist, All sources, Fuzzy mode and eight candidate rows. There was no second dispatch. One Tab reached Artist; lyrics' own Close returned to Home with the same paused, muted recording.

Save, bookmark operations, lyrics selection/Apply and Play were never activated. This accepts draft preservation while the request waits and the pending presentation after explicit cancellation. It does not accept draft restoration after Cancel or claim a lyrics-over-Notes presentation.

## Closed data and protection

Independent review compared all 27 typed tables and schemas in ten closed backups. The first nine, from startup through both cells and final main-window readback, have identical database bytes and values. The complete Track's 35 columns remain equal to the original seed in all ten; Notes, Bookmarks, listening events, EQ presets and imports remain zero. All seven queue JSON fields and both session JSON fields retain equal decoded values, including the same single current recording, empty history/Up Next, Repeat Off and Shuffle Off.

Whole-file equality to the seed is not claimed. Seed → startup changes six lifecycle/checkpoint tables; startup → normal Quit changes five. Both saved-position slots remain 8,693.356009070294 ms during the cells and round to 8,693.333333333334 ms on normal shutdown, a −0.02267573696008185 ms delta. The detailed audit retains those differences and does not interpret a persisted session-status field as proof that transport was playing. All eleven main database files, including the seed, and ten existing SHM sidecars retained their modes, sizes and hashes throughout the read-only audit.

All original 18 typed preferences remain equal. The stopped export contains 21 keys, adding the native window frame, Home browse-route data and ten flat EQ bands with Q 1. These are recorded additions, not a claim of an unchanged entire domain or an EQ interaction. The independent protection audit rechecked the formal application's full 207-entry inventory, absent normal data/physical preferences, original 0400 seed, all 446 product inputs, reused Release/resources/constvalues, prior retained evidence and all seven protected completed trees. Keyboard-navigation mode stayed 0, and the exact owned application and runners were stopped.

## Evidence and remaining scope

Private evidence is under `~/.muses/tmp/engineering-oct15/intent-import-draft/`: the root's retrospective `native-drafts-result.json`, both complete requests, runner source and qualification receipts, ten closed SQLite backups and stopped preferences. Native observations are attributed to the coordinator's direct Cua AX and screenshots; independent reviewers verify closed framework, data and protection artifacts without claiming another GUI run.

The complete test cases took 33.350154 and 29.213365 seconds, including coordinator gating; these durations are not performance results. Both xcresults have zero failed/skipped tests, no runtime warnings and no build/analyzer errors or warnings. The outer command logs retain their CoreSimulator-version and multiple-matching-destination notices; this does not claim warning-free CLI output. Full binding and table-value audits are retained in `independent-review/i1-closed-data-protection-review.json` and its detail files.

The candidate, isolated data/cache namespace and both complete runner builds were archived as 7,344 members, including the stopped logical and physical preferences. An independent direct comparison checked every member against the still-present originals before the four exact temporary directories were removed. The runner's one verified system container has a separate 48-member archive and direct original/tar review. Exactly the candidate and two runner-host paths were unregistered; the fresh final dump has zero entries for the three exact identifiers. The isolated logical preference domain is empty, with its empty physical plist retained. Both cleanup results report no error and unchanged protected evidence. Original source, both full request results, ten backups, sidecars, stopped exports, the original seed and current build remain available. The archives do not claim ACL, extended-attribute or resource-fork parity.

The two cells add no manual Siri/Shortcuts binding, actual macOS 26 runtime, full VoiceOver/device/appearance matrix, provider matching correctness or performance acceptance. Earlier accepted cells and original failures retain their existing boundaries. Formal 0.6.0, the original paused seed and prior evidence remain protected; no new formal release or Pages publication is part of this continuation.
