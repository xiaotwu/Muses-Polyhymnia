# Post-release acceptance — October 23, 2026

## Published baseline

[Muses 0.6.2](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.2), build `20261023.4`, is published from `73f1dbe6e5a93f6cb7fdf147e98f2e8ef037ee12`. The new human listening answer, actual public assets, signed update feed and all historical compatibility fields passed. The [family mirror](https://github.com/xiaotwu/Project-Muses/releases/tag/polyhymnia%2Fv0.6.2) has byte-identical DMG/ZIP/checksums and matching source provenance. See the [complete candidate/publication record](release-candidate-pr19-2026-10-23.md).

The next two cells retain their existing parents: XW-19/XW-9 for minimum-width focus cards, and XW-72/XW-14 for genuine continuous desktop lyrics. These are partial acceptance cells, not closure of all visual, VoiceOver, provider, device or OS matrices. XW-74, Premium and Erato remain paused.

## Attempt and external prerequisite

After publication, the separately signed/notarized derivative `com.muses.acceptance.rc-20261023-4` was launched through background Cua Driver 0.37.0, PID `2836`, main window `104702`. The current host reports macOS `27.0.1`, build `26A434`; this is not a separate macOS 26 acceptance result. The production bundle and normal data were not launched or replaced.

The initial window read reported `screen_locked`, zero readable accessibility elements and unknown frame freshness. A Settings lookup was refused with no input applied. A later passive read still reported the same lock-screen prerequisite. A screenshot in this state is not fresh interactive-layout proof. No theme, text-size, focus-card, playback or desktop-lyrics action has been accepted in this post-release phase.

The Mac must be awake and unlocked before continuing. The user has been asked to supply that external state; this is not a request to authorize publication again. Do not send foreground input to the lock screen. The owned candidate's normal quit and final stopped audit are also pending that prerequisite; do not kill it or stop the shared driver to manufacture cleanup.

## Prepared closed baseline and next cells

Before this launch, a new closed DB/WAL/SHM copy and read-only SQLite backup preserved the final RC checkpoint: 535 Track identities, 534 ordered queue Track UUIDs, 38 listening events, Prima at approximately 71 seconds, and 15 exact seed preferences. This is a before-state, not an after-state or GUI pass. Original returned window bounds for this attempt were 1152×724 at (324,240); take a fresh Cua read after unlocking before using geometry or element tokens.

1. **Focus cards:** Settings → Appearance, Dark and Large; actual 840×804 frame with independent readback; Songs and real imported Liked Focus strip, long title/artist, Browse collection control, complete-list expand/collapse and PlayerBar boundaries. Select only nonfocused cards, whose labels end in Select; a focused card is a playback control. Keep playback paused and mute. Restore settings/frame, quit normally and run the strict focus-only typed audit.
2. **Desktop lyrics:** use Library search without Return, because Return activates the top result. Select the existing A Head Full of Dreams recording `rwdwb5Fkgso`, obtain actual metadata and a genuine matching synced result through Match Lyrics, then Apply. Enable Settings → General → Desktop lyrics. Record actual tags and offsets; naturally cross two adjacent tags with no seek or other input during observation, and inspect both real main-clock and desktop-line painting. No existing synced lyrics are assumed from the seed. Record actual Apply/playback differences and justify only those exact columns in the stopped audit.

Restore the original appearance, desktop-lyrics state, volume, frame and seeded preferences, and close task-owned windows/processes through normal UI when available. Preserve the formal app/library/credentials, prior evidence, the exact published artifacts and the original strict audit failures. All new private evidence and the current process/lock checkpoint are under `~/.muses/tmp/engineering-oct15/release-062-pr19-oct23-01a16186/`.
