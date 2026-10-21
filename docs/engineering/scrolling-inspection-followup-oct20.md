# Scrolling and inspection attribution — October 20, 2026

XW-74 remains In Review. The current run establishes real foreground row movement and a normally saved owned-process Time Profiler capture. It does not yet isolate ordinary scrolling from the native inspection transport, so it does not justify an application performance patch.

## Candidate and workload

The unchanged Release payload was qualified at report source `724c3f3`: all 446 product inputs matched the retained build inputs. `com.muses.acceptance.performance-auxiliary-oct20`, build `20261020.7472`, used a separate writable backup of the current 531-track library, separate preferences and cache, volume zero and paused playback. No credentials or browser cookies were copied. The source normal library, formal 0.6.0 and earlier evidence stayed protected.

The actual main window was 1280 × 804pt, with app Light and system Dark, on Apple silicon/macOS 27.0.1 (26A434). This is not macOS 26 runtime coverage. After the tool's Raise action failed to activate the candidate, the human placed it in front; no scroll was dispatched before that handoff. The human's bounded foreground grant covered four groups of eight scroll calls. Exactly those 32 calls ran, with four down and four up in each group. That grant is consumed.

A used minimal explicit inspection: native scroll dispatch and a screenshot. B added one whole-window `getAXState(disableDiffing:true)` after each screenshot. The returned table described an outline of 100 items; this is not evidence of a complete 531-row AX traversal. Native screenshot checkpoints after calls 1, 4 and 8 in all four groups were retained: approximately rows 20–30, 77–87 and 1–11 respectively. B's per-step AX ranges also show down/up movement. These observations prove painted movement; they do not record each native event's receipt, delta or clip origin.

| Group | Workload wall time | Covered CPU interval | Process CPU seconds | Mean CPU, one core |
| --- | --- | --- | --- | --- |
| A1 | 23.028s | 22.451s | 13.898s | 61.906% |
| B1 | 32.936s | 32.505s | 27.324s | 84.059% |
| B2 | 32.100s | 31.635s | 26.051s | 82.349% |
| A2 | 22.779s | Incomplete: 1.029s | Not accepted for the full group | Not accepted for the full group |

A dispatches followed a three-second cadence. B's extra AX reads took 13.491s/13.213s in total, with median reads of 1.615s/1.578s, and stretched dispatch intervals to about 3.6–4.8s. Metadata/credit enrichment was also still evolving. The phases are therefore not a matched causal ABBA comparison. The approximately 190s interval from A1 start through cooperative quit includes gaps; it is not uninterrupted exposure evidence. Passive window-order observations cover A1/B1/B2, with insufficient coverage for all of A2. The original long-lived reader slept without servicing its main run loop, so its `NSWorkspace` active-PID field is not independently qualified for live changes. Fresh WindowServer ordering and retained native images supply separate sampled visibility evidence; neither establishes continuous keyboard focus or uninterrupted exposure.

## Counter correction and stacks

The original private reader mislabeled `proc_pid_rusage` CPU counters as nanoseconds. On this host the counters are Mach ticks; the measured timebase is 125/3 nanoseconds per tick. The original approximately 1.5–2.0% phase figures are invalid and are superseded by the table above. Original output is preserved alongside the corrected analysis. A separate one-second self-process calibration compared converted counters with `getrusage`: 0.996062s versus 0.996072s, about 0.001% relative difference. That calibration verifies units, not Muses performance.

The normally saved Time Profiler trace lasted 125.912s, exited 0 and covered A1/B1/B2. A2 began after capture ended. All 74,419 exported Running samples resolved to the owned process; 72,568 were on its main thread. Inclusive sample weights overlap and must not be added or treated as exact CPU durations.

| Main-thread sample weight | A1 | B1 | B2 |
| --- | --- | --- | --- |
| Samples in the phase | 13,637ms | 27,083ms | 25,946ms |
| Stacks containing AX work | 8,239ms | 16,048ms | 15,485ms |
| `_AXXMIGCopyHierarchy` | 7,320ms | 14,436ms | 14,040ms |
| `GeometryReader` | 1,168ms | 2,411ms | 2,287ms |
| `sizeThatFits` | 1,353ms | 2,674ms | 2,521ms |
| `CollectionTrackTitleCell.body` | 130ms | 286ms | 311ms |

The useful finding is that substantial AX hierarchy/layout work is already present in A. A screenshot with no explicit extra AX request does not establish a no-AX transport. B adds elapsed inspection work, but its CPU difference cannot be attributed solely to an app scrolling algorithm. No queue, artwork, row height, focus, playback or observation subsystem was optimized from these samples.

## Recorder lifecycle and remaining work

A separate requested ten-second no-input Animation Hitches pilot saved normally: 11.175s actual capture, 84.173s observed wall time and exit 0. The earlier foreground-entry Animation Hitches attempt recorded zero scrolls; its 51.159s TOC is readable, but its wrapper failed while finalizing and has no accepted normal exit. Its recorder later saved and disappeared. Finalization overlapped the later Time Profiler interval, an unmeasured external confound. These records remain separate rather than being labeled one successful frame benchmark.

There is no accepted scrolling-frame/FPS denominator, energy comparison or leak study. The next attribution step needs a fresh no-AX process and passive native event/clip-origin evidence, with a stable workload and explicit coverage. No further foreground scrolls have been authorized by the consumed 32-call grant.

The measured candidate quit normally. Its exact initial 20-key preference dictionary was restored; `defaults import` merged four extra own keys, so those keys were explicitly removed and equality rechecked. Its data/cache and necessary traces, original failures, corrected counters, input journal and twelve original response images remain private under `~/.muses/tmp/engineering-oct15/performance-auxiliary-oct20/`. This stage retained its candidate for diagnosis and did not claim bundle/cache cleanup. Protection checks passed for the full formal-app inventory, normal raw data and preferences, original 0400 seed, old candidates/evidence and shared Release outputs. The subsequent XW-72 repair candidate is a separate source revision and runtime stage.
