# Disk hygiene and cache budgets — 2026-10-28

After the [playing reload background acceptance](playing-reload-acceptance-2026-10-28.md) closed, the user requested a deep cleanup before opening the foreground-acceptance conversation. They reported a macOS System Data reading near 900 GB and explicitly required ongoing cleanup of failed/superseded builds, temporary verification programs and caches, plus finite application cache limits. Publication, XW-74 measurements, Premium and Erato remain paused.

## Physical storage and ownership inventory

The internal APFS container initially reported 994,610,155,520 bytes capacity, 499,130,769,408 used and 495,479,386,112 unallocated. Data used about 435 GiB with 461 GiB available. No Data snapshots or Time Machine local snapshots were present; the current sealed system snapshot was retained. These measurements do not establish 900 GB of physical System Data.

Docker's `Docker.raw` has a logical length of 994,609,987,584 bytes but only 11,281,997,824 allocated bytes (10.51 GiB). This could contribute to a size-reporting discrepancy, but the System Settings classification has not been traced. Its user containers/images/volumes remain untouched. Android AVDs, SDKs, installed simulator runtimes/devices, Codex runtimes/history, paused worktrees, communication-app data, system VM/diagnostics and active Chrome were retained. Some protected system paths denied inspection; no privilege or permission bypass was attempted.

Muses engineering scratch had accumulated 85.16 GiB by `du`; ordinary application cache was only 56.36 MiB. A failed-build copy alone occupied 37.31 GiB in `remaining-repairs-oct23-01a16186/aborted-shared-build-changes`. Preserving that compiler cache as an evidence copy was excessive; the sibling source, baseline/delta inventories, failure receipts and recovery record suffice. No second archive of that cache was created.

The exact independently reviewed cleanup plan contains 52 non-overlapping targets:

| Targets | Count | Allocated size reported by du |
| --- | ---: | ---: |
| Obsolete private build/test/module caches | 18 | 54.79 GiB |
| Inactive Chrome 154 signing clones | 20 | 28.09 GiB |
| Muses appcast-generator extracted apps | 6 | 1.36 GiB |
| Byte-identical redundant publication downloads | 8 | 1.33 GiB |

APFS clones and hard links mean these accounted allocations are not a promise of exclusive physical recovery. Canonical final ZIP/DMG assets, one verified anonymous download of each, the current acceptance ZIP, raw stores/screenshots/receipts, and paused XW-74 traces remain outside the plan. The source repositories and the new cache-fix worktree are also outside all targets. Completed work was clean and pushed at child `4e28aacbb6749f84c84ee65bd93a72a786259f9c` and parent `3b3e5eaf64aaee8a5a199e75fd582f6df1c156a0` before disposal authorization was exercised.

Private bounded receipts are under `~/.muses/tmp/engineering-oct15/disk-cleanup-oct28-01a17a75`. `cleanup-plan.json` SHA-256 is `69f1e96de147b88fae6fdda1685e2088a4894890c6c3d390b4cd0facaf3fa13b`. The user explicitly authorized permanent disposal of these invalid items conditional on valid changes being committed; the source-preservation receipt states the exact prior-work scope and retains ongoing source outside the target set.

## Execution checkpoints

Fifty generated Sparkle Updater registrations inside the obsolete build roots were unregistered by exact path, with all unrelated prior registrations retained. No global Launch Services reset was used. All 52 targets then passed fresh ownership, canonical-path, same-volume, tree, active-process/open-file and duplicate-content checks and were atomically renamed into one private Trash directory. The active Chrome 156 signing clone remained held by its existing processes and was excluded.

The first permanent-disposal pass removed items 1–19 and stopped on a changed metadata digest at item 20. All remaining targets stayed in Trash; the failure journal is retained. Independent investigation found that five remaining Chrome clones shared the main-executable inode with the removed clone. Unlinking it changed only the surviving hard links' link counts and ctime. Three shared main-executable groups covered exactly 5/10/4 remaining approved aliases, with no alias to active Chrome. Full per-file metadata and executable hashes were bound into a new manual-continuation review. Other files, root identities, node counts and logical/allocated totals remained unchanged.

Three unique old Chrome versions passed non-strict deep code/resource verification. Strict verification failed because the existing clone bundles contain FinderInfo; this failure remains in the evidence. No attributes were removed or signatures repaired, and no old clone was launched. The manually reviewed continuation allowed only the three identified executables' exact link-count/ctime transitions after its own journaled unlink; stable fields, content hashes and every other file remained guarded. This is cleanup artifact identity evidence, not candidate trust or runtime acceptance.

The continuation removed items 20–52. All 52 original and staged targets are absent, all 50 old generated registrations remain absent, and all 52 empty numbered containers plus the private Trash root were removed with empty-directory checks. No unrelated Trash was touched. From immediately before the first permanent disposal to the last one, physical APFS free space increased from **496,387,723,264** to **559,028,940,800 bytes**: **62,641,217,536 bytes / 58.33918 GiB**. Background activity can contribute to this observed delta; it is not presented as 85.6 GiB of exclusive physical recovery.

The original failed disposal evidence and successful manual continuation are both retained. `remaining33-disposal-receipt.json` SHA-256 is `8cbdd9fdeec91bbf9922177fefe0f4ad6703a596511e1d8c6eea5b55066db442`. `cleanup52-owner-closure.json` binds the plan, approval/source-preservation condition, prior failure, exact unregister receipt and final completion.

Independent closing review `cleanup52-independent-closure.json`, SHA-256 `15653d2989284784691cd90f68cb8f0c67e63cf0beffc313b7aae693e157f2bf`, confirms all targets and stale generated registrations absent, normal Muses registration/active Chrome retained, canonical downloads/current candidate ZIP/135 native support inputs rechecked, and all five protected roots equal to the native baseline. The three paused traces remain; only existence, ownership and current size were checked, without a new profiling run or an unsupported unchanged-byte claim.

The three newly generated cleanup helpers and one full metadata snapshot were recoverably compacted after review: 11,851,879 original bytes became one 572,147-byte source/evidence archive, SHA-256 `e1d8315466da81819e5e2fdb75eb7cbddfe5947b6f6981d0436af92e8eb91e39`. Every member's byte hash/mode/size was verified before removing its loose duplicate; `helper-compaction-receipt.json` records the mapping. None of the 135 existing native support paths was compacted or removed. Large compiler caches were not archived.

During read-only system inventory, `xcrun simctl list runtimes` unexpectedly auto-initialized/refreshed the CoreSimulator toolchain and printed an install-success message. No install, boot or delete was requested; further simctl calls were stopped. The operation therefore is not described as entirely free of side effects. Two root-owned Zoom updater LaunchAgents refer to a missing application; their exact system paths remain administrator-only follow-up items, without a global background-item/TCC/network reset.

## Additional recoverable duplicates

The user separately approved a second exact plan of **17** targets: 12 expanded apps whose complete primary files/modes/kinds/symlinks match retained ZIPs, and five feed DMGs matching retained canonical DMGs by SHA and mode. Their accounted allocation was 4,298,350,592 bytes (4.00315 GiB). Seven nonmatching apps were excluded, including two acceptance apps whose CodeResources differed from their ZIPs; they were not silently treated as duplicates. AppleDouble sidecars remain in the canonical ZIPs and were checked for their magic and corresponding primary nodes; no independent extended-attribute equality was claimed.

`second-cleanup-plan.json` SHA-256 is `a243e426bd1db211124d442274af98542d8198b1542f3ac73baa193d60bdca8e`. New exact-path unregister removed only the 12 old target app registrations, preserving normal Muses and all unrelated prior registrations. All 17 targets were fully checked before staging, all staged copies verified before disposal, and every regular file was required to have one hard link. Source commits on main and the new `codex/media-cache-budget` branch were checked against their actual remote refs. No new archive of an expanded app was made.

Both original and staged paths and the emptied private Trash root are absent. Physical free space during this second disposal increased from **557,611,732,992** to **560,449,130,496 bytes**, a measured **2,837,397,504 bytes / 2.64253 GiB**. Together, the two disposal intervals report **65,478,615,040 bytes / 60.98171 GiB** of observed free-space increase, with the same background-activity qualification. The count is **69 approved targets and 62 old generated registrations**, not a claim that all macOS storage or every ambiguous historical artifact was erased.

`second17-cleanup-receipt.json` SHA-256 is `d2972eafedd2b502a00e8ca26f2fe656b31cab7a82ff1eef8b16c6691c065e81`. Independent closure `second17-independent-closure.json`, SHA-256 `39eb152ae51e350911b9ba9cb90ba391a3fccca9bd2cf9e4dbf43de5f4006f45`, confirms all 69 targets/62 old registrations absent, normal Muses registered, all 12 receipt-bound canonical files plus two other retained acceptance ZIPs and nine archive proofs hash-verified, and all 135 current native support inputs retained and disjoint. The first pass's five-root audit is retained alongside the second pass's disjoint paths and one-link invariant; no database, trace profiling or native acceptance was repeated.

## Confirmed application gaps and bounded repair

[XW-131](https://linear.app/xiaotwu/issue/XW-131) records ordinary paused-media caching bypassing the optional pre-download budget. The 512 MiB file limit did not limit aggregate media bytes. A shared total budget must cover both writers, in-flight transfers and safe retirement while preserving active playback and cache cancellation/publication identity.

[XW-132](https://linear.app/xiaotwu/issue/XW-132) records unbounded SWR search/Home metadata and catalog limits applying only per locale. The unused artwork warm writes also have no byte limit; existing artwork must not be assumed rebuildable merely from its directory name. HTTP disk cache is already bounded to 64 MiB and the lyrics cache to 100 files below 2 MB each. WaveformCache has no production callers; update archives require transaction/installer ownership and are not indiscriminately purged.

Both repairs are implemented in an isolated worktree. The single scratch build is capped at 8 GiB and must stop if available space drops below 100 GiB. No shared canonical build root is used. Source, controlled component tests, native acceptance and human audibility remain separate evidence levels. Full exact-commit CI, integration and foreground acceptance are still separate gates.

The implemented policy under verification is:

| Cache family | Budget and behavior |
| --- | --- |
| Ordinary paused-media downloads and optional pre-downloads | One shared 1/2/5/10 GiB preference, default 2 GiB; whole-representation reservations, allocated-block accounting, active-file leases and safe eligible-file retirement. Prediction downloads refuse admission instead of evicting played media. Lowering the budget cannot destroy an active decoder's pinned file; new writes refuse admission until room exists. |
| Search metadata | 64 MiB / 256 family entries, with bounded single documents. |
| Home metadata | 128 MiB / 512 family entries across account/language/region partitions, retaining the currently validated account fallback and the seven-day trust boundary. |
| Public catalog metadata | 200 MiB / 100 family entries across locales, preserving provider timestamps and successful network results when cache admission fails. |
| Import artwork | Remove the two unused duplicate downloads/hash-file warm writes; preserve remote artwork URLs and all existing artwork files. |

Metadata accounting includes unknown entries, old staging and directory overhead while refusing to delete them. Only recognized owned JSON is evictable; cross-instance publication tickets prevent clear/invalidate resurrection. The dormant WaveformCache and retired nonproduction playback engine are not represented as new production growth paths. Deno/yt-dlp tool caches and transaction-owned update material have their own lifecycles; this change is not a unified hard cap on the entire `~/.muses` tree or an APFS-exclusive-size guarantee.

## Focused source verification

One root-owned SwiftPM runner used only `source-build` and `package-cache` inside the maintenance directory, four build jobs and explicit module-cache paths. The first compile caught two missing Darwin-time integer conversions; those were corrected before any tests ran. The next invocation executed 103 tests across 11 relevant suites. All media, resource, clear/loading, metadata capacity, Home trust/privacy, catalog and existing import cases passed except two parameter instances of the new artwork-warm-write test.

The failed test initially used an empty-host response rule and observed the ordinary fallback `hqdefault.jpg`, not its intended successful oEmbed fixture. Retaining the read ModelContext did not resolve it and is not claimed as the cause. The corrected fixture explicitly intercepts the oEmbed host/path and image host and requires a real intercepted oEmbed request, while retaining the exact `cover.jpg` expectation and existing-cover byte preservation. Only that affected test was rerun; both parameter instances passed. The 101 previously passing tests were not repeated locally. The only later product-source change was removing an incorrect directional word from Settings help; the final targeted invocation compiled it as well.

All four source/test fingerprints remained stable during their respective invocations. Peak measured task allocation was **1.12449 GiB**, below the 8 GiB cap, with no budget stop. The complete logs and bounded receipts `focused-cache-tests-01` through `04` retain failed and successful observations. Independent cross-review covered descriptor ownership, decoder leases, cancellation gates, allocation accounting, root/partition identity, cross-instance invalidation and validated Home fallback protection. No GUI app, audio output, normal library, shared build root or published artifact was used for this verification.

The validated functional source is committed and backed up as `f9d80a91d1ec48f0fb78a7f6a3e4b1f024f76133`. Full exact-source CI and integration are tracked by its repair PR and Linear XW-131/132; subsequent record-only commits must preserve that product-source identity. The original 23 coordinator/matrix issues, XW-74 measurement skip and Premium/Erato pauses remain separate. A new foreground conversation follows only after this cleanup, validation and synchronization closeout; no publication is authorized.
