# Foreground history and Songs deck acceptance — November 5, 2026

This increment adds three native paths to the original open matrices. The isolated `com.muses.acceptance.ci-41098673128-1` candidate reused the retained CI41098673128 preview, functional source `e34fab55db0e3d6206d6e696ff42e26ecbcb214f`. PID 67264 ran on arm64 macOS 27.2 and loaded the exact candidate executable (SHA-256 `8408bf9d183332b8df9be2920d9d0874152d39d1fd06da7883cce637ee51cb43`). The isolated profile used the stopped acceptance donor. No account, normal-library copy, build or product publication was involved.

Preparation first stopped on a journal argument collision after acquiring the two locks and before extracting the app or writing the profile or preferences. The continuation extracted the app once and stopped on a full-tree mismatch limited to 42 symbolic-link modes (0700 in place of 0755). A separately scoped continuation restored those exact link modes and verified the full 784-node signed tree, including the original Info.plist. The initial failure and mismatch receipts were preserved. The app was neither re-extracted nor re-signed.

## Native observations

| Issue and path | Observation |
| --- | --- |
| XW-13 / XW-19, History Cancel | History → All Time showed 17m listened, 10 songs, 9 artists, 8% finished and 12 activity entries in the AX observation. The trash control opened `Clear all listening history?`. Explicit native `Cancel` dismissed the alert and preserved the relevant dashboard AX before/after, including the activity entries. The October 26 Clear and cold-retention path remains separate. |
| XW-9 / XW-19, dedicated chevron drags | Songs began at 426 of 535, プリマドンナ. An upward drag from [1368, 1225] to [1368, 1065] on the lower chevron opened the native table with rows 1–10 visible and default Title ascending. A downward drag from [1368, 324] to [1368, 484] on the return chevron restored the deck and the same canonical focus. The coordinates are from the captured native surface. Prior button expansion, scrubber dragging, sorting and pagination were not repeated. |
| XW-9 / XW-19, focused song information | In the regular-width window (2560 × 1608 capture), the native toggle reported Expanded and displayed the right-side `Focused song` pane with the same title and artist, `Prima Donna` album and a duration dash. The pane’s own xmark dismissed it and the deck retained canonical 426. The compact below-deck layout remains open. |

The player stayed paused at 1:11 / −1:41 and 0% volume. The session issued neither Play nor Seek. The main view returned to Home. Native menu Quit completed. The subsequent CUA app list and stopped process/hold checks confirmed candidate absence.

## Stopped audit and exact scope

The strict comparison retained the schema and 20 of 27 tables typed-exact, with zero deletions. All 40 ListeningEvent rows, all 535 Track rows and import memberships were typed-exact. The seven changed tables had 4 appended ACHANGE rows (two ListeningSession and two QueueState), 4 ATRANSACTION and 1 ATRANSACTIONSTRING append, and 3 ListeningSession, 6 QueueState, 1 Z_METADATA and 3 Z_PRIMARYKEY cell changes.

The separate qualification found seven decoded queue JSON values equal by type and value, including the 534-item order. The queue index was 16 at both checkpoints. The metadata plist differed only at `NSPersistenceFrameworkVersion` and `NSPersistenceMaximumFrameworkVersion`, both 1629→1634. The two position values changed from IEEE-754 bits ending `fc` to `ef` (−13 ULP each). The strict result remains false. The qualification applies to these exact changes and grants no general numeric or ORM allowance.

## Ledger and recoverable cleanup

Exactly three existing Muses issues received this native and audit increment. Readback matched each new prefix and complete prior suffix exactly. XW-9 and XW-13 remain In Review, and XW-19 remains In Progress. Their parents, project and other readback fields matched. The original matrices remain open and **暂不发布** stays in effect.

Private evidence remains under `~/.muses/tmp/engineering-oct15/foreground-continuation-nov05-01a18a83`.

| Receipt | SHA-256 |
| --- | --- |
| `native.json` | `cb7b36bf5299032dea323fb3b7fa4ec24e8c3bc2d0b117a32a88913ec5d884f0` |
| `store-audit.json` (strict false) | `f3c2ba9a73352daefcd947c60a79400ccecaceb40c07ab6c20fd78b576d26fd1` |
| `store-qualification.json` | `b491c7a104c95932fdf2e0ae2a1cc80f240f92b8e346ea8f25ec708df9464a9e` |
| `linear-native-reconciliation.json` | `1593234170df76c148c7724000bd59cb4dcfab708a42191b9e49bee73e4ba890` |

## Recoverable cleanup

The executor moved the 784-node application, 79-node isolated profile, 4-node HTTP storage and cleared preference plist to `~/.Trash/muses-foreground-continuation-nov05-01a18a83`. It unregistered the exact staged app path, retained 1,112 non-target Launch Services registrations and preserved all 78 other top-level Trash identities. One CFPreferences setter and one synchronize removed only the candidate’s Spotlight key. The readback preserved the normal Muses key at true, the other current Spotlight values and the menu preference. System Settings interface residue was outside this check. Both owned locks were released by recoverable rename.

At the executor checkpoint, the dedicated Trash held 458,412,157 logical bytes and 460,750,848 allocated bytes. Measured available space was 591,756,914,688 bytes. The recoverable moves reclaimed zero exclusive payload bytes and permanently deleted nothing. Executor receipt `cleanup-receipt.json` SHA-256 `66a71d68396e9045318f1181010f35c340dfa22a66e30e1ff88efaa6c4469345`.

Five temporary helper sources were packed into a verified 22,337-byte ZIP and moved recoverably to the task Trash. The archive manifest maps the historical source paths to the ZIP and original files. The first read-only post-check used the moved helper path as its source directory and stopped. A second check loaded the same frozen source with its original path context and verified the moved payloads, raw SQLite main and WAL bytes, normal app/data/preferences content, original build-root metadata and current shared preferences. The original post-check failure remains in the private evidence.

The final checkpoint measured 460,824,576 allocated bytes and 458,474,407 logical bytes in the dedicated Trash, 339,968 allocated bytes in the private evidence stage, and 591,739,580,416 available bytes. These are point-in-time readings. The helper archive SHA-256 is `6b1c3c53ea93fe73a901797aa5f610a9743e3f14badc8fd4e951265b1f268fb4`, its receipt SHA-256 is `b50b55c32e24cc78058f66afc654a10abf196659c8af9518db8381d568d38dc7`, and final guard SHA-256 is `684d3e96a7ae7cda0ed20aaa646e37aeb2e34c3bbd3b0a2f14174267f7e64cf8`.
