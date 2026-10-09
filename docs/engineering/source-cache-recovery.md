# Web cache recovery after privacy deletion

2026-10-08 continuation of XW-73, tracked as XW-81. This is a source/cache follow-up to [the earlier CI repair](source-ci-regression.md), not an extension of [Personalized Home native acceptance](source-state-acceptance.md). No GUI, OAuth, browser cookies or helper fetch was used.

## Confirmed failure

Baseline `7347ac5` was clean and pushed. `HomeDiscoveryService.clearSavedWebHomeForCurrentAccount` invalidates the active account's normalized Web layer, removes its displayed sections and reloads. `HomeFeedCache.invalidate` correctly clears opened partitions and removes the exact mode/account/layer subtree across dormant locales and pre-locale layout. That privacy deletion is intentional and must remain.

Opened SWR objects nevertheless stayed in the partition dictionary. Their directories had been deleted after `clearAll` recreated them. A subsequent same-instance `set` retained the new value in memory and returned accepted, but asynchronous staging could not write into the missing directory. A separate cold cache restored no new snapshot. This is a handle/directory lifetime defect; XW-78's obsolete-writer publication repair remains valid. The locale subtree deletion dates to `8118a19` and was not introduced by this follow-up.

The controlled regression seeds schema-valid, channel-matched normalized account-Web snapshots in English/US and Traditional Chinese/TW, then awaits persistence. A separate clearing cache opens either English alone or both locales. Exact deletion removes both locale directories and a normalized legacy-layout file. Fresh saves and completion precede the cold reader, so no early cold lookup can accidentally recreate a missing target directory and hide the defect.

Before repair, both cases failed with three cold-read assertions in 0.013s: English failed in both; Traditional failed only when it had also been opened. Fresh in-memory reads and the dormant-only restoration passed. Current-account baselines in both locales, guest baseline, another recommendation mode and another account's Web snapshot remained readable. These are synthetic typed cache fixtures, not authenticated provider or native Personalized Home evidence.

## Narrow repair and verification

Each matched partition is now removed from the registry **after** `clearAll` revokes its outstanding writes and clears memory. Future access uses the existing lazy initializer to recreate a writable directory. The exact privacy deletion, JSON format, namespace rules, SWR ticket checks and provider/auth boundaries remain in use. No synchronous bulk write or new disk coordinator was added. The flush documentation now states its existing current-partition boundary explicitly.

Under the sources-cache-followup workspace lock:

- InnertubeHomeTests, HomeDiscoveryTrustTests and PerfCacheTests: 45 tests / 3 suites passed in 0.976s.
- The new two-case recovery test plus the existing three delayed invalidate/clear/replacement cases passed five consecutive runs, 0.065–0.083s each. Old ticket revocation is retained before handle retirement.
- `git diff --check` passed. Latest baseline full CI was already successful; no full local matrix or GUI session was repeated. The repair push receives the complete macOS CI, including full tests, metadata and preview packaging. Its exact commit/run and terminal result are recorded in XW-81 and private handoff metadata.

Private evidence: `~/.muses/tmp/engineering-oct08/round-2/evidence/sources-cache-followup/`, including review, before/after/repeated logs, preservation snapshots and exact cleanup manifests. Twenty-five attributed fixture directories were removed after test-process, UUID/prefix, UID, path and content-hash checks. The regression's own recovery roots also remove themselves after their completed writes. Preexisting temporary paths and current shared build products were preserved.

The existing donor SQLite/WAL/SHM hashes, its complete preference dictionary and normal app Info.plist/executable hashes matched the pre-session values. No production library or preferences were edited. Only the owned workspace lock was acquired; other round-2 status/completion files and the native runtime order were left alone. The sources-cache-followup completion marker is a source handoff after CI/cleanup, not a Personalized Home native pass or a parent-gate closure.
