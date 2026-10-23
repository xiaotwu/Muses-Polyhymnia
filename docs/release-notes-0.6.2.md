# Muses 0.6.2 — release candidate notes

**Unpublished candidate plan.** The next integrated candidate is planned as build `20261023.3`. Its final package, signing, notarization and native acceptance checks remain pending. These notes do not announce an available update.

## Included changes

Public playback moves to a single native streaming backend while Muses retains control of the collection queue, Up Next, history and saved positions. Public playback does not use configured browser cookies. Authenticated and Premium-quality acceptance remains deferred.

The application bundles the complete media resolver and its required JavaScript runtime, so playback does not depend on separately installed tools or a developer shell. The resolver packaging addresses a measured startup stall that contributed to cold playback timeouts. The existing deadline and source restrictions remain in place; a universal startup-time guarantee is not claimed.

Returning to Search resumes an interrupted album, artist or podcast detail without replacing the selected destination. Retrying additional search results preserves the catalog category, loaded results and continuation state. Explicit catalog failures retain their own Retry action.

Earlier candidate results are recorded in the [engineering release record](engineering/release-0.6.2.md). They are not acceptance results for this new integrated package. No library reset or playlist reimport is required by these changes.

## Compatibility and availability

The planned release requires **macOS 26 or later on Apple Silicon (arm64)**. Muses 0.6.2 remains on hold; no new installation asset or update-feed entry is being published during this candidate validation.

Muses 0.5.11 remains available for macOS 14 and 15, and its compatible entry remains in the signed update feed.
