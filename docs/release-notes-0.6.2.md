# Muses 0.6.2

This patch fixes playlist songs failing to play after launching Muses from Finder, including repeated Retry at 0:00.

The application now includes the JavaScript runtime required by its media resolver and uses that bundled copy directly. Playback no longer depends on tools installed separately or on a developer shell's configuration. No library reset or playlist reimport is required.

Resolver output is drained without occupying Swift's cooperative workers, so background extraction cannot block the workers needed to start a selected playlist song.

Real playlist playback, pause/resume and Next/Previous were verified with the playlist's queue identities and canonical order preserved. Account consent and source restrictions retain their existing behavior.

## Compatibility and installation

Requires **macOS 26 or later on Apple Silicon (arm64)**. Use Check for Updates in Muses, or download the signed, notarized DMG or ZIP from this release. Existing library data and preferences remain in place.

Muses 0.5.11 remains available for macOS 14 and 15, and its compatible entry remains in the signed update feed.
