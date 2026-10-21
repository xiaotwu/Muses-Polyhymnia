# Native scrolling input follow-up — October 20, 2026

The [earlier 32-call inspection trace](scrolling-inspection-followup-oct20.md) did not isolate ordinary scrolling from AX transport. The next attempt uses a private diagnostic source copy based on `4a2a2cf`, with a bounded native wheel/clip-origin receipt buffer attached only to the owned collection table. Events return unchanged. The buffer exports only on normal termination; it does not read row text or credentials, synthesize input or activate a window. This instrumentation is absent from product source.

The signed isolated `com.muses.acceptance.scroll-receipts-oct20`, build `20261020.746271.1`, uses the separate 531-track/6-event backup and muted preferences, with the actual 1280×804pt Light window on macOS 27.0.1. The human launches and navigates before any target Cua binding. A passive RunLoop-serviced process reader records Mach-tick CPU counters with the host timebase, window ordering and active PID. Each profiler has an owned PID, explicit coverage and normal-finalization checks.

## First attempt: sequence not accepted

The requested sequence was two rounds of four down/four up touchpad gestures. The human instead reported no movement, then clarified using both touchpad and keyboard. The normally saved Time Profiler capture lasted 120.867801 seconds and exited 0; it is not a completed scrolling benchmark.

The owned table received 116 precise wheel events belonging to one gesture, spanning 1.296 seconds. The application was active and its window key for those events. Delivery lag was 0.000713–0.021379 seconds. Native clip origin ranged from −29 to 116.5pt, with first-visible row indices 0, 1 and 2, followed by a return to the top. This establishes a short delivered gesture and transient native movement; it does not establish the requested 16 gestures, sustained painted movement or frame pacing. The later screenshot/AX check showed the first rows at the top. Target AX reads began only after the human failure report; samples from that conservative timestamp onward are excluded from ordinary-input analysis.

The passive reader covered 1.521 seconds around that single gesture, observing 0.371 CPU seconds (24.402% of one core). Only four samples cover it. The preceding idle interval did not remain foreground throughout. These intervals are not an accepted idle/scroll or A/B comparison. Main-thread inclusive stack weights overlap and do not justify a performance patch.

The candidate quit normally and exported its bounded receipt. The first strict frontmost-at-start gate had recorded zero profiler starts before correction: replying in Codex can foreground Codex, so actual wheel/key-window receipts, rather than the reply-time state, establish foreground execution.

## Touchpad and keyboard separation

A second bounded 300-second launch wait expired with zero candidate/profiler starts observed during that wait. The human subsequently confirmed that touchpad scrolling moves the table while direction keys do not. That report is interaction evidence; the expired capture supplies no performance coverage. Keyboard scrolling needs separate table-focus verification and is not yet a confirmed application defect.

The next capture was prepared to wait for a manual foreground transition. Before it started, the human explicitly confirmed that touchpad scrolling works and asked to skip this part. The owned waiting CLI was stopped and its absence verified; it started zero new recorders. No additional touchpad measurement is pending or requested by this follow-up.

A separate, non-performance keyboard check on the unchanged table implementation established table focus by selecting the first song once, without playing it. One Down selected row 2; twelve more selected row 14 and advanced the native vertical scrollbar beyond the initial viewport. Thirteen Up returned selection to row 1, and the scrollbars were restored to zero before normal quit. This supports the need to establish table focus for that sequence; it does not reproduce a direction-key application defect or justify a source patch.

The human touchpad report and focused-keyboard sequence are accepted as those interaction results only. A repeatable matched scroll/AX workload, ordinary application hotspot, frame/FPS denominator, energy and leak results remain unaccepted. No performance optimization has been made. XW-74 remains In Review, and measurement resumes only if the user requests it.

Private sources, signatures, normal backups, native receipts, failed gates, traces, exported sample data and journals remain under `~/.muses/tmp/engineering-oct15/catalog-settings-comments-oct20/`. The formal-app inventory, normal library/preferences, original immutable seed, previous evidence and shared Release outputs remain protected.
