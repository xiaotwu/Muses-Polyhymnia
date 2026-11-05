# Expanded foreground acceptance — November 5, 2026

This isolated batch tracked 11 native paths. Nine passed, one failed and one remained unobserved. The retained CI41098673128 preview used the exact signed 784-node bundle from functional source `e34fab55db0e3d6206d6e696ff42e26ecbcb214f`. The bundle ID was `com.muses.acceptance.ci-41098673128-1`. PID 69399 loaded its verified executable on arm64 macOS 27.2. An initial read-only symbolic-link preflight was refined to resolve internal link chains. The frozen preparation executed once and passed.

## Native results

| Scope | Exact observation |
| --- | --- |
| Songs compact information | A 2122 × 1608 capture showed the expanded pane below the deck at canonical 426. It displayed プリマドンナ, Hoshimachi Suisei - Topic, Prima Donna and a duration dash. One scroll exposed the complete pane and scrubber above the PlayerBar. The pane’s own xmark collapsed it and focus returned to 426. |
| Songs table Escape | Escape left the table in place while the window itself held focus. With no menu or dialog open, a single click selected row 1. Escape from that table state returned to canonical 426 in the deck. |
| Imported test order | The actual Order header displayed descending canonical rows 530–526. The five titles matched the frozen donor tail: Never Gonna Give You Up, Trademark - Without You, Trademark - Three’s A Crowd, Trademark - There’s No One Like You and Trademark - Step Into My Life. The ascending canonical order was restored. |
| Imported test Artist sort | The actual Artist comparator reported `Artist: Ascending; then Collection order: Ascending`. The first four displayed artists were 3LAU - Topic, 5 Seconds of Summer - Topic, 26Jino Masquerade - Topic and 40mP - Topic, with original ordinals 290, 223, 151 and 341. Collection order was restored as primary ascending before leaving the table. |
| History row menu | In All Time, the A Head Full of Dreams activity (29s) exposed Play, Play Next, Add to Queue, Like, Go to Artist and Share. Escape closed its own menu and kept the activity visible. No menu action was selected. |
| Settings gesture-area disclosure | Pointer clicks on the actual chevron expanded and collapsed the explanation. It showed Down · close, Left / right · track and Up · lyrics, plus the artwork/background and lyrics/slider/scrolling boundaries. The three switches retained On / On / Off. The earlier AX-label click had no effect. |
| Settings lyrics preference | Native Automatic → LRCLIB → Automatic selection changed the owned preference to `lrclib` and restored `auto`. Lyric display surfaces stayed closed. This is preference evidence. |
| Diagnostics repeated Preview / Cancel | None → Safari staged preview was opened and canceled twice. Both preview AX trees matched. The draft returned to None, the cookie-source key was absent and Diagnostics closed. Apply was never invoked. |
| Public Search categories | The same `Daft Punk` query and YouTube source held through Artists → Albums. The former showed Daft Punk and the latter displayed Random Access Memories, Discovery, Alive 2007 and Homework (25th Anniversary Edition). The source and query were restored to All Sources and empty. |
| Songs deep cover-wall focus **failed** | At canonical 426 of 535, switching to Cover wall started the visible grid at row 1. The row-426 card was absent from the stable rendered/AX evidence. Returning to Focus strip preserved 426 and the same paused player. Root cause and repair remain open. |
| In-flight Search cancellation **unobserved** | No cancellable busy control was observed on the initial or supplemental-prefix request. Neither Cancel nor Retry was invoked. |

The player stayed paused at 1:11 / −1:41 and volume 0%. No Play, Seek, Like or playlist mutation was invoked. Home, Search and the Settings drafts were restored, and normal menu Quit was corroborated by the CUA app list and absence of PID or file holds. The attempted resize back from 2122 × 1608 to the initial 2560 × 1608 capture did not regain the original width. The narrower frame applied only to the isolated instance. Previously accepted paths were not counted again.

## Evidence and closure

Private evidence is retained under `~/.muses/tmp/engineering-oct15/foreground-batch-nov05-01a18a83`. The candidate receipt is `33a0f3dbae03df3bffe18ada0e64c83893a68e87049685e47caef63d1814561b`, the launch receipt is `40812b5f459974fa8c5a5bfa6dcb391b500fb159ee8020a8a6de5187346f53e8` and `native.json` is `3a9144b5bd2e586c8cb1775a10cdcc4781f03963e91ebde29f78b9a08a1b7c04`.

The stopped audit retained 20 of 27 tables typed-exact, including all 535 Tracks, 1,064 import memberships, 40 ListeningEvent rows and the complete Liked 534-item order. The queue retained 534 items and index 16. All seven queue and two session JSON values matched after canonical typed decoding. Seven state, ORM and metadata tables contained 13 changed cells, nine appended rows and zero deletions. The four ACHANGE rows were limited to state entities. The two paused positions changed by exactly −13 ULP each, and two framework version integers in the metadata plist changed from 1629 to 1634. The original strict result remains false. The separate qualification covers the exact changes. The read preserved main/WAL and donor bytes, with a change in the existing SHM coordination bytes.

| Receipt | SHA-256 |
| --- | --- |
| `store-audit.json` (strict false) | `225701b304e17cdca6d41ad97b20776210bc2d470d61ae4e521e121dd973c44e` |
| `store-qualification.json` | `dd501e1be96ee6c30a1ca32176871bc700d18fdc1ffb4d953b4a60108da88249` |
| `linear-expanded-reconciliation.json` | `531d94b4e41568764b96a44f0c5fd2eb31300ac418bd1fb5961dc92801fc1382` |

The eight scoped Linear descriptions were each updated once and read back with exact new prefixes and prior bodies. The Muses project readback retained all 120 issue states, parents and project memberships. The original 23 matrices remain open and **暂不发布** stays in effect.

The application, isolated profile, HTTP storage and empty preference file moved to the dedicated Trash by same-volume rename. The actual new staged app path was unregistered, with the 1,112 non-target registrations retained. Both owned locks were released by recoverable rename. The first read-only cleanup wrapper expected a candidate Spotlight key based on the preceding batch and stopped before mutation. The live candidate key was absent, so the executed cleanup performed zero CF setters and synchronizations. The shared typed preferences and the identities of all 79 other Trash entries matched the live snapshot.

Three temporary sources were verified in an 18,093-byte ZIP and moved recoverably. The final guard matched the full signed tree, the stopped SQLite family bytes, the protected normal app, data and preferences, and the original build-root metadata. It found the candidate paths absent and its preference domain empty. At that checkpoint, the dedicated Trash held 474,705,920 allocated bytes and 471,904,988 logical bytes. The private evidence stage held 323,584 allocated bytes, and available disk space was 591,137,718,272 bytes. The recoverable moves reclaimed zero payload bytes.

| Closure receipt | SHA-256 |
| --- | --- |
| `cleanup-receipt.json` | `ed61854004c94e655156c89ac67665737ac162274ae180b98b0fb11c803c604c` |
| `helper-archive-receipt.json` | `03cfc3d92c39b1e14ef7735583191d794eb023f032dc88e714e9a3520c881b73` |
| `final-guard.json` | `286f73e0d64edacd4a7bee8e73a289f6d1d665814c60a9ee619c4081ff5bc7ef` |
