# Artist detail and online catalog follow-up

On 2026-10-14, XW-73 exercised Roselia's library detail, a genuine public online discography, a same-process re-read, ordinary horizontal browsing and Back. XW-73 remains In Review. A separate accessibility-action crash is tracked as [XW-100](https://linear.app/xiaotwu/issue/XW-100/muses-investigate-artist-online-shelf-accessibility-scroll-crash); its cause and remedy are not established by this acceptance unit.

The signed isolated candidate used `c5b45c9`, build `20261014.7302`, on macOS 27.0.1 (26A434), Chinese, regular 1280 × 804pt. All 439 executable inputs match the locally tested `8560bab` and CI-tested `639a277`/`fc339c8`. No new product source or tests were changed for this unit. Initial observations rendered light; the later unlocked continuation rendered dark without a task-authored system appearance change. These observations do not establish the complete appearance or macOS 26 matrix.

## Genuine source and ordinary interaction

The entire immutable October 11 [actual UI-import checkpoint](library-catalog-acceptance.md) was copied unchanged, SHA-256 `a8590c3b1da44ca8e74894e5db6e086fad5c60500ee73105c9b97567681756db`. No rows were injected or new import performed. Its 679 Tracks, 60 listening events, the 24 Roselia occurrences and memberships, inherited 655-item queue and paused 20-second session are distinct from today's normal application baseline.

Artists → Roselia opened the real `channel:UCLeeo2KeEketIWQ2QK8qXLw` detail with 24 library songs and one library album. The top and lower rendered rows covered the 24-song title-sorted projection; this order is not the original import order. The sidebar and paused, muted PlayerBar remained present. Explore Online returned eight displayed song/video rows and an official-release shelf, backed by 17 valid unique album browse identities in the actual normalized response. Initial AX exposure of 15 cards and paint of the first seven were observation limits, not evidence of a missing-card defect.

A separate continuation process reached the same detail and completed two ordinary Explore Online reads. The second response's `fetchedAt` advanced from `813720373.51106` to `813726220.927607`; the long interval included screen lock and waiting for manual unlock, and is not request latency. All five song, ten video and 17 album records retained their values and order. Related artist recommendations and three playlist artwork URLs changed; the entire response is not claimed equal. No transient loading frame was captured. The UI has no manual Load More control; normalized results do not prove that a provider continuation was encountered or exhausted in this run.

Tool-delivered ordinary horizontal scrolls produced no visible displacement. The user then explicitly confirmed using the trackpad to reach the right end and see **Reweave (Cover)** and **礎の花冠**. Root's subsequent AX read and rendered image independently showed both tail cards. Human input and the later observation are recorded separately. This establishes tail reachability; it does not claim an individually inspected drawing of every intermediate card. Back returned to Artists with Roselia / 24 songs and the unchanged unresolved-library notice. No playback, Import, account, Web Home or remote write was activated.

## Separate unexpected exit

The first process, PID 82490, exited unexpectedly after the shelf list's declared `AXScrollToBottom` action. The tool returned process-not-found, and a passive process check confirmed absence before any Quit or relaunch. The owned crash report matches PID, bundle, build, launch time and executable UUID. It records SIGTRAP / EXC_BREAKPOINT on the main thread in SwiftUICore `AGAttribute.syncMainIfReferences`, `ForEachState`, lazy layout enumeration and SwiftUI accessibility scroll handling. The internal `scrollToBeginning` frame does not establish the action parameter or a selector mismatch.

Two independent source/diagnostic reviews found valid unique stable IDs, no source array truncation and main-actor catalog assignment. No business-source fault frame or assertion message identifies a narrow repair. Duplicate-ID, off-main update and blanket eager-layout fixes are unsupported. XW-100 retains the original IPS and a controlled isolation plan. Full VoiceOver and another OS were not tested.

PID 83428 was a separately identified ordinary relaunch of the same frozen bundle. Its successful re-read, human scrolling, Back and normal Command-Q are not relabeled as completion of the failed first process. The declared crashing AX action was not repeated in that continuation.

## Minimal diagnostic comparison

A separate private SwiftUI L0 application fixes the same 17 IDs, titles and order, displaying only 140-point placeholders and text in a horizontal `ScrollView` / `LazyHStack` / `ForEach`. It has no business services, asynchronous artwork, interactive cards, networking, catalog updates or application-store access. Final linking metadata matches the product's minimum OS / SDK fields, 26.0 / 26.0, with the actual compile SDK path recorded separately as 27.0. An earlier unlaunched 14.0 / 14.0 artifact and the initial compile error are retained; neither was used for the native trial.

Five distinct private processes each received one currently advertised list `AXScrollToBottom`. Each produced a rendered/AX tail including **Reweave (Cover)** and **礎の花冠**, then stopped with normal Command-Q and an exact process-absence check.

| Variant | Change from the preceding control | PID |
| --- | --- | --- |
| L0 | Display-only horizontal lazy collection | 90168 |
| N1 | Outer vertical ScrollView and bottom spacer 0 → 900 to create overflow | 90395 |
| B3 | Wrap the unchanged card in a native no-op Button with plain style | 90444 |
| C1 | Add `accessibilityElement(children: .contain)` to that Button | 90488 |
| C2 | Add a named Open action with a no-op handler; the handler itself was not activated | 90528 |

These are single simplified trials, not application regression passes or exclusions of those components from the richer page's cause. They do not reproduce the original preceding library lists, scrolled page position, full artwork/menu/hover/focus behavior or live catalog updates. Actual window/shelf geometry was not independently measured. N1 intentionally changes both nesting and the necessary overflow. App bundle identities and window titles differ; the Window id and L0 page copy remain shared. L0's Info.plist still states minimum OS 14.0 while its actual final Mach-O is 26.0 / 26.0; the later controls' Info minimum is 26.0. No complete metadata/geometry equivalence or causal production fix is claimed.

## Data protection and cleanup

Consistent snapshots separate the whole seed, startup, library detail, each online read, unexpected exit, continuation, Back and stopped application. Each read changed only the artist refresh fields and corresponding persistence bookkeeping. Online re-read → Back retained all 27 typed tables. Candidate user metadata, source associations and order, 679 Tracks / 60 events and all seven decoded Queue JSON values remained intact. Normal shutdown added separately recorded Queue/Session checkpoints and JSON object-key serialization changes; whole-file byte equality is not claimed.

All 32 candidate seed preferences remained equal; four runtime keys were separate. Command-Q stopped the exact continuation process. The owned stream cache created while restoring the paused current recording was inventoried (3,294,170 bytes) and removed with the candidate data/cache. This is not a zero-download run. Exact application registration, bundle, namespace and physical/ByHost preferences were cleared; an empty plist left by defaults deletion was verified and removed. The immutable seed and current Release build were preserved, and keyboard mode remained 0.

The normal application's 45 preferences match both raw bytes and typed values, and installed Info.plist/executable hashes match the fresh baseline and current files. Its 27-table comparison retains 20 tables exactly; the other seven reflect three added listening events (82 → 85), one existing Track's play count/last-played fields, Queue/Session updates and persistence bookkeeping. No old event was changed or removed. Three new history entries precede the retained 19-entry suffix, whose values and order are equal; the 530-item collection's identity/order also remains equal. The saved position changed from 79,381.337868 to 64,224.036281 ms. The new transaction timestamps span 01:11:41–01:21:23 UTC, distinct from the later 97-minute screen-lock gap. Normal-app process records and transaction metadata are supplementary facts; snapshots alone do not establish the input or cause of those writes. These actual later changes are preserved, not restored or described as an unchanged whole store.

The five diagnostic bundles were independently checked against their qualified source, signed executable, Info.plist, UUID and strict signatures, then archived unchanged with verified executable bytes and 0400 archive permissions. Their original app paths, registrations, own preferences, caches/saved state and temporary compiler caches were removed. Sources, inputs, raw build logs, earlier failures and native receipts remain. The original product Release build was preserved. The fresh post-diagnostic normal snapshot matches the post-artist checkpoint in raw SQLite bytes, all 27 typed tables and 64 schema objects; all 45 preferences match in raw bytes and typed values, and installed hashes remain equal. Thus the separate diagnostic audit preserves the already-recorded later normal state, including 85 events.

Private evidence: `~/.muses/tmp/engineering-oct14/artist-catalog-unlocked-oct14/` and the separate `artist-ax-diagnostic-oct14/`. Rendered images and AX observations remain in this execution chat; original crash, normalized cache copies, immutable seed, consistent snapshots, diagnostic source/build logs and independent reviews stay private.

## Remaining scope

XW-100 needs a repeatable trigger in the richer page and causal isolation before a justified remedy. The next control must reproduce its actual preceding lazy content, page position and card structure rather than expand the unrepresentative simple matrix or infer a fix from five successful trials. XW-73 retains genuine separately consented, exact-channel Web Home, other catalog/playback/error states, actual provider continuation coverage, macOS 26 and the complete accessibility/device matrix. This follow-up does not revive retired public Home recommendations or error-Retry obligations.
