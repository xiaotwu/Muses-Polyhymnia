# Muses 0.6.3

- Song tables show the active sort field, direction and any secondary sort. Imported songs retain their saved play counts, year and genre.
- Improved playback position and play/pause restoration when clearing the media cache or changing audio quality. Cache settings report failures and offer a retry. Media downloads and discovery caches now have storage limits.
- EQ preset saves and deletions handle storage failures without losing the current preset or save draft. Audio Info shows the custom preset name.
- Home explains when the local library is empty. Catalog details reload after a language or region change, and Settings preserves its intended destination when opening a new main window.
- The packaged app loads its bundled fonts, icons and translations without depending on the development checkout.

## Compatibility

Requires **macOS 26 or later on Apple Silicon (arm64)**. Your existing library is retained. Muses 0.5.11 remains available for macOS 14 and 15.

## Known issues

Switching from a song deep in the Songs focus strip to Cover wall may open the wall at the first song. Switching back to Focus strip restores the previous focus.

One release check showed the paused position about 10 seconds ahead after clearing the media cache and restarting. A follow-up check restored the saved position correctly. The first offset remains under investigation.
