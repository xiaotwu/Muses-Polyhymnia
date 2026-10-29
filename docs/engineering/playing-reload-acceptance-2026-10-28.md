# Playing-current reload acceptance — 2026-10-28

The user requested completion of the remaining reliable background work, followed by a new conversation focused on foreground acceptance. This pass adds only the playing-current Clear and quality-reload cells. Previously accepted paused reload, search, History and error/retry cells are reused. XW-74 measurement, Premium, Erato and publication remain paused.

## Exact candidate and isolation

The existing Release 0.6.2 / `20261026.3` candidate was restored from its verified ZIP, SHA-256 `3ad8eebd6f6ab85c4d04e9d2e65bb8ab4a6fc8a29713a9ed8cbae31abcf98f7b`. All 623 entries, modes, symlinks, executable hash and strict deep signature match. Its frozen source is `d7bea1b`; current product source is equal. There was no rebuild, resigning, source modification or repeat of the completed source CI.

The reused acceptance identifier is `com.muses.acceptance.remaining-20261025`, at a newly created isolated profile. Before preparation its logical preference domain was empty and its physical plist/profile/registration absent. Preparation saved those observations, copied the untouched 535-track / 1,064-member / 40-event stopped acceptance seed, verified all 27 tables, and set only system language and floating-point app volume 0. The 534-occurrence queue starts at index 16, current Track `CD440950-B881-46AD-A635-FDD4DCACA8A1`, paused at approximately 71 seconds. This pass reused the saved acceptance seed; normal data and credentials remain untouched.

Private evidence is retained under `~/.muses/tmp/engineering-oct15/background-playing-reload-oct28-01a17a75`. The host is macOS 27.0.1 / 26A434. Cua Driver 0.37.0 uses the existing shared daemon. History tools are not advertised. Workspace preparation and native execution use mutually exclusive owner locks; root is the sole GUI controller.

## Native playing-current Clear

PID 29647 / window 114722 restored **プリマドンナ** at 1:11, with app volume 0. Native Play produced Pause and an advancing clock, **1:12 → 1:20**. Settings → Playback → Clear media cache displayed the actual **2.9 MB** confirmation. The one Clear action succeeded; the sheet disappeared and Zero KB appeared. Returning Home showed the same song with Pause and **1:42 → 1:51**. Native Pause stopped it at **1:52**.

The controlled partial fixture was subsequently absent. Genuine current media was cached again; there is no claim that the final cache stayed empty. Artwork and Home sentinel hashes remain equal to preparation. This adds playing-state position/intent and subsequent clock progress, rather than repeating the previously accepted empty-current or paused-state deletion checks.

## Native playing-current quality change

The next segment resumed from that new pause position. Native Play again displayed Pause; the clock advanced **1:53 → 2:32** before the actual Data saver selection. The radio's selected value was read back. Home initially waited for loading to finish, then showed the same song, Pause and **2:35 → 2:48**. Pause stopped it at **2:50**, before natural completion. Automatic was restored while paused, with its selected value checked; Home retained the 2:50 pause.

The observed sampling intervals are preserved in invocation timestamps and `clock-checkpoints.json`; the second pre-action interval was 39 seconds. Actual pause occurred near the ending, with about two seconds remaining. No Next or natural completion was observed, and the complete history/queue audit determines whether that narrow same-occurrence condition held.

These observations prove native clock/position and playback intent. Volume was zero, so they do not prove human audibility, audio quality or uninterrupted sound. Concurrent pre-download, other quality/source combinations and controlled provider failures remain separate scenarios.

## Persistence and closure

The first process quit through the native menu and was confirmed absent before its stopped snapshot. A fresh PID 31731 / window 114854 restored the same song paused at **2:50 / −0:02**, with Play visible; it then quit normally before `final-stopped` was captured.

An initial cold-window discovery accidentally queried PID 29796. Its empty result is retained as a read-only targeting mistake, followed by discovery using the actual launch-returned PID 31731. No input targeted the wrong PID, and that empty list is not process-termination evidence.

All `run_steps` invocations request background delivery with foreground fallback disabled; Quit receipts report background, and both launches report self-activation suppressed. Traffic-light appearance alone is not evidence that global frontmost ownership stayed unchanged, so no such broader claim is made.

## Independent data audit

Seven immutable SQLite copies independently match their full 27-table typed reports, schemas, column metadata, implicit rowids and PRAGMAs; each integrity check is `ok`. All 535 Tracks and 1,064 import members remain. Only the current Track changes its play count from 11 to 12, last-played date and ORM version after the actual first Play. The other 534 complete Track rows and all 40 old ListeningEvents remain exact, with no new history event. All 534 queue occurrences, their order, index 16, current UUID and full decoded queue/session JSON remain equal. The final comparison has 21 unchanged tables; Track, QueueState, ListeningSession and three ORM tables contain the explicitly recorded changes. This is not whole-database equality.

QueueState and ListeningSession positions are equal at every checkpoint: baseline `70999.99999999994`, Clear pause `112305.69104266219`, quality pause `169646.3800850101`, Automatic-restored pause `169696.78212667682`, and both stopped captures `169696.77083333343` milliseconds. Quality pause to restored pause moves forward by 50.4020416667 ms; the final live-to-stopped difference is −0.0112933434 ms. The two stopped values are identical. Those small differences are retained without a clamp or exact-live-equality claim.

The independent native/data audit passes and binds 135 retained inputs. `final-native-audit.json` SHA-256 is `8dc4643af52956bdbcab7099889ace340245bdf7db88ccc2f62de59752e3ded0`; its review is `final-native-review.md`, SHA-256 `7698ef427bfe9f276d13999724102a1bcd44b69b36a32a4bfc022febbc1d79b7`. No additional product defect was confirmed. Repeated reload while pending still has component evidence only; no complete matrix, audibility or performance pass is added.

## Cleanup and synchronization

The reviewed cleanup script removed only the expanded task app, acceptance profile and physical acceptance preference plist; both launched PIDs are absent and the exact acceptance registration count is zero. The initial two-key System/float-zero preferences were strictly restored and read back before returning the logical domain to its original empty dictionary and removing the empty physical plist. The complete 62-entry final profile TAR, its full manifest, raw SQLite/WAL/SHM, final and restored preferences, screenshots and action/audit receipts remain. The previously verified 623-entry app ZIP is reused without creating a duplicate archive.

The turn interruption occurred after the target removals, before an original success receipt was saved. No success or failure receipt from that script exists, so it is not recorded as a normal script completion. The destructive script was not rerun. An independent read-only review instead verified the three absent targets, two absent PIDs, zero registration, empty logical preferences, strict initial preference readback, complete TAR bytes/modes/types/symlinks, old ZIP SHA/CRC, raw-store links, all 135 audit inputs and a fresh complete inventory of all five protected roots. The formal app, normal data/preferences and shared build roots remain equal to the fresh pre-task baseline. The shared Cua daemon remains.

The final profile TAR SHA-256 is `3104b49d1b3dd869dd35d5c6acfbf91ae10327e8c4f12d3d699ec9b91656723d`. `cleanup-interruption-independent-review.json` is `3cf68aeb77d2651b2e07b4fe26fc33a493cc3d009ce95cf5637749360b700cf7`; the explicitly labeled owner recovery record `cleanup-recovered-closure.json` is `26e4de9681d5ee3cb62cacbb7a3d6bb29a284b78881955237667799a6d5d1720`.

Linear XW-130/17/11/10/26/19/12/27/5 and both existing Muses project documents were updated and read back. All previous description/content suffixes, titles, states, project membership and issue parents remain unchanged. A fresh full project query is still 116 issues: 93 Done, 17 In Review and six In Progress, with the same original 23 open IDs. XW-130 remains Done; no complete coordinator/matrix was closed. `linear-sync-readback.json` SHA-256 is `d9f1fdff1ece6385687a30642f3131061028977646d63b84eb1fe0c85f6af048`.

## Next conversation

After the data audit, cleanup and record synchronization, create the requested fresh conversation for foreground acceptance. The user's October 28 instruction authorizes necessary visible input on the isolated candidate in that follow-up. It does not resume XW-74/Premium/Erato, authorize publication, mutate normal data or protected playlists, grant account/credential/system permission changes, invoke Siri or install updates.

First work through remaining native table-header descending/paging-toggle input, real multi-bookmark text submission/cancel isolation, temporary owned EQ-preset deletion/Flat and physical Escape, then no-main-window Settings/About and Diagnostics preview/Cancel. Reuse accepted setup and do not count it again. Old ineffective background input is a reason to change the method in the foreground, not to replay the same rejected action blindly.

No additional background cell without a new scenario prerequisite was identified after these two playing-current checks. Concurrent pre-download, genuine provider faults, account content, macOS 26, other devices and full accessibility conditions remain explicitly unaccepted; moving to foreground does not supply those prerequisites.
