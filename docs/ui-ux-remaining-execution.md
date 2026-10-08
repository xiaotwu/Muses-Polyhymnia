# Remaining Linear work and compact-window execution — 2026-10-07

This round reconciled the 20 unfinished Muses issues under XW-5 against executable source and the [64-area evidence table](ui-ux-acceptance-reconciliation.md). Descriptions now distinguish implemented behavior, accepted native states, remaining checks and external limitations. Original descriptions are retained privately. No independent Linear project was returned; XW-5 is the work's parent.

## Completed scope: XW-53

At the supported 840 × 804 minimum with Queue open and Large text, the playlist overview title wrapped into fragments and the collection-detail title was squeezed away. `PlaylistsView` and `CollectionPageHeader` now prefer the existing horizontal title/actions arrangement and place the same controls below the title when the horizontal arrangement does not fit. Native action semantics, glass grouping and collection/playback state are unchanged.

The final isolated candidate was inspected on macOS 27.0.1. Home, Songs, playlist overview and `test` detail retained navigation, Queue header controls and the complete PlayerBar in the compact Light/Dark and Standard/Large combinations. The repaired headings remained readable; Queue-closed and 1280 × 804 layouts retained their ordinary arrangement. Earlier accepted idle and volume first-open evidence remains applicable to unchanged code.

The user physically confirmed visible-scale left 0%, right 100%, four Left presses back to 80%, and Escape dismissal. The reported very slight delay is subjective and unmeasured. The automated panel image incorrectly captured a miniature parent window, so no endpoint pass is inferred from that image. Subsequent main-window readback showed app volume 80% and no panel.

The final executable source passed 877 tests / 119 suites in 27.644s. Release packaging took 66.07s; strict/deep signatures, the helper and both hardened-runtime yt-dlp launch checks passed. The temporary candidate was ad-hoc signed; this establishes no Developer ID, notarization or release-installation result. A later source edit changed indentation only.

Native Appearance font search filtered to the Avenir families; Escape delivered to the main window closed the popover without selecting a font. Mini-player menu invocation could not make the target stably key/frontmost through the automation route, and enabling desktop lyrics produced no visible lyric window for the paused track. These are retained limitations, not claimed application failures or accepted auxiliary-window coverage.

## Remaining ownership

After XW-53 completion, 19 issues remain unfinished: 13 In Review and six In Progress. Review status records implementation awaiting its remaining evidence; it does not mean full acceptance.

| Issues | State | Remaining scope |
| --- | --- | --- |
| XW-6, XW-7 | In Review | Actual macOS 26 and remaining native navigation/focus/accessibility cells. |
| XW-8, XW-9 | In Review | Discovery, catalog/provider/loading branches and remaining shelf/collection presentation states. |
| XW-10, XW-13, XW-14, XW-15 | In Review | Playback coordination, queue/history states, lyric/provider/contrast and auxiliary/video/EQ evidence. |
| XW-11, XW-16, XW-17, XW-18 | In Review | Operations/settings coordination, remaining test-only operations, modal/font/help and consent/recovery branches. |
| XW-62 | In Review | Implemented cancellation/paging race repair; populated native replies remain blocked by the genuine `insufficientPermissions` response. |
| XW-25 | In Progress | Cross-page keyboard/focus, Settings/help and auxiliary windows; XW-53 is complete. |
| XW-26 | In Progress | Remaining queue/playlist/media branches, populated subscriptions and comment permission evidence. |
| XW-19 | In Progress | Missing rendered regression cells; compact-header repair evidence is linked. |
| XW-27, XW-12, XW-5 | In Progress | Aggregate reconciliation after child acceptance. Completed local journey and measurements remain distinct from outstanding cells. |

The [native ledger](ui-ux-redesign-acceptance.md) and [local journey report](ui-ux-final-local-session.md) retain the earlier accepted evidence. Actual macOS 26, populated subscriptions, deferred OS accessibility/display traversal and live comment authorization cannot be established by this local compact-window round. Other unchecked branches remain unexercised and must be targeted individually.

## Restoration and cleanup

The fresh acceptance domain was `com.muses.acceptance.remaining-oct07`, with a disposable copy of the prior isolated guest store. Desktop lyrics and MiniPlayer were restored Off; final Home was paused at 0:20, app volume 80%, Queue closed. The owned app quit; no process or window remained. The source guest SQLite SHA-256 and full original preferences were unchanged. Full temporary preferences were restored and compared before removing the disposable data/cache and all three task-created app bundles. The final registered bundle was unregistered. Seventy-three attributed test fixtures were removed using completed-run, ownership, source-prefix and unchanged-content guards. Normal installed/build apps and the current Release build were preserved.

Private screenshots, AX snapshots, build/test logs, original issue descriptions and cleanup manifests remain under `~/.muses/acceptance/com.muses.acceptance.remaining-oct07/evidence`. No screenshots or library data are committed. No Liked operations, remote writes, permission expansion, output-device changes, OS setting changes or release publication occurred.
