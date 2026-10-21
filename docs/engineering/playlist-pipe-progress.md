# Cold playlist playback and resolver pipe progress

2026-10-21, [XW-107](https://linear.app/xiaotwu/issue/XW-107/muses-keep-resolver-pipe-reads-off-cooperative-workers-during-cold), discovered at the 0.6.2 publication gate after the XW-106 runtime fix.

## Reproduction and evidence

The first signed, notarized 0.6.2 package was held from publication. Its isolated copy could play, pause/resume, Next/Previous and retain the 534-item Liked context, but repeated cold-media Play All attempts reached Retry at 0:00. Cold restoration of the current item also succeeded; these are different paths, not interchangeable acceptance.

The installed 0.6.1 application, normal database and preferences were preserved. Finder launched the candidate with `/usr/bin:/bin:/usr/sbin:/sbin`, and actual resolver arguments referenced the exact packaged Deno. Separate resolver comparisons succeeded with and without the existing Chrome source. The isolated GUI could not find Chrome's cookie database and used the existing no-cookie recovery path. A temporary resolver wrapper retained only fixed error categories and timing, never raw stderr, signed media URLs or credentials; one cold recovery resolved in approximately 2.93 + 4.14 seconds and played. The wrapper was then removed and the complete original candidate inventory restored. The later unmodified Play All failure prevents attributing every failure solely to earlier process inspection.

A five-second sample of the exact candidate showed blocking Foundation pipe reads on `com.apple.root.utility-qos.cooperative` inside `YTDlpRunner`. A standalone reproduction compiled the original runner source and used `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`: while a background child slept for three seconds, the separate foreground lane's immediately returning child took **2.861170583 seconds**, despite its one-second timeout argument. This demonstrates cooperative worker starvation and loss of foreground progress, independently of browser permissions or media networking.

The same reproduction with only pipe draining moved to a Dispatch queue for blocking I/O returned complete stdout/stderr in **0.003988667 seconds**. These are bounded mechanism measurements, not general startup, CPU, scrolling or energy claims. Some native logs also contained cancellation and resolver timeouts; the evidence does not assign every observed GUI failure to a single cause.

## Change and gates

`YTDlpRunner` suspends its pipe-reader tasks while a non-cooperative Dispatch queue performs the blocking reads. Both pipes still drain concurrently. Resolver slots, process arguments, the existing deadline and cancellation mechanism, browser consent/recovery policy and queue behavior remain unchanged.

The regression suite adds complete 256 KiB stdout and stderr capture. CI also runs that test and the existing foreground-lane regression with one cooperative worker. Full CI and a rebuilt, signed/notarized final package's repeated cold-media Play All, pause/resume, Next/Previous and queue preservation remain publication gates. No 0.6.2 release or update-feed replacement has occurred at this checkpoint. XW-74 remains paused.

Local focused verification passed 33 tests in four suites. The two one-worker regressions both passed: foreground selection in 0.020 seconds and complete dual-pipe capture in 0.164 seconds. These local checks do not replace the pending remote CI or final native gate.
