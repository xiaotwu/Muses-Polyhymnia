# Comments retirement — October 20, 2026

The user explicitly retires comments completely, including reading comments and replies. XW-62 now tracks removal, superseding its old populated-reply/pagination acceptance and `insufficientPermissions` limitation. Historical implementation and native permission observations remain historical evidence; they are not permission work to resume.

The source removes the video-overlay comment action, presentation state, panel, volatile browser, both comment/reply Data API methods and all four feature-only response models. There is no hidden viewing route or account setting that restores the feature. The old comment-browser tests and comment-page test are retired with that implementation. The two independent stable-channel and video-metadata tests are retained as `YouTubeCatalogReadTests`.

Video playback, chapters, floating/docked presentation and shared queue/history services retain their implementation. Only the comments branch is removed from video Escape handling. No database schema, migration, account authorization, cookie fallback or permission change is introduced. Existing comments were volatile and had no persistent user-data table to delete.

## Verification

The product Release compiled successfully. A fresh isolated `com.muses.acceptance.clean-playback-oct20`, build `20261020.736271.1`, has new App Intents metadata and a strict/deep-verified Developer ID signature. Its 447 product inputs are frozen; the private scrolling receipt probe is absent from this product. The candidate uses a separate writable backup of the 531-track/6-event library, 20 allowlisted muted preferences, no OAuth client and no production URL scheme.

The 41 focused tests in six suites passed in 0.067 seconds, covering video/session behavior, retained catalog reads and queue/persistence. All 14 release configuration checks passed. Family-site links, generated iOS policy/icon parity and six release-sync unit tests passed; the release-sync publish output belongs to mocked tests and does not publish a release.

The current-source native unit opened the paused `75wwBVDPeyY` video from the PlayerBar, returned from the floating window to the main window and exercised docked video controls. Float, Close and Chapters remained available; no comment action or panel was present. Chapters visibly progressed from loading to the genuine no-chapters terminal state. No Play or Import input was sent.

An initial background-delivered tool Escape dismissed both layers, so it was not accepted as the physical-key result. The human then confirmed that one real Escape closes Chapters and a second closes video. A later tool readback still showed video without the popover; its explicit Close returned Home, paused at 0:00 with volume 0. These observations retain their separate scopes rather than attributing the second physical transition to that later readback.

The candidate quit normally. Both stopped library checkpoints retain 531 Tracks and six listening events; complete user-library/import/history tables remain equal to the baseline, with lifecycle/ORM changes audited separately. All 20 initial preferences were restored with exact values and types. The final product also contains the separately verified [Traditional Chinese Settings repair](settings-traditional-chinese-acceptance.md); it does not reintroduce the comments chain. GitHub CI and integration are tracked by [PR #12](https://github.com/xiaotwu/Muses-Polyhymnia/pull/12). The formal 0.6.0 app, normal data/preferences and earlier evidence remain protected.

## Other acceptance boundaries

XW-71 already has accepted ten-category/history, font search/pointer/arrow/Return/cancel, language/size restoration, four Help Tab/Space and information-origin Escape/focus results. Actual macOS 26, full VoiceOver and other unexercised configurations remain separate; the previous temporary Keyboard navigation setting was restored to 0.

XW-73 retains its accepted bounded real catalog and online-album playback results. Genuine identity-matched, separately consented Web Home, remaining source/account branches and external platform/accessibility cells remain open. Removing comments neither expands account access nor proves those cells.

The [native scrolling follow-up](scrolling-native-input-followup-oct20.md) records the separate baseline attempt and its input/inspection limits. No application performance optimization is inferred from comment removal.
