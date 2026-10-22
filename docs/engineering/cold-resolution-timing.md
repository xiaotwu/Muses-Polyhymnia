# Cold public resolution: numeric stage timing

2026-10-21. Tracking: [XW-107](https://linear.app/xiaotwu/issue/XW-107/muses-resolve-remaining-cold-public-playback-timeouts-in-pr-17), [Draft PR #17](https://github.com/xiaotwu/Muses-Polyhymnia/pull/17).

## Change and regression

The runner now records request/slot wait, launch, first stdout/stderr bytes, process exit, pipe EOF byte counts, return, cancellation and timeout. One trace continues through typed JSON parsing. Records contain a random numeric request token, fixed stage number, monotonic elapsed time and a numeric value; never arguments, media IDs, URLs, headers or payloads.

A controlled child wrote five stdout bytes and ten stderr bytes, then slept. Foundation `read(upToCount: 65536)` delivered both first-byte observations at child exit, about 0.712 seconds. POSIX `read` on the same non-cooperative pipe-drain queues delivered them around 0.0035 seconds, before the child exited around 0.715 seconds. A live-child regression now requires both first-byte events before exit, then cancels the child and verifies completion. This corrects diagnostic timing; it does **not** prove faster extraction or explain the prior 20-second failures.

Public typed extraction additionally uses the bundled tool's `--verbose` stderr diagnostics. Only fixed phrases become numeric webpage/API/player-script/JS-challenge/format-check/error events. The classifier has a bounded 512-character in-memory overlap and clears it at EOF. Stdout remains JSON; raw stderr is not logged or persisted. Configured-account extraction does not enable these verbose phases. `--no-quiet` was rejected during control preparation because it polluted stdout with progress; that failed diagnostic setup is retained separately from playback results. See the [upstream CLI reference](https://github.com/yt-dlp/yt-dlp#verbosity-and-simulation-options).

The 20-second deadline, access/quality policy, selector, checked-format requirement, retries, scheduler and queue/transport authority remain unchanged.

## Actual observations

The fixed public recording was `HsuGYhLsKyo`, the retained sample from the prior gate. All probes used the same packaged yt-dlp/Deno binaries, no cookies, Best audio and a cold completed-media/typed-stream cache. Public extractor/runtime disk caches were retained. Normal launch background metadata work was allowed in the application. Independent controls ran after the application stopped; metadata load and OS scheduling therefore remain differing conditions.

| Scope | Observed seconds | Result |
| --- | --- | --- |
| Actual runner, initial numeric trace | 7.326 / 8.064 / 8.214 | Three Opus251 resolutions |
| Signed app, initial numeric trace | 10.496 / 11.760 | Typed parsing completed; paused restored recording loaded |
| Signed app, initial numeric trace, third launch | 20.088 | Timeout; process started at 0.0014s, no pipe bytes, terminated with status15 |
| Interleaved actual runner | 8.358 | Opus251 resolution |
| Signed app, detailed phases | 17.593 / 11.311 / 19.796 | Typed parsing completed; the last actual media load took about22.884s |
| Interleaved detailed actual runner | 8.072 | Opus251 resolution |

In the timed-out application request, slot acquisition took 0.00048s and launch returned at 0.00144s. There was no successful JSON to parse. Both pipes reached EOF immediately after the timeout terminated the child. That sample excludes slot wait, delayed launch, typed decoding and post-exit pipe drain as the dominant delay; it locates the unresolved wait inside the launched subprocess.

Detailed successful application trials took 8.836 / 3.848 / 9.755 seconds to produce their first stderr bytes, and 9.033 / 4.057 / 9.964 seconds to reach the extractor-start phrase. The interleaved runner produced its first stderr at0.321s and reached extraction at0.490s. Application typed parsing itself took approximately0.00035s. There is therefore a substantial measured pre-extractor delay in these app samples, alongside the later network/JS/format-check costs. A background/QoS/App Nap, filesystem, code-validation or network cause is **not** established by these observations.

The candidates were muted through their own preference domains and normally quit between samples. Paused restoration/media initialization does not add a new audible-playback claim. Older human-audible evidence remains bounded to its original candidate.

Both stopped candidate stores contain535 Tracks and19 listening events. The formal application, normal raw store/preferences and the repository's canonical `.build`/`build` inventories match this session's baseline. Copied SwiftPM build state initially removed files from the older private staging tree;315 original build files and27 relative framework links were restored from matching cloned bytes/targets. Two rebuildable SwiftPM manifest-cache files remain absent, explicitly recorded in the private guard delta; the older private tree is not claimed wholly byte-identical. No original signed candidate or evidence file changed.

## Verification and remaining gate

Final private-home regression: **1,077 tests / 146 suites passed**. Strict single-cooperative-worker progress/output/timing scope: **7 tests / 3 suites passed**. Debug application build and hardened ad-hoc signature verification passed. The strict CI filter now includes output bounds and the timing regressions. Early compiler failures and the rejected no-quiet control remain in private evidence; neither is a native playback outcome.

Private evidence: `~/.muses/tmp/engineering-oct15/cold-resolution-oct21-01a16186`. Exact measured executable hashes are in the candidate receipts; the detailed candidate has a compiled-source hash map. Bundle source-revision metadata inherited from the prior packaging template is not used as source provenance. The initial numeric-only candidate predates the verbose-phase change; its earlier measurements are not represented as results from the final phase-enabled source.

Next, capture a failing **detailed-phase** application request and a bounded child startup stack before the first stderr event. Compare serial versus ordinary background metadata concurrency, then test any scheduling/activity change as an explicit controlled comparison. Keep all failures, identical deadlines and fixed inputs. Do not patch QoS/activity assertions, lengthen deadlines or add blind retries on these timing differences alone.

XW-107 stays In Progress. PR #17 stays Draft and 0.6.2 remains held. Reliable cold playback and final Developer ID/notarized-package acceptance are still open; Premium is deferred and XW-74 remains paused.
