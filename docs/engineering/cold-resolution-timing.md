# Cold public resolution: startup timing and runtime packaging

2026-10-21. Tracking: [XW-107](https://linear.app/xiaotwu/issue/XW-107/muses-resolve-remaining-cold-public-playback-timeouts-in-pr-17), [Draft PR #17](https://github.com/xiaotwu/Muses-Polyhymnia/pull/17).

## Current result — 2026-10-22

The avoidable pre-extractor stall is repaired by replacing the same-version PyInstaller one-file resolver with the official pinned onedir runtime. A new signed candidate completed all nine fixed cold resolutions under the unchanged20s deadline. This accepts the bounded cold-source correction; PR17 remains Draft while integration review and final Developer ID/notarized-package gates are outstanding.

## Earlier diagnostic change and regression

The runner now records request/slot wait, launch, first stdout/stderr bytes, process exit, pipe EOF byte counts, return, cancellation and timeout. One trace continues through typed JSON parsing. Records contain a random numeric request token, fixed stage number, monotonic elapsed time and a numeric value; never arguments, media IDs, URLs, headers or payloads.

A controlled child wrote five stdout bytes and ten stderr bytes, then slept. Foundation `read(upToCount: 65536)` delivered both first-byte observations at child exit, about 0.712 seconds. POSIX `read` on the same non-cooperative pipe-drain queues delivered them around 0.0035 seconds, before the child exited around 0.715 seconds. A live-child regression now requires both first-byte events before exit, then cancels the child and verifies completion. This corrects diagnostic timing; it does **not** prove faster extraction or explain the prior 20-second failures.

Public typed extraction additionally uses the bundled tool's `--verbose` stderr diagnostics. Only fixed phrases become numeric webpage/API/player-script/JS-challenge/format-check/error events. The classifier has a bounded 512-character in-memory overlap and clears it at EOF. Stdout remains JSON; raw stderr is not logged or persisted. Configured-account extraction does not enable these verbose phases. `--no-quiet` was rejected during control preparation because it polluted stdout with progress; that failed diagnostic setup is retained separately from playback results. See the [upstream CLI reference](https://github.com/yt-dlp/yt-dlp#verbosity-and-simulation-options).

The 20-second deadline, access/quality policy, selector, checked-format requirement, retries, scheduler and queue/transport authority remain unchanged.

## Earlier observations before the packaging correction

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

## Startup stack and controlled correction — 2026-10-22

A bounded one-second startup sample began before the first stderr byte. The one-file bootloader waited on its Python child. In that child,704 of816 captured samples ended in dyld `__fcntl` under Python extension import, `dlopen` and segment mapping from the fresh `_MEI` runtime. This sampled request later completed in12.001s; it is a slow-start witness, not a newly captured detailed20s failure. The earlier timeout and every failed preparation remain retained. The sample's observation overhead is separate from the unsampled comparisons.

[PyInstaller documents](https://pyinstaller.org/en/stable/operating-mode.html#how-the-one-file-program-works) that one-file launches extract support libraries into a fresh temporary directory. The stack and paired trials locate an avoidable Python import/loader startup cost in that layout. They do not identify a particular OS validation daemon, quarantine rule, QoS or App Nap mechanism. The correction uses the same2026.10.21 [official onedir alternative](https://github.com/yt-dlp/yt-dlp#release-files); no extractor-version, deadline, selector, cookie, scheduler, retry or background-metadata change confounds the comparison.

| Signed application, same fixed recording | First stderr, seconds | Typed resolution, seconds |
| --- | --- | --- |
| One-file, sampled witness | 4.036 | 12.001 |
| One-file, unsampled run2 | 8.424 | 16.752 |
| One-file, unsampled run3 | 3.957 | 13.437 |
| Onedir, unsampled run1 | 0.258 | 8.669 |
| Onedir, unsampled run2 | 0.295 | 8.562 |
| Onedir, unsampled run3 | 0.199 | 7.591 |

The latter two pairs were interleaved. Both application layouts retained ordinary launch metadata concurrency and the same Swift executable, fixed recording, public Best/no-cookie policy and public runtime/extractor caches. Completed-media caches were moved aside between launches and typed-stream state was fresh. This superseded the planned scheduling/serial-metadata experiment: changing only runtime packaging removed the measured startup stall, so no scheduler/activity patch was made.

`copy-ytdlp.sh` now delegates to `bundle-ytdlp.py`. It verifies the upstream ZIP SHA256, an independently pinned normalized unsigned-tree digest and the pinned license. It restores four framework links only after comparing duplicate bytes/modes, preserves the full third-party notices, and checks every file/link/mode in the runtime. Failed downloads or validation leave the previous complete set intact. `--check` remains read-only and never executes a resolver.

Packaging installs both complete runtime copies, refreshing stale SwiftPM resources. It signs each104-file native closure and Python framework inside-out, retains the existing helper-only entitlement, and writes a signed-resource receipt covering the final runtime inventory. Verification checks that inventory and every native signature. A signed application is never modified by the install/sign actions. The app continues to provide its packaged runtime without an external Python/PATH dependency or a resolver self-update path.

## Fresh candidate verification

A fresh source snapshot, SwiftPM cache/config/security roots and Xcode derived data were used; no previous SwiftPM build state was copied. **1,077 tests /146 suites**, **34 release configuration/native packaging tests**, **7 strict single-worker tests /3 suites**, the Debug application build, both resolver executions, Deno execution and deep hardened ad-hoc signature checks passed.13 of the34 tests cover resolver archive/closure validation, failure preservation, read-only check, framework normalization, both installed copies and native signing coverage. Remote CI is tracked separately in the PR checks; the prior complete44bf6ad run is [39717226141](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/39717226141).

The rebuilt signed candidate uses `com.muses.acceptance.xw107-fixed-oct21`. Its exact executable, compiled-input and packaging-script digests, runtime receipts and source map are retained privately. The Swift/C application inputs match44bf6ad; the separately hashed packaging correction is the change under test. The source-revision field is not presented as proof that the packaging fix was already committed during measurement.

Three fixed public inputs were each tested three times, in interleaved order. Each launch restored a paused recording from a disposable copy of the same isolated535-track seed, with an explicitly selected queue cursor and checkpoint. The first recording retained its82.024s checkpoint; the other two used12s. Public runtime/extractor caches were retained, while completed media and in-memory typed streams were cold. Normal background metadata remained enabled. This is cold media/source resolution, not a claim of a cold OS disk cache.

| Public input | Resolution1, seconds | Resolution2, seconds | Resolution3, seconds |
| --- | --- | --- | --- |
| HsuGYhLsKyo — プリマドンナ | 8.077 | 7.854 | 8.638 |
| WQTf4lG-odE — Ooh Baby | 10.671 | 7.748 | 2.937 |
| 0bOMEdmLjoc — Showtime Ignition | 8.964 | 7.266 | 7.665 |

All9 resolved and reached real libmpv FILE_LOADED and the restored positive position, with the expected title visible. First stderr was0.168–0.249s, typed resolution2.937–10.671s and FILE_LOADED3.164–11.393s from native load start. There were no20s timeouts in this fixed sequence. All observations are retained; finite public/network trials establish no universal latency guarantee.

The same candidate then advanced real Opus playback to0:50, paused with its position stable, accepted a60s AAC seek, navigated Next/Previous, and replayed a completed AAC file. The cached generation selected the file at0.023s, loaded it at0.078s and reached positive position at0.175s. After pausing AAC at1:11 and normally quitting, a fresh process selected the completed cache and restored1:11 paused (FILE_LOADED0.621s). The application remained muted throughout. These are actual media/clock/control observations; new human-audible output is not claimed. Earlier human-audible evidence remains bounded to its original candidate. Cancellation/deadline/slot/dual-pipe and unfinished-Next behavior additionally passed the full and strict source regressions; no new native forced-timeout/Retry or complete device/rate matrix is claimed.

The final candidate retains all535 track identities and unchanged library/metadata fields. Only two tracks' play counts/timestamps, queue/session checkpoint fields, two added listening events and SwiftData sequence/version counters changed. No rows were removed. Every owned candidate was normally quit. All seven protected roots, including the formal application, normal raw data/preferences, canonical `.build`/`build` and both older evidence trees, exactly match this run's fresh baseline. The two older manifest-cache exceptions recorded above belong to the prior run and were not changed here.

Private evidence: `~/.muses/tmp/engineering-oct15/xw107-startup-oct21-01a16186`, including `layout-trials-corrected.json`, `native-cold-matrix.json`, `fixed-candidate-identity.json`, `validation-results.json`, `candidate-final-data-audit.json` and `final-protected-audit.json`. Expired driver-session and closed-log registration preparation errors were corrected before the measured candidate launch; neither is a playback failure or a successful trial.

## Remaining review and distribution gate

The cold startup correction and bounded source/native checks are ready for review in PR17. No merge, release tag/asset/feed or formal installation update is performed by this repair. Final Developer ID/notarized-package acceptance and the applicable integration review remain open;0.6.2 stays held. Premium is deferred and XW-74 remains paused. Parent issues are not closed from this child repair.
