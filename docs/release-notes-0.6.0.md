# Muses 0.6.0

Muses brings its YouTube music and podcast library into a rebuilt native macOS interface, with a more dependable playback, queue and playlist workflow.

- **Native Liquid Glass navigation.** Persistent navigation islands, real Back/Forward history, integrated Search and ten flat Settings categories keep browsing and preferences in one window.
- **Artwork-led collections.** A focused artwork strip, optional cover wall and complete sortable tables give songs and playlists distinct browsing modes. Compact layouts keep navigation, queue and player actions reachable.
- **A clearer playback surface.** The floating PlayerBar, full-height queue, square cover or circular vinyl Now Playing, and shared lyric typography work together. Volume endpoints and keyboard adjustments, MiniPlayer, menu-bar dismissal and desktop lyric dragging have been refined.
- **More reliable library changes.** Playlist Pull preserves the preview and ordering draft after a save error, rolls back the failed transaction and supports retry from the same panel. Saved metadata and notes refresh the open playlist and current local search immediately.
- **Stronger playback and recovery.** Failed Play requests retry correctly; queue occurrences, history and repeat behavior retain their collection context. A quick exit during cold restoration preserves the saved playback position. App Intents use the application's shared services, including verified cold-start lyric search.
- **Source and accessibility refinements.** Catalog cancellation and cache recovery, podcast continuation/progress, verified display credits, font-picker keyboard selection and distinct song/video accessibility labels receive targeted fixes.

## Compatibility and installation

**Requires macOS 26 or later on Apple Silicon (arm64).** This release uses native Liquid Glass throughout its application chrome. Muses 0.5.11 remains available for macOS 14 and 15, and its compatible entry is retained in the signed update feed.

Download the signed, notarized DMG or ZIP from this release. Install Muses in Applications, or use the existing application's update command on a supported Mac. Existing library data, playlists, likes, history and settings are preserved; no manual library reset is required.

## Verification and follow-up

The release builds on 901 reported Swift tests in 123 suites, a separately executed real disk-failure recovery test, release configuration/signature checks and scoped native acceptance. Native checks include playlist error/draft/retry recovery, retained metadata refresh, queue restoration and a genuine stopped-target lyric Intent with saved playback position preserved after normal exit.

Further keyboard, accessibility, appearance, source-specific and performance refinements will continue after this release. These retained validation conditions are tracked in Linear and the [current engineering status](engineering/current-status.md); this release does not claim every device or accessibility combination has been exercised.
