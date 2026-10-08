# Collection scrolling and inspection overhead — 2026-10-08

The current executable phase is complete with explicit measurement limits. Two minimal-inspection wheel runs moved genuine `test` rows. Both full-AX attempts timed out before their first wheel input, so this is **not a successful controlled ABBA comparison**. No optimization, FPS, energy or leak improvement is claimed; XW-74 remains In Review for the missing complete-AX/frame conditions.

## Exact source and conditions

The candidate uses `91cf3371e479f5974736f5c451d2f4ff25329e3a`, arm64 Release UUID `B66C9021-22BC-3364-93BA-294CCCC938E8`. [Full macOS CI 37853523168](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/37853523168) completed successfully on that exact SHA: tests, App Intents metadata and preview packaging all passed. This phase reused the already-built Release and did not repeat tests/builds or change executable source.

Local conditions were macOS 27.0.1 (26A434), Swift 6.4, Mac17,2, 24 GiB memory and ten CPU cores. The ad-hoc hardened acceptance bundle had debug attachment enabled only in its temporary entitlements. It used `com.muses.acceptance.performance-oct08`, an independent Keychain namespace with no account configuration, playback cookie source None and Web Home off. No production credentials were copied or read.

The preserved isolated donor library contained 655 YouTube-backed tracks; the existing `test` import contained 506 occurrences. The donor remained read-only. Every cold trial restored the same SQLite seed, complete test preference seed and disk-cache seed. Seed-cache manifests matched across all four trials. Each new process navigated Home → Playlists → test → complete table, warmed the same bounded row interval with four down/four up wheel events, and waited until two consecutive checks found no direct resolver child. This is a bounded quiescence observation, not proof that every URLSession task or in-memory cache was identical. Display-credit results and resident memory differed between cold runs.

One main window used an independently read-back 1100 × 820 pt frame at (100,100), with 1568 × 1169 px captures. App appearance was Light, standard F3 text, ordinary visuals and native table mode. Playback stayed paused at 0:20, app volume 80%, Queue closed and Repeat One inherited from the seed. The window was background-routed (inactive traffic lights); on-screen/current-space metadata was observed, but foreground exposure and occlusion were not independently controlled. Normal applications and ambient desktop work were preserved. Neither OS appearance, accessibility, refresh rate, security, output device nor system volume was changed.

## Workload and actual outcomes

A is screenshot-only inspection (`include_accessibility_tree:false`). B requests the same screenshots plus a 10000-node/40-depth AX traversal. Each planned 45-second workload dispatches eight targeted real wheel events at screenshot-verified point (500,650), amount 3/by line: four down then four up, at five-second intervals. Fresh screenshots bracket inputs. A pre-inspection that misses its deadline or lacks a structured result invalidates the run. These are intermittent synthetic wheel bursts, not continuous physical trackpad input or a user-perceived latency benchmark.

CPU is the owned app's process CPU-time delta divided by monotonic elapsed time, expressed against one core (ps CPU-time resolution 0.01 s). RSS is a one-second sampled resident range; it excludes unsampled peaks, compressed-memory interpretation and descendant-process CPU. UID, executable path and process start identity were checked throughout. CPU runs were separate from stack sampling and Instruments capture. Both coordination locks were held; no other task build, test or GUI lane ran during capture.

| Attempt | Owned PID | CPU capture | Mean CPU, one core | Observed RSS | Input/read result |
| --- | --- | --- | --- | --- | --- |
| A1 | 35973 | 45.0119 s | 2.8659% | 253.70–287.58 MiB | Eight wheels; complete visible row sequence 1–11 → 7–17 → 13–23 → 19–29 → 25–35 → 19–29 → 13–23 → 7–17 → 1–11. |
| B1 | 39477 | 45.0110 s | 100.1533% | 256.08–334.23 MiB | First AX read returned the driver's 20-second timeout at 20.0405 s; zero wheels. Invalid comparison sample. Remaining CPU interval includes post-timeout activity. |
| B2 | 42465 | 45.0071 s | 100.0954% | 284.63–320.67 MiB | Same 20-second timeout at 20.0386 s; zero wheels. Invalid comparison sample. |
| A2 | 45542 | 45.0113 s | 2.7771% | 150.16–153.42 MiB | Eight wheels and dispatch cadence completed. Rows 1–11 → 7–17 → 13–23 → 19–29 → 25–35 → 19–29 → 13–23 → 11–21 → 5–15. Late range drift prevents treating this as an identical return-path replicate. |

A1's painted range movement is directly verified. A2 proves real movement but not identical row anchoring. Its final two ranges differ from A1; the available screenshots show evolving credits, but do not uniquely attribute the drift to metadata, AppKit anchoring, input delivery or another cause. No speculative table/height/focus patch was made. Earlier progress text saying both A runs shared the same complete row sequence was preliminary and is superseded by this screenshot reconciliation.

B's approximately one-core readings cannot be divided by A's readings to claim an improvement: B did not perform the same input sequence. The timeout establishes an inspection/driver limitation under these conditions; it does not establish that ordinary pointer scrolling hangs the app. Screenshot-only reads and cooperative quits remained available after the failed AX walk. A separate default 2000-node/25-depth pilot also returned the explicit timeout. The initial larger pilot lacked retained stderr/exact elapsed time and is excluded; subsequent raw timeout responses/timings are retained.

## Owned-process hotspot and frame evidence

A separate three-second, 10 ms stack sample attached only to acceptance PID 32805 during the default-AX diagnostic. Its main-thread call graph included AppKit layout, CoreAutoLayout and SwiftUI work. It was not included in the CPU trials.

A 25-second Time Profiler recording attached only to B1 PID 39477 after the failed AX read, with no wheel inputs. Its exported target and 25.9005-second trace duration were verified. All 25,306 exported rows resolved to that owned process; 24,749 main-thread rows were Running. Sample weight was 25,306 ms overall / 24,749 ms main thread. Inclusive weights overlap and are not exclusive CPU percentages: `GraphHost.flushTransactions()` had 13,107 ms, SwiftUI `LayoutEngineBox.sizeThatFits(_:)` 11,920 ms, and nested stack/GeometryReader layout about 11,800 ms. Leaf samples included Objective-C messaging, CoreAutoLayout's `NSBitSetFindNext`, Foundation observation and AttributeGraph updates.

Application frames beyond entry-point ancestors were comparatively small in this diagnostic (`CollectionTrackTitleCell.body.getter` 175 ms inclusive; translation 82 ms; image-loading frames about 51 ms). This confirms sustained main-thread framework layout/transaction churn after full inspection, not a uniquely identified application algorithm to optimize. No queue/playback, table sorting, context-menu, keyboard/AX, artwork or high-frequency observation subsystem was modified.

A separate Animation Hitches capture attached only to B2 PID 42465 after AX failure: exported target verified, actual duration 25.8191 s, **zero owned hitch rows**. It had no wheel inputs and a background window; zero rows do not establish smooth pointer scrolling. Frame-lifetime tables do not provide an owned-process FPS denominator.

The A2 pointer workload completed separately under a requested 55-second Animation Hitches recording, but the recorder remained in “ending recording” for more than five minutes after reaching its time limit. Exact UID/path/arguments verified its ownership before SIGINT, then SIGTERM when it still did not finish. The recorder exited with code 1. This incomplete capture is **not accepted frame evidence**. Its pointer screenshots/input log remain useful, but there is no valid pointer hitch/FPS comparison. No energy measurement or leak test was performed.

## Cleanup and remaining gates

All pilot/trial apps quit through targeted Command-Q; the driver acknowledgements sometimes reported unverifiable/delivery-failed while independent PID and window checks confirmed exit. No app force-kill or ordinary-application shutdown was used. The separately owned stuck recorder was terminated as described above. Exact trial/recorder PIDs and native inventory were checked; no performance instance remained.

The complete original own preference dictionary was restored and compared. Donor SQLite/WAL/SHM hashes and its complete preference dictionary matched; normal app Info.plist/executable hashes also matched. Only the unique owned registration, bundle, entitlements/staging and disposable data/cache were removed after bundle-ID, UID and no-symlink guards. Private source checkpoints, compact raw traces, summaries and owned-window screenshots remain under `~/.muses/acceptance/com.muses.acceptance.performance-oct08/evidence`. The current shared Release and ordinary apps/Keychain were preserved.

Remaining XW-74 conditions: a complete-AX traversal that can coexist with a matched input cadence; a successfully finalized pointer frame trace with verified exposure; independent resolution of the A2 anchoring drift; and any separately requested physical trackpad/foreground/energy or long-duration memory study. Actual macOS 26 native runtime remains a separate family acceptance boundary. The runtime-complete marker means this executable phase was cleaned and released, not that these conditions or parent acceptance tasks passed.
