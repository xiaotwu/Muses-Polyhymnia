# Post-release acceptance — October 23, 2026

## Published baseline

[Muses 0.6.2](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.2), build `20261023.4`, is published from `73f1dbe6e5a93f6cb7fdf147e98f2e8ef037ee12`. The new human listening answer, actual public assets, signed update feed and all historical compatibility fields passed. The [family mirror](https://github.com/xiaotwu/Project-Muses/releases/tag/polyhymnia%2Fv0.6.2) has byte-identical DMG/ZIP/checksums and matching source provenance. See the [complete candidate/publication record](release-candidate-pr19-2026-10-23.md).

The next two cells retain their existing parents: XW-19/XW-9 for minimum-width focus cards, and XW-72/XW-14 for genuine continuous desktop lyrics. These are partial acceptance cells, not closure of all visual, VoiceOver, provider, device or OS matrices. XW-74, Premium and Erato remain paused.

## Resumed results — October 24, 2026

The user resumed acceptance and explicitly chose background-only control. The old PID `2836` was already absent; Cua reported no candidate app/window. A new closed DB/WAL/SHM backup first passed the strict focus-only comparison against the pre-lock checkpoint. The original lock attempt remains below as history. No formal app or published artifact was launched, replaced or rebuilt.

The same signed derivative, `com.muses.acceptance.rc-20261023-4`, ran in two separately closed phases. These results apply to the current macOS 27 host, not a separate macOS 26 or full VoiceOver matrix.

### Focus cards — XW-19 / XW-9

Settings selected Dark and Large without changing font style. WindowServer independently confirmed the actual 840×804 frame. Native Songs (535) and the real imported Liked playlist (534) showed the focus strip, square artwork with separate text area, Browse collection track and handle, complete-list handle, and persistent PlayerBar within the window. Nonfocused cards were selected once, without pressing their subsequent Play action. Liked's long title/artist used intentional ellipsis without colliding with the card's playback control. Both complete lists expanded and returned to the card deck. Songs exercised the current Prima card and long artist; its separate long-title variant remains unaccepted.

The custom Browse collection element exposed increment/decrement actions, but the background Home key could not establish element focus. A background track click and drag produced no observed movement. Their acknowledgements are not successful input verification. The user declined temporary foreground control, so scrubber drag/keyboard and physical focus acceptance remain open; no product defect or performance conclusion follows from these driver limits.

The candidate remained paused at approximately 71 seconds and app volume 0%. Appearance, frame and card presentation were restored through UI, followed by normal background Command-Q and exact preference restoration. The strict `focus-only` typed audit passed without exceptions: all 535 Track values, 534 ordered queue Track and occurrence identities, and 38 old events were retained. Changes were limited to ORM transaction records/counters/optimistic locks, save timestamps and JSON key ordering. The EQ preference's temporary raw difference was also only JSON object key ordering; the final 15 typed preference values exactly match the seed, including its raw EQ JSON.

### Continuous desktop lyrics — XW-72 / XW-14

Library search selected the existing `rwdwb5Fkgso` recording without Return or import. Actual playback exposed the 3:44 duration. A genuine LRCLIB Synced result was first found automatically, then explicitly selected through Match Lyrics: matching title, Coldplay artist, A Head Full of Dreams album and 3:44 duration. The real preview and Use these lyrics action were captured. The actual normalized cache has 41 time tags; its first adjacent tags are 32.24 and 35.39 seconds. There was no LRC offset tag, saved manual offset or nonzero per-track offset.

The real Desktop Lyrics window measured 700×120. While paused, the playback slider was set once to 30 seconds; the visible 0:30 clock and desktop's pre-line state independently verify that seek despite the setter's unverified acknowledgement. One Play then naturally crossed both tags, with only passive main/desktop reads until Pause. The first pair shows main 0:33 and the first corresponding line; the second main AX sample was 0:36 while its later PNG had reached 0:37, and the desktop painted the second line. These are successive samples, not a claim of simultaneous frame-level timing. Root and an independent reviewer inspected all four actual PNGs and the action log. No lyrics or timestamps were fabricated and there was no intervening seek or input.

### Stopped data and cleanup

Desktop lyrics was disabled through General; its separate window disappeared. The real Liked table's Prima row restored the 534-track context through playback, followed by Pause and a visible 1:11 seek. A bounded table read could expose an offscreen row but could not prove window ownership for input; scrolling made the actual row visible before the background action. Table-walk timeouts are retained as tool evidence and do not resume XW-74's paused performance investigation.

Normal Command-Q closed each owned process (`7378`, then `10276`); exact PID absence and empty window readbacks were verified before raw DB/WAL/SHM copying and read-only SQLite backup. All 535 Track identities, ordinary models and the 38 old events remain; two real skipped displacement events were appended (40 total), not completed-playback evidence. Among Track columns, only the existing target's `ZLYRICS` changed outside normal playback counters/dates. The original 534 ordered queue Track UUIDs were restored; occurrence UUIDs and collection context were regenerated by the actual selection, so whole-DB/occurrence equality is not claimed.

The initial lyrics audit retains five strict violations. The explicit comparison passed allowing only `ZTRACK.ZLYRICS` for `rwdwb5Fkgso`, `ZQUEUESTATE.ZITEMSJSON`, `ZQUEUESTATE.ZORIGINALORDERIDSJSON`, `ZQUEUESTATE.ZSMARTSHUFFLEJSON`, and `ZLISTENINGSESSION.ZQUEUESNAPSHOTJSON`, justified by the real Apply and collection restoration. Item changes are limited to occurrence IDs, enqueue timestamps and that target's new lyric payload; each original-order array matches its own occurrence sequence and each session item snapshot matches its persisted queue. Smart Shuffle remains disabled; its only semantic difference is the new collection ID. Original reports retain all typed values and both queue projections.

The final 15 own preferences exactly match the seed; Desktop Lyrics is off, app volume 0%, repeat/shuffle off, Prima paused near71s, and the regular 1280×804 frame restored. Own registration was withdrawn and the Cua session ended without stopping the shared driver. All ten protected roots matched before and after the run, including the formal app, normal data/preferences, shared build roots and old evidence. The retained candidate/profile and raw evidence remain private for continued validation.

Evidence is under `~/.muses/tmp/engineering-oct15/release-062-pr19-oct23-01a16186/`: `resumed-20261024-native-evidence-summary.json`, focus and lyrics typed audits, raw closed copies/provenance, actual cache/timing plan, continuous script/call log, PNGs, preference receipts and final protected-root receipt. These engineering-document changes add no product-source, build, test-suite, publication or new human-listening claim.

### Remaining scope

XW-19 stays In Progress; XW-9, XW-72 and XW-14 stay In Review. Scrubber/keyboard/hero input, Songs long-title variant, other appearance/geometry/control combinations, Help origin focus and uninterrupted physical auxiliary focus remain. Genuine plain-only Unsynced content is still a matching-source prerequisite; do not detach a plain field from a Synced document. Provider/translation/artwork contrast, actual macOS 26 and full VoiceOver/device cells remain separate. XW-74, Premium and Erato remain paused. The two bounded results do not close any parent matrix.

## Historical attempt and external prerequisite — October 23

After publication, the separately signed/notarized derivative `com.muses.acceptance.rc-20261023-4` was launched through background Cua Driver 0.37.0, PID `2836`, main window `104702`. The current host reports macOS `27.0.1`, build `26A434`; this is not a separate macOS 26 acceptance result. The production bundle and normal data were not launched or replaced.

The initial window read reported `screen_locked`, zero readable accessibility elements and unknown frame freshness. A Settings lookup was refused with no input applied. A later passive read still reported the same lock-screen prerequisite. A screenshot in this state is not fresh interactive-layout proof. No theme, text-size, focus-card, playback or desktop-lyrics action has been accepted in this post-release phase.

The Mac must be awake and unlocked before continuing. The user has been asked to supply that external state; this is not a request to authorize publication again. Do not send foreground input to the lock screen. The owned candidate's normal quit and final stopped audit are also pending that prerequisite; do not kill it or stop the shared driver to manufacture cleanup.

## Historical prepared closed baseline and next cells — October 23

Before this launch, a new closed DB/WAL/SHM copy and read-only SQLite backup preserved the final RC checkpoint: 535 Track identities, 534 ordered queue Track UUIDs, 38 listening events, Prima at approximately 71 seconds, and 15 exact seed preferences. This is a before-state, not an after-state or GUI pass. Original returned window bounds for this attempt were 1152×724 at (324,240); take a fresh Cua read after unlocking before using geometry or element tokens.

1. **Focus cards:** Settings → Appearance, Dark and Large; actual 840×804 frame with independent readback; Songs and real imported Liked Focus strip, long title/artist, Browse collection control, complete-list expand/collapse and PlayerBar boundaries. Select only nonfocused cards, whose labels end in Select; a focused card is a playback control. Keep playback paused and mute. Restore settings/frame, quit normally and run the strict focus-only typed audit.
2. **Desktop lyrics:** use Library search without Return, because Return activates the top result. Select the existing A Head Full of Dreams recording `rwdwb5Fkgso`, obtain actual metadata and a genuine matching synced result through Match Lyrics, then Apply. Enable Settings → General → Desktop lyrics. Record actual tags and offsets; naturally cross two adjacent tags with no seek or other input during observation, and inspect both real main-clock and desktop-line painting. No existing synced lyrics are assumed from the seed. Record actual Apply/playback differences and justify only those exact columns in the stopped audit.

Restore the original appearance, desktop-lyrics state, volume, frame and seeded preferences, and close task-owned windows/processes through normal UI when available. Preserve the formal app/library/credentials, prior evidence, the exact published artifacts and the original strict audit failures. All new private evidence and the current process/lock checkpoint are under `~/.muses/tmp/engineering-oct15/release-062-pr19-oct23-01a16186/`.
