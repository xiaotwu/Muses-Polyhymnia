# Native library catalog import and refresh

The October 14 [artist-detail follow-up](artist-catalog-acceptance.md) separately records the later genuine online re-read, human horizontal shelf-tail observation, Back and an accessibility-action crash. The October 11 boundaries below remain historical.

On 2026-10-11, XW-73 completed one real YouTube Music album import, nonempty Library Albums/detail/refresh/Back route and Artists overview on macOS 27.0.1. Executable source was `3b44632`; the later `8a58f7b` changes only tests, CI and documentation. This accepts the exercised library projection, while XW-73 and its parent XW-19 retain their other source and platform conditions.

The isolated English main window measured 1280 × 804pt. Rendered observations cover this regular window; they do not establish another appearance, compact layout or macOS 26 runtime.

## Source and native observations

The source was Roselia's [Album - Lehre der Rose](https://music.youtube.com/playlist?list=OLAK5uy_nJxXSeOmjU8xLIBgy98TVvzx08SzOwGZw). Two bounded anonymous metadata reads returned all 24 distinct video IDs in the same order, with continuous indices and matching declared counts. The extractor marked it unlisted but readable by URL. This establishes complete unrestricted flat enumeration, not authenticated Data API pagination or per-video playback availability.

The normal Playlists → Import YouTube Playlist workflow displayed 24 selected items and a 24-item confirmation. Native Import created one actual import, 24 ordered occurrences and 24 Tracks. An initial automation typing attempt lost URL punctuation; native field assignment and an exact value readback corrected it before Continue. No malformed URL was submitted and no store injection replaced the UI operation.

Albums with All selected displayed the new cover card. Its detail showed the actual title, Roselia, 24 songs / 1hr55min and rows 1–24 in source order. The rendered lower rows remained above the PlayerBar. The release identity was `playlist:OLAK5uy_nJxXSeOmjU8xLIBgy98TVvzx08SzOwGZw`; its stored kind remained `unknown`, so this does not accept the narrower Album-kind filter.

Refresh Catalog belongs to the Albums overview. The exercised route was detail → Back → Refresh Catalog → same detail → Back. Refresh finished without a visible source error; release and artist refresh timestamps advanced and unavailable remained false. Only those timestamps and ORM version fields changed on the two catalog rows, and all 24 membership rows remained equal. The reopened detail retained 24 tracks; Back returned to Albums with All and the same card. A transient loading frame was not captured.

Artists overview displayed Roselia with 24 songs and a circular cover, backed by the real `channel:UCLeeo2KeEketIWQ2QK8qXLw` identity. Artist detail, expanded discography and its paging were outside this unit. The provider did not supply an MPRE identity; the application's browse route derives from the real OLAK playlist identity.

## Persistence and cleanup

Ten immutable SQLite checkpoints cover the initial clone, launch, preview, import, Albums, detail, refresh, Back, Artists and stopped application. Root independently compared all 27 tables, checked integrity and verified every source occurrence's video ID, order and Track/membership links. Actual Track count was 655 → 679, with exactly 24 new source Tracks, one import and 24 occurrences/memberships.

All original 655 Track rows, five imports/1,161 occurrences, the protected 506-item collection, ten revisions, ordinary Playlist, note, bookmark, 60 listening events and podcast state were preserved. Original Track ORM versions also remained equal. Queue/current-position/order/repeat/shuffle semantics were unchanged apart from the known restoration of nine missing historyRecordID bindings. Session/save timestamps and Core Data bookkeeping are separately recorded; whole-file byte equality is not claimed.

The PlayerBar stayed paused at the original 0:20 and app volume 0%. No transport, video, account, comments or remote playlist write was activated. Startup nevertheless produced a current-track stream-cache file while restoring the paused track; this is not a zero-media-download run. That owned cache was inventoried and removed after shutdown.

Native Command-Q exited the exact candidate. Temporary preferences were restored before quit; an own-domain plist recreated during exit was preserved as evidence and removed afterward. Exact candidate registration, bundle, namespace/data/cache and owned processes were cleared. Root independently rechecked 12 protected files, all five matching metadata resources, seed mode 0400 and owned path/process/preference absence. Normal applications, library and Keychain were preserved. Both execution locks were released.

Private evidence: `~/.muses/tmp/engineering-oct08/round-4/catalog-native-20261011-8821f59e/`; root review: `round-4/root/xw73-catalog-independent-review.json`. Cua rendered images and AX observations remain in the execution chat's tool records; no local PNG export or independent root screenshot inspection is claimed. The ten databases, normalized public-cache responses, ownership and cleanup records remain private.

## Remaining scope

This unit does not accept album playback, artist detail, authenticated paging, a cold restart, transient loading, genuine source-error/manual-Retry recovery or the complete appearance/accessibility matrix. Identity-matched Personalized Home still needs its existing dedicated consent and channel conditions. Earlier accepted public browsing and playback evidence remains separately scoped in [source-state acceptance](source-state-acceptance.md).
