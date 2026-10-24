# Queued prepared Next priority

October 23, 2026 · [XW-121](https://linear.app/xiaotwu/issue/XW-121)

PR #19 was independently re-reviewed and merged as `34fa44c`. Exact-head CI 40039614760, merge CI 40041957655 and frozen release-source `73f1dbe` CI 40042082311 all passed. The new [0.6.2 / 20261023.4 candidate](release-candidate-pr19-2026-10-23.md) includes this repair and has new package, numeric native and data-preservation evidence; the user confirmed continuous normal music for this exact build and it is now published as stable [v0.6.2](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.2). This does not transfer old candidate acceptance or claim saturated background slots were observed natively. The following investigation and submission sections retain their original evidence scope.

This follow-up is separate from the completed [0.6.2 / 20261023.3 candidate](release-candidate-2026-10-23.md). Its source finding does not establish the cause of historical native cold-resolution timeouts, and its changes are not present in that frozen candidate.

## Confirmed behavior

A controlled integration on merged source `02ebc7d` executes the real `PlaybackService`, `MpvStreamEngine`, `StreamResolutionCoordinator`, `YTDlpBridge`, parser and `YTDlpRunner`. Only the local extractor and `MpvClient` output are fixtures; the check makes no media or account request and produces no native audio.

Two local processes hold the runner's two background slots. Track A loads through its foreground slot, and automatic preparation of B queues in the background lane. The real `playback.next()` transfers B's unfinished preparation, but B stays queued. An independent interactive request on the same runner completes while both blockers remain held. After background release, B loads once.

The final old-code run fails only the expectation that selected B should start before background release: waiting count 1, active count 2, B still buffering, interactive probe successful, B process starts 1. The final test took 0.442 seconds. Two earlier fixture preparation/assertion corrections are retained separately and are not additional product failures.

`YTDlpRunner.run` captures its lane before acquiring a slot. Awaiting a preparation created under a background TaskLocal does not change that task's existing queued waiter. The foreground capacity is available but the transferred job cannot use it.

## Repair boundaries

Promote the same queued operation when foreground playback claims it. Keep its existing deadline, request identity, coalesced consumers and cancellation ownership. An extraction that already acquired a slot continues in that slot without restart. Unselected background prefetch retains its existing capacity limit.

The promotion signal must survive a claim before the preparation task registers its coordinator request. It must bind to that operation and consumer lifetime, so an old signal cannot promote a later request with the same media identity. Slot accounting must use the lane actually granted, and completion, timeout and cancellation must remove their observation registrations.

The repair creates a sticky caller handle before the engine starts its preparation task. Handoff promotes that handle. The coordinator forwards each consumer's signal to the handle of its existing request, and passes only that request handle through the bridge to the runner. A coalesced foreground consumer also promotes the existing request. Callbacks target request objects rather than future media-key lookups and are removed when their consumer or queued acquisition finishes.

The runner changes a still-queued waiter's lane on its actor. It grants the reserved foreground slot when available, or waits for that lane to be released. Acquisition returns the actual granted lane for accounting. The original elapsed-time budget and queue timeout remain in place; a process that has already acquired a slot has no queue observer and continues unchanged.

## Verification

- Focused regressions: 35 reported tests in five suites passed. The portable production integration covers both an already-queued preparation and a foreground claim before coordinator registration.
- Full private regression: 1,092 reported tests in 148 suites passed in 31.502 seconds.
- Strict single-cooperative-worker checks: 15 reported tests in five suites passed in 1.730 seconds, including both new suites. CI now retains those suites in its existing strict-worker step.
- All 50 release configuration checks passed.
- Meaningful boundary checks include sticky promotion before acquisition, already-running single execution, occupied-foreground successful grant, cancellation/grant races, the original queued deadline, callback lifetime, coalesced foreground consumers and stale-context/invalidation isolation. The occupied-foreground check first frees background capacity and runs an actual background probe; selected B still waits until foreground capacity is released, then starts once and returns all counters to zero.
- Independent source/test review found no blocking issue. The six tested source/test files match the frozen SHA-256 receipt. Extractor fixtures use `/bin/sh`, temporary roots and bounded waits, without media network access.

These are source and controlled-process checks. They do not add native-audio or human-listening evidence for this new change. Exact submitted-head CI is tracked on the follow-up pull request.

## Evidence

Private raw investigation and fixture failures are retained under `~/.muses/tmp/engineering-oct15/pr18-integration-rc-oct23-01a16186/queued-priority-investigation/`, including `INVESTIGATION.md`, `queued-next-observation.json`, `red-test-final.log`, `tested-files.json`, `green-focused-final.log` and the three `root-*.log` validation logs. Every build ran from the asserted private source directory with private scratch, cache, configuration, security, module-cache, temporary and test-home roots.

The signed RC, its ZIP/DMG and offline feed remain frozen. No release, tag, asset, production feed, Pages deployment, formal application replacement or account operation is part of this follow-up. Other native, device, platform, accessibility and account acceptance conditions remain separately open.
