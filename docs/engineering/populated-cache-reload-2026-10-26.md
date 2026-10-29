# Populated cache, search and history acceptance — 2026-10-26

This continuation covers previously unaccepted cells reachable through reliable background input. Previously accepted cells and ineffective input routes are not repeated. The original 23 coordinator/matrix issues stay open; XW-74 measurements, Premium and Erato remain paused. No publication is authorized.

## Candidate and input boundaries

The existing isolated Release 0.6.2 build `20261026.2`, frozen source `bebadc3`, was restored from its verified archive. All 623 application entries and strict deep signing verification were checked. Its namespace is `com.muses.acceptance.remaining-20261025`; the production installation, ordinary data/preferences and shared build roots are protected.

The active seed is the prior history pass's original stopped SQLite copy, SHA-256 `c43d5447d640ed919f102ab65c62bfe50eb9d237707aaf93fe316ca3d9d80310`. All 27 typed tables match the donor: 535 tracks, 1,064 imported members, 40 listening events and 534 queue occurrences. The current song is **プリマドンナ**, index 16, paused at approximately 71,000 ms. No business cells were edited. Only system language and floating-point muted volume were seeded in the isolated preference domain; no credentials were copied.

A preliminary zero-event seed was replaced before any launch; its receipt and files remain separately identified. Archive extraction initially changed 38 symlink modes under the private umask. The manifest guard stopped preparation; exact symlink targets/content were verified and their archived modes restored before signature verification and launch. A snapshot label collided with an existing preference seed after its database capture; those original database bytes were renamed to `baseline`, and the preference export completed separately. These are preparation receipts, not product failures.

The absolute-path launch request was rejected before dispatch with `APP_NOT_INSTALLED`. After checking the namespace had no existing registration, the exact task-owned application was registered and launched by bundle identifier as PID 92101 / window 110504, with self-activation suppressed.

## New native acceptance cells

- **Last known nonzero cache summary and retry.** The current paused song genuinely cached a 2,863,114-byte media file alongside the 53,248-byte controlled partial file. Playback Settings displayed 2.9 MB. Making the owned streams directory unreadable (`0100`) and using the actual Clear confirmation retained both files and displayed 2.9 MB, a clear failure, a last-known-size warning and Retry cache size. Restoring `0700` and pressing Retry retained the exact files, removed the read warning and correctly retained the earlier Clear failure. This supplements the previously accepted no-prior-summary branch.
- **Populated local search scope.** The genuine query プリマドンナ produced the existing local song under Library, public grouped results under YouTube, and the same local song after returning to Library, with the query retained. The direct AX menu-item route was rejected outside the target window and was not repeated; the already established popup `set_value` route succeeded. The brief empty state before the search debounce settled is not classified as a defect. No result was played or imported. The query and All source scope were restored.
- **Compact Dark History.** At independently verified 840×804pt with the application's Dark theme, genuine Today/This Week empty ranges displayed horizontal range controls, navigation and PlayerBar without the former vertical-label defect. All Time displayed the actual populated overview and songs on repeat. The 40 retained events precede the current day/week; neither the system clock nor history was fabricated. This adds the previously open compact Dark cell, not broader physical-input, accessibility or OS coverage.

## Confirmed reload defect: XW-130

The subsequent successful native Clear removed the fixture and current media file. Settings briefly displayed Zero KB; the same current media then genuinely downloaded again. Returning to Home showed the same song still paused, now at **0:00 / −2:52**, instead of **1:11 / −1:41**. No Play, Next or seek occurred. Later browsing retained zero after loading completed. This is [XW-130](https://linear.app/xiaotwu/issue/XW-130), under XW-17.

The immediate committed database snapshots before and after Clear, and after browsing, are identical across all 27 tables, including the old 71-second queue/session checkpoint. After normal Quit and confirmed process absence, both persisted positions become `0.9999999999999731` ms, compared with `70999.99999999994` ms before the action. Thus the displayed 0:00 also leads to a persisted near-zero checkpoint; the stopped value is not exactly zero. A transient Zero KB screenshot does not mean the cache remained empty after the current song reloaded.

All 535 Track rows, 1,064 import members and 40 listening events remain typed-value identical through these five checkpoints. Public-search enrichment visible in one frame did not persist any Track metadata change. Changes are limited to QueueState, ListeningSession and three ORM bookkeeping tables; the full audit enumerates them.

`PlaybackService.reloadCurrent()` schedules the same track without carrying its resume checkpoint. The common entry is used by successful cache clear and audio-quality changes. The repair is limited to retaining the current occurrence's checkpoint and playback intent through that load; quality-change runtime evidence must be identified separately.

## Repair and source verification

Frozen source `d7bea1bbb26192db6904c0111bea083a3a1e7dd2`, tracked in [PR #24](https://github.com/xiaotwu/Muses-Polyhymnia/pull/24), passes the existing `checkpointPositionMs` to the same-track load. This retains the unresolved saved offset as well as the loaded engine clock. The existing video retirement/handoff still occurs first, so an unrelated video's position cannot replace the current native track's checkpoint. No queue, persistence schema or history behavior is changed.

Two parameterized tests cover four cases: paused/playing intent at the real PlaybackService–MpvStreamEngine boundary, and repeated pending reloads with statistics enabled/disabled at the session persistence boundary. They verify the second actual seek, its acknowledgement, checkpoint saves, occurrence identity and event counts. The final tests fail on the old production implementation with 21 expected issues; changing only the production implementation passes **28 tests / two suites**. All 489 test inputs match the canonical workspace. Independent review found no blocker.

An earlier draft red run is retained separately. It omitted the simulated acknowledgement of an initial seek, causing extra test-timing failures; those are not classified as additional product bugs. The corrected red and green runs use the same final test inputs. No unrelated full local suite is repeated.

## Repaired native candidate

Release `20261026.3` was built from the exact frozen source in task-private source/build/cache roots. App Intents metadata, packaging, strict deep signing, helper signing and both resolver startup checks passed; all 881 frozen inputs remained unchanged. The earlier failure profile was first archived and verified across all 91 entries, including complete raw SQLite/WAL/SHM and preferences. A new copy of the same unmodified 40-event donor and two-key initial preferences was verified before launch.

PID 98534 / window 110719 first reported an unresolved AX window during startup. One subsequent settled observation bound the exact window and showed paused **1:11 / −1:41**. The window remained off the current desktop space, but background native actions then succeeded. No desktop switching or foreground fallback occurred.

1. The repaired candidate's Clear confirmation named **53 KB**, its controlled partial file. Unlike the original 2.9 MB reproduction, the current media file was not yet in this candidate's stream cache before Clear. The Clear AXPress returned `-25205`, while the same response showed the sheet removed and Zero KB. The fixture was independently absent, and Home showed the same song paused at **1:11**, so the action was not repeated. The actual current media subsequently appeared with its original complete hash; artwork and Home sentinels were unchanged.
2. The actual quality profile changed from selected **Automatic** to selected **Data saver**. After loading, Home retained **1:11** with Play visible. Automatic was then selected again; its successful selected-value check is retained even though the final observation returned an internal tool count mismatch. No selection was repeated. The following Home view retained **1:11**, and exported preferences confirm `muses.yt.quality=bestaudio`.
3. Native Quit was followed by confirmed ESRCH. QueueState and ListeningSession both saved `70999.99999999994` ms. A fresh PID 99944 / window 110762 displayed the same paused **1:11 / −1:41** after cold startup. It also quit normally before the final stopped snapshot.

This is narrow paused-current Clear/quality/cold-recovery evidence. Playing intent and repeated pending reloads are covered by the component tests; live concurrent pre-download, human audibility and the broader playback matrix are not added as native passes.

## Evidence and unfinished work

Private screenshots, exact-window action receipts, full typed SQLite snapshots and preparation failures are retained under `~/.muses/tmp/engineering-oct15/background-populated-cache-oct26-01a17a75`. Before leaving the original candidate, theme, window frame and Home destination were restored. Native Quit was followed by confirmed process absence before the stopped snapshot and source phase. Complete inventories of all five protected roots remain unchanged.

Region-only locale changes, genuine provider failure/Retry, physical keyboard/focus, VoiceOver and other platform/account conditions retain their prior boundaries. A source concern about History clear-error presentation has no reliable runtime failure reproduction and is not recorded as a confirmed defect or patched in this pass.

## Final data audit and recoverable cleanup

The final independent audit binds 192 permanent inputs and reuses the earlier five-snapshot defect audit with all of its supporting hashes checked. Five new SQLite copies were independently opened immutable/read-only and matched every typed value, implicit row ID, schema, column definition and PRAGMA in all 27 tables; integrity is `ok`.

All 535 Track rows, 1,064 import members, 40 listening events and 19 non-state business tables remain exact. The 534 queue occurrences, their complete decoded values/order, current index 16, current Track UUID and session queue snapshot are retained. From repaired baseline to cold stop, 22 tables remain exact. The five changed tables contain state revisions/timestamps/JSON ordering and ORM bookkeeping, including 14 added ACHANGE and ATRANSACTION rows each. The two live positions are `70999.99999999975` ms; fixed/cold stopped values are `70999.99999999994` ms, bit-identical to baseline. No whole-store equality or bit-identical live-position claim is made.

The actual candidate preference changed to `64k` and back to `bestaudio`; fixed and cold stopped dictionaries are semantically equal. Three exact candidate PIDs independently return ESRCH. `final-native-audit.json` SHA-256 is `fcfdf1fb4da9054a788ef98241b96b3fc958cd829821cc6b46932f9bfebff0bb`. The unchanged preparation receipt still says `nativeAccepted:false`; later evidence remains separate.

The final application/profile archives were checked entry by entry before cleanup: 623 application entries (ZIP SHA-256 `3ad8eebd6f6ab85c4d04e9d2e65bb8ab4a6fc8a29713a9ed8cbae31abcf98f7b`) and 60 profile entries (TAR SHA-256 `8ea53f22508663854c0b09db0ba98f24248ad24286b5aafb26f4c63883373e8e`). The exact old/new application registrations were removed, the isolated preference domain was cleared before importing its two-key seed, and key types/values were strictly read back before removing that disposable domain. All 22 fixed application/profile/preference/private-build/cache targets are absent. Frozen source trees/TARs, original raw SQLite families, screenshots, old failure receipts and both original/final profile archives remain available. Complete before/after inventories of the five protected normal app/data/preferences/shared-build roots match. The Cua session is ended and its shared daemon is retained.

Independent closing review confirms the actual 22-path absence, three ESRCH results, zero exact application registrations, strict preference restoration and final empty domain, retained archives/raw/source, all 192 audit input hashes and current five-root preservation. `cleanup-populated-receipt.json` SHA-256 is `4ba2298d5c795c1df39aa8d58abb92184e8bf650506baf78bf9c073dc570e1bc`; `independent-cleanup-review.md` SHA-256 is `ffcd10fd28f4e18faf59db59d9a8d3f96b90893de7518dd9926446c121afeba6`. It does not repeat the completed native or database checks.

## Exact-source CI, integration and Linear

[PR #24](https://github.com/xiaotwu/Muses-Polyhymnia/pull/24) merged as `84d03934d284a272337241aa75a97a10018eaaf7`; its whole Git tree equals frozen source `d7bea1bbb26192db6904c0111bea083a3a1e7dd2`, tree `aa8750262ba8b37bc7dc0de972325872444737ed`. [CI run 40429994034](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40429994034), job `121945049794`, passed all 15 steps on that exact source: 1,118 Swift Testing tests / 151 suites with nine explicit conditional skips, the XCTest test, 15 strict-worker tests / five suites, one independent real disk-failure recovery test, 50 release-configuration checks, App Intents metadata, pinned audio dependencies, signed preview packaging and upload.

The complete 980,929-byte decoded CI log has SHA-256 `3e1a578c642a46fa6a2ac0553e7ecee1c9d1550089fd7672ce2e2eca1a39f024`; `ci-verified-pr24.json` has SHA-256 `accf6bc6915030559c46001355b35cd6ad41410cd6291f53d33efe98b9ce2c86`. No CI rerun or unrelated local full suite was needed. CI, native acceptance and publication remain separate claims.

Twelve related issues (XW-130/17/11/13/10/8/73/19/12/26/27/5) and both Muses project documents were updated and read back. Existing descriptions/content, project assignments and parents remain intact; only XW-130 changes to Done. The scoped inventory has **116 issues: 93 Done, 17 In Review and six In Progress**. Its open identifiers exactly match the original 23. The current reconciliation rows for search, History and cache/reload now distinguish these accepted cells from the remaining conditions rather than repeating obsolete broad unaccepted labels.

Seven engineering records carry the same evidence boundaries. Child main is integrated before the family's gitlink synchronization; only technical documentation and the submodule reference accompany the source repair. No release assets, appcast or public website content are changed. XW-74 measurements, Premium and Erato remain paused, and **no publication** is performed.

## Playing-current follow-up — October 28

The [subsequent native pass](playing-reload-acceptance-2026-10-28.md) adds real playing-current Clear and Automatic→Data saver reload, continued clocks/intent and the resulting pause/Quit/cold checkpoint. It uses the exact same frozen candidate; this later evidence is separate from the paused-only scope above. Concurrent pre-download, other source/quality combinations and audibility remain unaccepted.
