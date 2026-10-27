# Background cache-clear failure and remaining display cells — 2026-10-26

This pass continues only reliable background acceptance. Previously accepted cells are reused, and previously ineffective input routes are not repeated. No publication is authorized; XW-74's skipped measurements, Premium and Erato pauses remain in force.

## Confirmed defect: XW-129

The original isolated Release 0.6.2 build `20261026.1` was restored from its existing archive. All 623 application entries, archive SHA-256 `d2525032e2c30bad9a525d7b133c7b964b19954b5701513da13d046ffb38461f`, strict deep signing verification and product-source equivalence to `a8e95c5` were checked. The namespace was `com.muses.acceptance.remaining-20261025`, with a newly created empty store and only muted volume/system language preferences. No production data or credentials were copied.

A controlled nonmedia partial file of 53,248 bytes was placed in the disposable stream-cache directory. Settings → Playback showed **53 KB** and its native Clear confirmation named the same amount. With that owned directory changed to mode `0500`, pressing the confirmation's actual Clear button changed the interface to **Zero KB**, although the file remained unchanged (SHA-256 `2e8c4f9aa450b1a0e52a8ca0488e027dca99aea009f29b6a0d60139b5ce797c9`). No error appeared. Playback was empty and idle pre-download was off.

`MediaFileCache.clearAll` suppressed removal/recreation errors, and Settings unconditionally cleared its displayed summary and reloaded playback. [XW-129](https://linear.app/xiaotwu/issue/XW-129) tracks the narrow repair under XW-17. The separate concurrent playback/pre-download lifecycle is not accepted by this fixture.

Two preparation errors are preserved in the receipts: an incorrect expected fixture size stopped before changing permissions, then an unsupported observation field caused a batch to execute zero steps. Both were corrected before the one real Clear confirmation. Neither is counted as a product failure or a repeated native deletion.

## Repair and source verification

Frozen source `bebadc3a6e7d539ce118bdf99e0738934aa7f679`, tracked in [PR #23](https://github.com/xiaotwu/Muses-Polyhymnia/pull/23), propagates deletion/recreation errors. Settings shows localized retry guidance, reloads the current track only on success and reads the actual cache summary after either outcome. A failed count retains the last valid size with an explicit warning; without a prior result it shows unavailable, not zero. Retry cache size remains separate from the destructive Clear confirmation.

Five new filesystem tests cover complete/partial deletion and private `0700` recreation, real `0500` failure and recovery, `0100` count failure and recovery, unsafe symlink roots and external entries. Those tests plus existing typed media-cache regressions passed **22 tests / two suites** in a task-private source/build/cache/home snapshot. All 881 frozen source inputs remained unchanged. An independent read-only review found no blocking issue. This is source evidence; the repaired candidate's actual native observations are separately identified below.

## Repaired native candidate

Release 0.6.2 build `20261026.2` was built from that exact frozen source, with private compiler/package caches and test home. App Intents metadata, packaging, strict deep ad-hoc signature checks, helper signature and both bundled resolver startup checks passed. No release feed, OAuth configuration or URL registration authority was added.

PID `86198` / window `110399` exercised the real Settings actions at 1280×804pt:

1. The same `0500` stream-cache fixture displayed **53 KB**. Native Clear confirmation now left **53 KB** visible with **Could not clear the media cache…try Clear again**. The 53,248-byte file's complete hash remained unchanged.
2. Restoring the owned directory to `0700`, then using the same native Clear/confirmation path, removed the file. The directory was genuinely empty and private `0700`; **Zero KB** appeared and the error disappeared. Artwork and saved-Home sentinel files retained their exact sizes and hashes.
3. Setting the now-empty owned directory to `0100` and reopening Playback from General produced **Unavailable**, a read-error explanation and **Retry cache size**. Restoring `0700` and pressing that button returned **Zero KB** with no read error. This proves the no-prior-summary failure/retry branch; it does not claim native coverage of a previously loaded nonzero summary becoming unreadable.

The empty-phase initial, original stopped and repaired stopped stores are exactly equal across schema, PRAGMA and all 27 typed tables. User-content tables remain empty; the three system metadata tables retain their existing rows. These idle/no-track fixtures do not accept live quality reload, playing-track reload, concurrent pre-download, other languages or physical/VoiceOver focus.

The first repaired launch was rejected before dispatch because its Cua lifecycle session had ended. Its empty stdout and explicit stderr are retained. After reviving that same background-only session, the effective launch reported PID `86198` and `self_activation_suppressed:true`; this was a tool-session recovery, not a product failure.

## Controlled nonempty year/genre rendering

After the cache candidate exited, its complete empty profile was archived and all 17 entries verified. A separate stopped acceptance store from the prior history/group pass was copied, with source SHA-256 `bc2fff306869eec4cbe69954165b53d55e13f22421685f3389e453cf55eb976c`.

Only two previously null fields were changed in the disposable copy: Track `DF1F3CE5-9439-4B08-BDEB-4450678EBC1C` / video `jLVrsY8Ch6s` / **Stay — Yves V - Topic**, `year=2026`, `genre=Fixture Genre`. Its only import membership is the existing `test` item `A0354C4E-89CE-448D-B8E9-D482376C16CB`; it has no Liked or ordinary PlaylistItem relationship. A complete typed comparison confirmed exactly those two cells differ, with all identities, version fields and relationships retained.

The same repaired build relaunched as PID `86864` / window `110419`. Songs → Show complete song list succeeded. A bounded AX scroller query timed out and was not repeated. Screenshot-grounded background wheel navigation visibly moved through rows 101, 201, 271, 291 and 301; the final frame shows row **304 Stay**, artist **Yves V - Topic**, **2026** in Year and **Fixture Genre** in Genre, with neighboring empty fields still shown as dashes. Both columns were already visible, so no horizontal or header input was needed.

This accepts actual imported-Songs projection/rendering of explicitly controlled nonempty metadata. It does not accept native metadata Save input, real-source year/genre provenance, sorting or physical keyboard behavior. Prior accepted table expansion and navigation are setup, not newly counted passes.

## Additional original-candidate native evidence

The genuine empty Music Videos page displayed **0 music videos**, **No music videos yet**, and its own **Open Search** button. Pressing that button opened the Search page, with its field, source/category controls and Browse Your Music cards. This adds only the specific empty-state/rendering/routing cell; previously accepted populated Light/Dark cells are not counted again.

The original candidate PID `81755` exited normally through its native Quit menu. Both initial and stopped store snapshots have integrity `ok`; all user-content tables are empty. Source work and native operation use mutually exclusive workspace/runtime locks.

## Evidence and remaining scope

Private screenshots, complete typed SQLite snapshots, Cua responses and preparation receipts are retained under `~/.muses/tmp/engineering-oct15/background-cache-metadata-oct26-01a17a75`.

The independent final audit binds 69 supporting inputs. Nine retained SQLite copies were independently opened immutable/read-only and matched their typed snapshots across all 27 tables, implicit row IDs, column metadata, schema and PRAGMA; integrity is `ok`. In the populated phase, all 535 Track rows, 1,064 import members and 19 non-state business tables remain exact against the controlled fixture. Overall 22 tables remain identical; changes are confined to ACHANGE, ATRANSACTION, Z_PRIMARYKEY, QueueState and ListeningSession.

All 534 queue occurrences, their full decoded values/order, current index 16, current Track UUID and session queue snapshot are retained. Some JSON serialization order changes without decoded-value changes. Queue/session version and save/update timestamps, four new ORM changes/transactions and exact primary-key maxima are enumerated. Position changes from `70999.99999999994` to `70999.99999999975` ms, delta `-1.8917489796876907e-10` ms: both round to 71,000 ms, but their IEEE754 bytes differ. No whole-store or bit-identical position claim is made.

The Quit request initially preceded complete process termination. A snapshot taken in that interval retains its live capture kind and original bytes under the explicitly recorded `metadata-quitting` names. A distinct `final-stopped` snapshot follows confirmed process absence; the independent auditor also received ESRCH for PIDs 81755, 86198 and 86864. Candidate preferences changed route/list state and EQ JSON key order; decoded bands remain equal. The five protected normal app/data/preferences/shared-build roots match their full before inventories after native work.

The original 23 coordinator/matrix issues retain their open statuses. Native metadata Save input, table headers/descending, paging toggle, multi-bookmark drafts, genuine provider-only unsynced lyrics, account/provider/device conditions, physical keyboard and accessibility/macOS 26 cells remain separate.

## Exact-source CI and integration

[PR #23](https://github.com/xiaotwu/Muses-Polyhymnia/pull/23) merged as `74c8782c7fd5e05b8e25d19e8cdc8a4b9b2a4681`. Its complete Git tree equals the frozen source's tree `b423445a11c92f24edba875845f124a4b7e0e17b`. Frozen source `bebadc3a6e7d539ce118bdf99e0738934aa7f679` passed [CI run 40419577786](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40419577786), job `121910355967`, with all 15 steps successful: **1,116 tests / 151 suites**, nine explicit conditional skips, **15 strict-thread tests / five suites**, one independent disk-recovery test, **50 release-configuration checks**, App Intents metadata, pinned audio dependency verification, signed preview packaging and upload. These checks do not publish an application or establish the open native branches.

The complete CI log and verification receipt are retained locally. `ci-verified-pr23.json` SHA-256 is `f9d7be4792d647d25655a821e7cb47b7e389731141ef589ae6af87b8e70cd8e3`; the 979,557-byte log SHA-256 is `53b2f94e29c6ecdda4609540f5aec3508f2bd3b1355ce2ca863c680b259dd30c`. The final native audit SHA-256 is `bc96c9469b2312563c0af7b1907b40a2049f8c32ea1d824398fd98b3e5c59b2c`. The candidate preparation receipt's original `nativeAccepted:false` is retained: subsequent observations are separate evidence, not a rewritten preparation claim.

## Recoverable cleanup and record synchronization

Both applications were unregistered at their exact task-owned paths. The repaired application ZIP was checked against all **623 entries**, SHA-256 `d322edd0bc2526777d114111aef17a3b2437218ebe241e81368cb49c357d9bd6`. The final profile tarball was checked against all **374 entries**, SHA-256 `faa297bd089369fc63be22085c913fee65c6a90e95268f00f2f6809fdd335189`. The original application archive, the 17-entry empty profile, frozen source tree/tar, all screenshots, original SQLite/WAL family, typed analyses and prior receipts remain available.

Cleanup first stopped before any removal on a strict preference check: `defaults import` merged the initial two keys into the existing nine-key domain. The failed readback and original failure receipt remain unchanged. An independently reviewed continuation bound their exact hashes, all 69 audit inputs, complete archives and the original removal list. It deleted only the isolated preference domain, imported the initial `muses.language=system` and floating-point `muses.playback.volume=0.0`, and strictly verified both types and values before preserving that readback. It then removed the isolated domain and original 13 owned application/profile/build/cache directories. An earlier preflight comparison correction and the rejected pre-dispatch launch are also retained; they are not product defects.

`cleanup-cache-receipt.json` records successful completion with **14 paths absent**, source/evidence/raw stores retained, the three PIDs stopped and both exact application registrations absent. SHA-256: `803a565c69d3a7da7303fc1d2620fcfd6f73508ecc07b9bab79cd4d5121f3f2d`. Full before/after inventories of the five protected roots match. The Cua session is ended; its shared daemon is retained. No application is relaunched for cleanup.

An independent closing review confirms actual target absence, ESRCH for all three PIDs, zero exact application-registration matches, strict initial/restored preference types, an empty final domain, and retained archive/raw/source/audit hashes. Its receipt is `independent-cleanup-review.md`, SHA-256 `c94407ac37ec393c417cadea0a31633ea9f040c07bddb7a95e1e10df5d74fda2`. It does not rerun already accepted native cells or duplicate the completed database audit.

Eight related Linear issues (XW-129/17/11/9/19/12/27/5) and both Muses project documents were updated and read back. Previous descriptions, project assignments and parents remain intact; only XW-129 changes to Done. The scoped project inventory is **115 issues: 92 Done, 17 In Review and six In Progress**, preserving the original 23 open coordinators/matrices. The engineering status, reconciliation, ledger and remaining-work entry points carry these same limits. Source and record commits are synchronized through child main before the family submodule reference. No release assets, appcast or public website content are changed; XW-74/Premium/Erato pauses and **no publication** remain in force.
