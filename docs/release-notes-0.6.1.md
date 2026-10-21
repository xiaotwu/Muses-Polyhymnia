# Muses 0.6.1

This maintenance release brings the fixes and refinements completed since 0.6.0 into the stable channel.

- **Search keeps your place in the catalog.** Returning to the same completed search preserves its category, loaded results and continuation cursor. Artist album shelves support native horizontal scrolling and keyboard focus without the previously observed accessibility crash.
- **Clearer recording credits and artwork.** Confirmed obsolete imported credits can be repaired without replacing recording identities or manual edits. Collection cover cards and Spotlight results have been refined.
- **Two lyric search modes.** Fuzzy search is the default; exact search compares complete fields and explains source limitations. Closing externally requested lyrics returns to the EQ editor that was already open.
- **A focused menu-bar player.** The compact 16:9 card keeps playback centered, moves More to the right, removes its volume control and combines playback modes into one button. Long titles pause before scrolling. Clicking the title opens the main window, and Escape closes the card when another app was previously active.
- **More dependable keyboard and window behavior.** Settings information popovers close with Escape and preserve button focus. Navigation remains reachable from immersive playback, cold-start lyric requests wait for the main window, and video yields keyboard events to native sheets and other windows. Traditional Chinese Settings translations are more complete.
- **A cleaner listening experience.** Video comments and replies, including viewing and related requests, have been removed. Home retains library-based recommendations and explicitly authorized, identity-matched account recommendations; anonymous public recommendations have been retired.

## Compatibility and installation

Requires **macOS 26 or later on Apple Silicon (arm64)**. Download the signed, notarized DMG or ZIP, or use the existing application's update command. No library reset is required. Muses 0.5.11 remains available for macOS 14 and 15, with its compatible entry retained in the signed update feed.

## Verification and follow-up

The changes have passed automated regression checks and scoped native acceptance for catalog navigation, lyric search, window handoff, Settings and menu-bar behavior. Real video playback, seek and pause/close handoff have also been exercised with preserved queue identities and order.

Broader system, account, VoiceOver, device and performance coverage remains tracked separately. This release does not claim those complete matrices, and it includes no new scrolling-performance claim.
