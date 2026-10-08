# Source integration cache regression

2026-10-08 follow-up to XW-73, tracked as XW-78. This supplements [source-state acceptance](source-state-acceptance.md); its completed native observations and external conditions remain unchanged. No application/GUI session was started and no runtime lock was acquired. Work used only the sources-owned workspace mutex after the performance preflight released both locks.

## Failure and attribution

[Full CI 37849908816](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/37849908816), on `ee011df`, failed 881 tests / 119 suites with five assertions:

- `HomeDiscoveryTrustTests.anonymousFailurePreservesSnapshot`: the reopened cache lacked the expected expired snapshot, producing the cold failure section instead of the saved section, cached source, stale state and update timestamp.
- `PerfCacheTests.swrInvalidate`: a cached value was readable after invalidation.

Ten local repetitions of those two original tests passed. That result did not resolve the CI failure: both tests depend on detached writer scheduling, so controlled ordering was required.

The cold Home fixture was introduced in `0280290` and immediately reopened a separate cache after an asynchronous `set`. It never established that its disk seed had completed before calling `load`. The generic writer's last lifecycle change was `0a72b83`; XW-29 fixed pending-value retention and explicitly left detached disk-write ordering unchanged. Invalidation and clear removed memory/pending values and files, while an already dispatched writer could subsequently publish its obsolete envelope. A slow earlier write could likewise overwrite a newer persisted value. These implementation gaps predate `a325a36` and `e74a638`; their appearance in that later CI is not evidence those source fixes introduced them. The precise historical scheduler timing remains unmeasured.

## Controlled reproduction and narrow repair

A synthetic Codable value blocks its old encoder on a condition gate. Tests wait for that exact state, then invalidate, clear, or persist a replacement before releasing the old writer. On the original publication path, all three cases failed with five assertions: invalidation/clear resurrected the old value in both current and cold readers, and replacement reverted to the old value on disk. The fixture never uses a live provider, browser cookie or fabricated native source state.

SWRCache now assigns a current write ticket before dispatch. Encoding and bulk staging remain detached. A per-instance lock protects only ticket state and publication/deletion; same-directory atomic rename publishes an envelope only while its ticket remains current. Invalidate/clear revoke tickets and retain their existing synchronous deletion behavior. New writes replace the prior ticket. Staged files are removed on completion, including revoked writes, and pending value/task bookkeeping is retired by identity. JSON envelopes, hashed filenames, cache partitions and synchronous memory semantics are unchanged. This is an ordering repair, not a claimed scrolling or energy optimization; it does not introduce cross-process cache locking.

An asynchronous `flushPendingWrites` boundary awaits all writes already dispatched at the call, including revoked tasks. HomeFeedCache forwards that boundary across its opened partitions. The cold Home fixture awaits persistence and requires its seed from a separate reader before testing the offline/stale recovery behavior. The existing generic cold-cache test also uses completion rather than main-thread polling. The boundary confirms task completion, not successful storage under arbitrary I/O failures; the cold-reader requirement reports a failed seed directly.

## Verification and preservation

Local toolchain: Apple Swift 6.4 on arm64 macOS 27.0.1. Verification for the final implementation:

| Check | Result |
| --- | --- |
| Delayed write regression before repair | All three cases failed, five assertions, 0.055s. |
| Home trust and performance caches | 34 tests / 2 suites passed, 0.933s. |
| Original cold Home plus complete performance cache suite | Ten consecutive 15-test runs passed, 0.143–0.156s each; each included all three delayed-write cases. |
| Complete integration suite | 882 tests / 119 suites passed, 30.769s. |
| Release build | Passed, 75.95s. |
| Release configuration checks | Eight Python tests passed. |
| Whitespace and patch validation | `git diff --check` passed. |

The push runs the existing macOS 26 workflow, including full tests, App Intents metadata and preview packaging. Its exact pushed commit/run and terminal outcome are recorded in XW-78 and private CI metadata; local testing is not substituted for the remote result. No installed application or local normal bundle was repackaged.

Private evidence is under `~/.muses/acceptance/com.muses.acceptance.sources-xw73-oct08/evidence/ci-regression/`: original CI reference, ten baseline logs, controlled failure log, focused/repeated/full/build/configuration logs, preservation checks and exact cleanup manifests. The original source acceptance remains a separate record.

Before/after temporary-directory inventory, test-source prefix/UUID provenance, exact paths, UID and content hashes identified 221 task-created fixture paths. All were removed after test processes ended; this includes six fake yt-dlp directories and one hash-verified synthetic cookie fixture. Preexisting temporary paths and unrelated applications were preserved. The donor SQLite/WAL/SHM hashes, complete donor and sources acceptance preference dictionaries, and normal app Info.plist/executable hashes matched the earlier baselines. No browser credentials, production library, permissions, output settings, remote playlist writes or native acceptance preferences were changed. The current shared Debug/Release products and private evidence remain available.

The separate `ci-regression-complete` status/marker follows remote CI confirmation and release of this workspace lock. It permits performance preparation to resume against the repaired source, without closing XW-73's remaining account/native matrix or any parent gate.
