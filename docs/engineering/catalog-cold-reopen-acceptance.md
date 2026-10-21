# Catalog navigation and cold reopen — October 20, 2026

This is a bounded XW-73 native follow-up using the comment-free `com.muses.acceptance.clean-playback-oct20`, build `20261020.736271.1`, on macOS 27.0.1 with a 1280×804pt Light window. It uses a separate writable copy of the 531-track/six-event library, muted preferences, no OAuth client and no production URL scheme. It does not operate the formal app or connected account.

## Observed path

The Library Artists page truthfully reported that the existing 531 songs lack confirmed catalog artist/album pages. Refresh preserved that empty state rather than inventing identities from names.

Search for `Roselia`, with All Sources and the actual `zh-Hans/US` source locale, displayed a genuine loading marker and populated results. Opening the matching artist reached `browse:UCJzgTYxZKiK-e2_0Y5hPEAg`; opening **Lehre der Rose** reached its real 24-track album. The first track was `video:YfY82CJjyII` (Avant-garde HISTORY) and the last was `video:jOM0l0UZ-Z4` (VIOLET LINE, 10th-anniversary version).

The initial AX result exposed only the first 17 tracks. The first scroll exposed all 24 to AX while the screenshot still painted only rows around 8–17. A second native scroll painted the actual final track and footer above the PlayerBar. Only the latter is counted as visible tail acceptance. Native Back returned through artist to the retained Roselia search query and results.

After normal quit, an actual cold launch began at Home. Repeating Search → the same stable artist → the same album succeeded. This is explicit app relaunch and browsing, not restoration of the last page or an Intent invocation. No playback, import, account, output-device or system-setting action was sent.

## Cache and data comparison

Separate first-pass and cold-pass normalized catalog responses were preserved. The album retained all 24 ordered IDs and metadata; the artist retained its five ordered IDs. The search response's 25 ordered IDs differed. All three files changed bytes and fetch timestamps, so this is not a whole-response equality, offline availability, cache-hit or network-absence claim. The brief Search loading observation also does not establish in-flight HTTP cancellation.

Both stopped library checkpoints retain 531 Tracks and six listening events. Complete library, import, playlist, note, bookmark and listening-event tables match the original backup; queue lifecycle and ORM changes are recorded separately. Normal quit and all 20 original typed preferences were verified. Formal-app inventory, normal data/preferences, the immutable seed, previous evidence and shared Release inputs remain protected.

XW-73 remains In Review for genuine consented identity-matched Web Home, additional provider/error/continuation/account branches, actual macOS 26 and the remaining accessibility/platform matrix. Existing [artist catalog and native shelf repair](artist-catalog-acceptance.md) and [album playback](artist-release-playback-acceptance.md) evidence retains its own scope. Comments and replies are now [retired by user decision](comments-retirement-acceptance.md).

Private qualifications, both normalized-response sets, stopped backups and audit receipts remain under `~/.muses/tmp/engineering-oct15/catalog-settings-comments-oct20/`.
