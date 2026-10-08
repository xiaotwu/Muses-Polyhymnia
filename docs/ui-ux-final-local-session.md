# Final local journey and performance session — 2026-10-07

The local journey, representative measurements and session cleanup are complete. Comprehensive acceptance remains open for the explicit boundaries in the [64-area reconciliation](ui-ux-acceptance-reconciliation.md). This session does not convert unexercised branches into passes or close the implementation coordinators automatically.

## Exact candidate and journey

Executable source remains `37dbfce`; subsequent reconciliation commits change documentation only. The signed isolated candidate and SwiftPM Release executable shared arm64 UUID `3272A2B6-B5B0-38E6-AFC0-76C1ACD466AF`. Strict/deep signature validation passed before removing the obsolete isolated bundle. The existing final-source run passed 877 tests in 119 suites in 28.038 seconds; Release compilation took 66.42 seconds. No new application code was introduced in this session, so those source checks remain applicable.

The actual journey began with a cold Home at paused 0:20/app volume 80%, then Library Search for Resonating Beats, test's genuine 506-song detail/deck, and the complete native table. Native deck adjustment moved canonical focus 1 → 7 → 1. A generic tool scroll directed at the outline subsequently timed out; full AX reads also stalled while the process reported about one core of CPU. A three-second owned-process stack sample showed SwiftUI/AppKit layout and table accessibility work. The user could click Home, reporting only a slight delay; CPU then fell to an idle level and the tool reconnected. This is not evidence that the whole application was permanently hung, nor proof of a specific source defect.

Playback continued from the overview's **Play test**, retaining its 506-item collection. Library Search for 酸橙色信箋 exposed the full native track context menu. Play Next created one manual insertion; native Next consumed it, drained Up Next to zero and played that occurrence while retaining the original collection. Opening Now Playing hid the queue/PlayerBar and showed the actual track/credits/progress. Lyrics truthfully returned Find lyrics for this song; no document or timing was fabricated. Previously accepted genuine LRCLIB synchronized timing/mode evidence remains separately recorded under XW-68.

The on-demand video opened the floating window, returned to the main window and exposed its genuine YouTube player at about 1:56. Escape returned audio to the same Library query and actual playback around 2:02. Pause, ordinary Settings entry, Appearance and Diagnostics visits retained playback state and hid the PlayerBar in Settings. Native Back returned through the categories to the same query. Cover/Vinyl and reduced-visual preferences were restored to their original values before closing their windows.

After a cooperative quit, cold startup returned Home with the same manual current track, paused 2:39/app volume 80%, collection 506 and Up Next zero. Read-only comparison established exact semantic equality of decoded collection, insertion, history, groups, original order, Smart Shuffle, current index, repeat/shuffle, current identity and `159237.30158730157` ms position. Save metadata alone was excluded; SQLite UUID blobs were compared using the same representation on both sides. No raw JSON key-order equality or uninterrupted automation claim is made.

## Actual native table follow-through

A subsequent restored-baseline round invoked the vertical scroll area's exposed **Scroll Down/Scroll Up** actions directly. Fresh AX snapshots returned visible ranges 9–21 → 19–32 → 30–42 → 40–52 → 30–42 → 19–32 → 9–21. A separate traced round returned 19–32 → 30–42 → 19–32 → 9–21. Scroll Up and the outer scroller's native Scroll Left restored the first rows and leading title/artist columns; the actual screenshot retained full artwork rows and PlayerBar clearance. Home returned normally. This establishes those actions and outcomes, not equivalence to every wheel/trackpad gesture. The earlier generic-outline timeout remains a distinct tool/workload limitation; no speculative table refactor was made.

## Measurements

Each untraced sample verified the exact owned process UID, executable path and process start identity. CPU is the process CPU-time delta divided by elapsed wall time, expressed as a percentage of one core. RSS is resident memory, not total allocation or a leak measure. The ordinary desktop workload, trace export/analysis and automation were not isolated from the machine, and app activation/occlusion was not independently controlled.

| Actual case | Elapsed | Mean CPU, one core | RSS range | Conditions |
| --- | --- | --- | --- | --- |
| Home shortly after cold start | 20.017 s | 4.40% | 264.02–420.56 MiB | Paused 0:20/80%; loading/credit work may be included. |
| Now Playing cover | 20.021 s | 5.04% | 603.67–611.86 MiB | Actual cached 酸橙色信箋 playback; lyrics closed. |
| Now Playing vinyl | 20.013 s | 23.63% | 256.97–256.98 MiB | Same cached song/app volume; lyrics closed. |
| Vinyl, reduced visuals enabled | 20.026 s | 6.14% | 266.13–266.23 MiB | Same song; native seek to 0:30 before sampling; preference restored afterward. |
| Native table scrolling with AX inspection | 20.018 s | 52.90% | 801.00–806.36 MiB | Real Scroll Down/Up plus full AX snapshots; final action loop lasted 22.81 s, so not every action falls inside the sample. |
| Returned Home, paused | 20.011 s | 1.45% | 329.44–481.13 MiB | Later round after table exit; includes resident-memory changes/trace export. |

An earlier 20.024-second generic deck-scroll attempt measured 9.04% CPU and 337.22–359.14 MiB RSS, but did not change focus. It is retained as an unsuccessful input sample and excluded from successful-scrolling evidence. The single samples above do not establish a controlled performance improvement, energy savings, FPS or absence of leaks. Differences in memory/cache/position and concurrent desktop work prevent a causal percentage comparison between modes.

A driver-assisted cold launch to the initial AX response took **3091 ms**, including app launch, connection and accessibility inspection. This is a measured end-to-end automation latency, not isolated process launch time.

The first 15-second SwiftUI trace successfully attached/exported. Its scope included native deck adjustments, AX inspection and the transition to the table: 634,425 owned update rows comprised 620,749 Other Updates, 12,778 View Body Updates and 898 Representable Updates. The streaming duration analysis resolved 600,836 rows and left 33,589 unresolved references; the largest resolved row was 4.091 ms. That partial per-update result does not rule out aggregate layout churn, hangs or hitches. The 2,489,053,495-byte duplicate XML export was removed after retaining its summary and original trace.

The initial Animation Hitches trace exported zero hitch rows but coincided with the unsuccessful generic-outline operation. It is not a passed scrolling test. A second 15-second trace during verified native scroll actions exported **206 owned Muses hitches**, totaling **1808.348 ms**; median **8.333 ms**, p95 **8.334 ms**, maximum **25.000 ms**. Its 1712 frame-lifetime rows lack a process column; they were not used to infer user FPS or divide an app hitch rate. The trace includes instrumentation and full AX workload. It is evidence of nonzero hitches under those measured conditions, not a pointer-only benchmark or a smooth-scrolling declaration.

Raw traces, stack samples, screenshots, data checkpoints and detailed measurement metadata remain in private acceptance evidence. No account tokens, cookies or user library records are copied into this report or Linear.

## Cleanup and retained boundaries

The final native readback was Home, queue closed, 1000日間 paused 0:20 and app volume 80%. Mac relocking delayed only the last quit; after the user unlocked, Command-Q exited normally. Both exact process checks and app inventory confirmed the guest stopped with no running windows. Original 27-table schema/rows, database integrity and complete guest preferences compared successfully. The journey restoration removed three temporary keys; the final restoration removed zero extra keys.

The exact owned isolated app bundle, its acceptance cache and temporary entitlements file were removed. Current SwiftPM Release, the normal app build/installed application, original isolated data/preferences and private evidence were preserved. Prior full-run fixture cleanup had removed 73 attributed directories. No OS accessibility/display setting, Liked operation, output device, account-scope expansion, remote playlist write or installation/publication was performed in this session.

Remaining acceptance is explicit: macOS 26 actual runtime; populated subscriptions on an authorized channel with content; the user-deferred OS accessibility/display traversal; populated comments/replies denied by the current read-only account; the unexercised auxiliary/focus and other states named in the 64-area table. A complete pointer-only scrolling/frame/energy claim is also not established by these instrumented samples. XW-25/26/19/27 and overall coordinators retain those boundaries rather than blanket Done status.
