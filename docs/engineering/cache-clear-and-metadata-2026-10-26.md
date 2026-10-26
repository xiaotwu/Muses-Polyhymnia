# Background cache-clear failure and remaining display cells — 2026-10-26

This pass continues only reliable background acceptance. Previously accepted cells are reused, and previously ineffective input routes are not repeated. No publication is authorized; XW-74's skipped measurements, Premium and Erato pauses remain in force.

## Confirmed defect: XW-129

The original isolated Release 0.6.2 build `20261026.1` was restored from its existing archive. All 623 application entries, archive SHA-256 `d2525032e2c30bad9a525d7b133c7b964b19954b5701513da13d046ffb38461f`, strict deep signing verification and product-source equivalence to `a8e95c5` were checked. The namespace was `com.muses.acceptance.remaining-20261025`, with a newly created empty store and only muted volume/system language preferences. No production data or credentials were copied.

A controlled nonmedia partial file of 53,248 bytes was placed in the disposable stream-cache directory. Settings → Playback showed **53 KB** and its native Clear confirmation named the same amount. With that owned directory changed to mode `0500`, pressing the confirmation's actual Clear button changed the interface to **Zero KB**, although the file remained unchanged (SHA-256 `2e8c4f9aa450b1a0e52a8ca0488e027dca99aea009f29b6a0d60139b5ce797c9`). No error appeared. Playback was empty and idle pre-download was off.

`MediaFileCache.clearAll` suppressed removal/recreation errors, and Settings unconditionally cleared its displayed summary and reloaded playback. [XW-129](https://linear.app/xiaotwu/issue/XW-129) tracks the narrow repair under XW-17. The separate concurrent playback/pre-download lifecycle is not accepted by this fixture.

Two preparation errors are preserved in the receipts: an incorrect expected fixture size stopped before changing permissions, then an unsupported observation field caused a batch to execute zero steps. Both were corrected before the one real Clear confirmation. Neither is counted as a product failure or a repeated native deletion.

## Additional original-candidate native evidence

The genuine empty Music Videos page displayed **0 music videos**, **No music videos yet**, and its own **Open Search** button. Pressing that button opened the Search page, with its field, source/category controls and Browse Your Music cards. This adds only the specific empty-state/rendering/routing cell; previously accepted populated Light/Dark cells are not counted again.

The original candidate PID `81755` exited normally through its native Quit menu. Both initial and stopped store snapshots have integrity `ok`; all user-content tables are empty. Source work and native operation use mutually exclusive workspace/runtime locks.

## Evidence and remaining scope

Private screenshots, complete typed SQLite snapshots, Cua responses and preparation receipts are retained under `~/.muses/tmp/engineering-oct15/background-cache-metadata-oct26-01a17a75`.

The original 23 coordinator/matrix issues retain their open statuses. Native metadata Save input, table headers/descending, paging toggle, multi-bookmark drafts, genuine provider-only unsynced lyrics, account/provider/device conditions, physical keyboard and accessibility/macOS 26 cells remain separate. This document will record repaired-build verification and final preservation/cleanup once those steps complete.
