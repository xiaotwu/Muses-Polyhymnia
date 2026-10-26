# Imported Songs metadata — October 26, 2026

This continuation excludes previously accepted cells. It follows XW-9 / reconciliation area 14 and the new narrow defect [XW-128](https://linear.app/xiaotwu/issue/XW-128), with [PR #22](https://github.com/xiaotwu/Muses-Polyhymnia/pull/22). The user requires background-only work and no publication. XW-74 measurements and Premium/Erato pauses remain unchanged.

## Reproduction and repair

The exact retained isolated Release `0.6.2 / 20261025.3`, bundle `com.muses.acceptance.remaining-20261025`, was restored from its verified 623-entry archive. Its product inputs match the current pre-fix source. A stopped, genuine prior acceptance-store backup supplied 535 Tracks, 1,064 import items, 40 listening events and the saved 534-item queue. No normal-store data or account credentials were copied.

In the real Songs complete table, **A Head Full of Dreams** and the second cover row each displayed Plays **0**, although both saved Track rows have playCount **1**. The candidate stayed paused on Prima at 1:11, volume 0%. The import branch of `CollectionTrackRow.playlistUnion` retained the Track snapshot but dropped `year`, `genre` and `playCount` while constructing the presentation row.

Source `a8e95c5f4fd67de81185f727d48691e94d2103f1` preserves those three fields from an existing linked Track. Lazy imports still use nil/nil/0. Imported dates, stable identity, local-membership precedence, canonical order and persistence remain unchanged. Track/disc-number handling is outside this repair.

The new saved-relationship regression reads through a fresh ModelContext and checks materialized/lazy fields, play-count sorting, canonical indices and absence of model writes. A separate independent source review found no blocking issue. Nonempty year/genre values are controlled-test coverage; the genuine native seed has neither and cannot prove their rendered nonempty state.

## Evidence boundaries

The old native header clicks did not produce a verified sorting change. The Paged song tables checkbox exposed no AX action, and a background pixel attempt did not change it. These are unaccepted input paths, not newly asserted product defects. Earlier title/artist sorting, ordinary pagination, EQ, Home, catalog and Diagnostics passes are reused rather than counted again.

The pre-fix interim audit compares all 27 tables, schema and PRAGMAs: 21 tables are byte/type-equivalent; all nine parsed queue/session JSON values and array orders match. All Track fields and 40 events remain unchanged. Session/queue version and save timestamps, ORM bookkeeping and a sub-picosecond position representation difference are recorded explicitly. This is not whole-database equality.

Private source, action receipts, screenshots, typed snapshots and audit evidence are retained under `~/.muses/tmp/engineering-oct15/background-nonempty-oct26-01a16186`. Completed validation, final audit and cleanup are recorded below. The checkpoint named `old-stopped` was actually captured live; its metadata retains that fact and it is not used as stopped-state proof.

## Validation and new native cells

The new regression failed on the old implementation with five assertions (year, genre, play counts and sorted identity/index order). The repaired snapshot passed 22 tests in two related suites. Independent source review found no blocking issue. The exact-head [CI 40412569935](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40412569935) passed: 1,111 tests in 150 suites (nine explicit conditional skips), 15 strict-thread tests in five suites, one separate disk-recovery test, 50 release-configuration checks, metadata, pinned dependencies and signed preview packaging/upload. PR #22 merged as `0104420b46ffd2359acab1e1435ac35b117def22`; Sources, Tests, Scripts, Dependencies, package files and workflows match the validated `a8e95c5` commit exactly.

A complete new ad-hoc Release `0.6.2 / 20261026.1` was built from `a8e95c5`; its App Intents metadata matches the build. OAuth client credentials, URL handlers and update authority are absent. Strict deep signing, both bundled yt-dlp launches, Deno and the helper/dependency checks passed. One private packaging attempt stopped at pinned runtime-tree verification; its failed output is retained. The retry reused an existing unsigned tree with the exact pinned runtime/license digests and normal packaging directory modes. No dependency pin or product validation was relaxed; the temporary failed extraction was gone, so its exact failing entry is not asserted.

- **Saved play-count display:** the same two real Songs rows now visibly show 1. Before/after pixels were independently reviewed. The AX table read is truncated and its no-change summary is not substituted for the pixels.
- **Plays ascending menu:** a real menu selection removes the two played rows from the first page. Page 22/22 contains precisely the ten saved nonzero identities in count order `1,1,1,1,1,2,3,6,8,11`; ties retain canonical collection order. All ten rows and their original numbers are visible. Paged rows display titles, artists and canonical numbers; the count sequence is independently derived from the unchanged store.
- **Date Added ascending menu:** selecting it from page 22 resets to page 1. The final page ends with the five genuinely later-imported identities: `11:stand still`, `Divine Spell`, `Linaria`, `Memory`, and `Nowlu / リナリア`, with canonical numbers 5/100/181/203/226 preserved. The source projection has 530 earlier and five later members. This accepts ascending menu sorting, not descending native column headers.

Paging was enabled only as a stopped, isolated fixture prerequisite. Its native Settings toggle remains unaccepted. The 21 Next-page actions per route are navigation setup for the newly exercised sort, not a new pagination pass. Title sorting and the card deck were restored as cleanup, not counted again.

The proposed multiple-bookmark/inner-Cancel cell could not be established: AXValue changed the visible time/title but Add used the uncommitted empty/zero draft; targeted text entry was refused for the sheet's key-window mismatch, and the exact sheet had no resolvable AX window. The temporary draft was removed and the outer sheet canceled without Save. The entire 27-table store, schema and PRAGMAs before/after that attempt are identical. This remains an input limitation, not a product defect or accepted bookmark flow.

## Final data and restoration

All three owned candidate PIDs (66951, 71393, 72779) quit normally. The initial-to-final audit compares all 27 tables, schema and PRAGMAs. The 21 business tables are exactly unchanged, including all fields of all 535 Tracks, 1,064 import members, 40 listening events, and empty note/bookmark tables. All nine queue/session JSON values and ordered arrays are semantically identical, including the complete 534-item queue; three JSON strings have only serialization-order changes. Final session/queue positions exactly match the initial IEEE754 values. Intermediate snapshots retain a `-1.8917489796876907e-10 ms` representation difference rather than erasing it.

Actual lifecycle changes are explicitly retained: session/queue versions each +6, save/update timestamps, 12 CHANGE rows (six per state object), 12 transaction rows, one transaction-string row and three primary-key maxima. This is not whole-database equality. The final nine-key preference export matches the pre-paging export byte-for-byte; it does not match the initial two-key seed. A defaults import initially retained the extra paging key; that failed restoration is preserved, followed by explicit stopped-state removal and verified restoration. The task Cua session ended; the shared Cua service remains.

Original 23 parent/coordinator issues retain their remaining matrices. Native headers/descending sort, actual paging toggle, bookmark input, remaining source/account/appearance/focus/accessibility/platform cells and existing pauses are not closed by these results. No audio listening, release or publication claim is added.

## Completed cleanup and tracking

The complete new application ZIP has 623 entries, SHA-256 `d2525032e2c30bad9a525d7b133c7b964b19954b5701513da13d046ffb38461f`. The final profile TAR contains 126 entries, SHA-256 `84b6229be2a8bbd1faddc4ec7c478b3f73159ec648fda865bda6acc82ce41e46`. Independent review verified every entry's content, kind, mode and link target, the retained older 623-entry application archive, all seven archive/artifact hashes, and 877 retained source inputs.

The first cleanup stopped before removing any target because the old candidate had already been unregistered. Its failure receipt is preserved. The reviewed resume verified the live registration inventory (old path absent, new path present), unregistered the exact new path, then removed only 14 owned candidate/profile/preference/private-build paths. Both app paths are absent from registration. All raw databases, source, manifests, screenshots, failure records and final audits remain. Three candidate processes are absent and the Cua session is closed; the shared Cua process is preserved. The five protected roots — normal application, normal data, normal preferences, shared `.build` and shared `build` — have no before/after differences. No normal credentials, Shortcuts, Liked or remote playlist membership were changed.

Final independent reports are `source-review.md`, `native-count-review.md`, `native-sorting-review.md`, `final-data-review.md` and `final-cleanup-review.md` in the private evidence directory. `cleanup-nonempty-receipt.json` records the actual deletion and protection results, not merely a prepared script.

Linear XW-128 is Done under XW-9 in Muses. XW-9/19/5/12/27 and XW-16 were updated and read back without changing their states, parents or previous descriptions. Both Muses project documents were also updated and read back, retaining all prior content. The final project-scoped inventory is **114 issues: 91 Done, 17 In Review and six In Progress**. The original 23 open matrices remain open. No application, feed, release or Pages publication occurred.
