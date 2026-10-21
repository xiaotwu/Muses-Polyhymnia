# Playlist playback after a Finder launch

2026-10-21, [XW-106](https://linear.app/xiaotwu/issue/XW-106/muses-bundle-the-javascript-runtime-required-for-playlist-playback).

## Failure and cause

The installed Muses 0.6.1 / 20261021.1 showed Retry at 0:00 for the user-approved first Liked item, `6peMtOYQyNQ` (ティファニーに連れてって). A real Retry failed again. No playlist was edited. The current protection baseline was 535 Tracks, three imports, 1,064 import items, eight listening events and 47 preferences, rather than the older release smoke baseline.

Finder launched the application with `/usr/bin:/bin:/usr/sbin:/sbin`. The release bundled yt-dlp 2026.08.19 but no JavaScript runtime. The developer shell could find Deno, explaining why developer-launched playback had succeeded. [yt-dlp's EJS documentation](https://github.com/yt-dlp/yt-dlp/wiki/EJS) requires an external runtime for YouTube challenges; its standalone executable already includes the solver scripts.

A controlled resolver comparison retained the same binary, sample, Chrome playback source, quality and minimal PATH. Without a runtime it exited 1 with signature/n-challenge failures and “The page needs to be reloaded.” Adding an explicit Deno path returned one media URL successfully. Repeating with the actual signed packaged Deno succeeded in 3.359 seconds with empty stderr. Signed URLs and browser credentials were not retained in evidence or issue text. This identifies a missing distribution dependency, not a playlist-order or audio-output defect.

## Fix

The build downloads the official arm64 Deno 2.9.7 archive using a pinned SHA-256 and includes its pinned license. It embeds and signs `Contents/Helpers/deno`; only that helper receives `allow-jit`. Inside-out signing preserves its entitlement instead of applying the application's entitlements through a deep re-sign. Packaging verifies its signature and executes JavaScript under a minimal PATH.

`YTDlpBridge` passes the helper's absolute path via `--js-runtimes`, including during existing cookie recovery. `YTDlpRunner` confines Deno's cache to the app's normal or acceptance cache namespace and disables runtime update checks. Cookie preferences, playlist operations, playback/queue behavior and the released 0.6.1 assets are unchanged.

## Verification

- 1,009 Swift tests / 135 suites passed, including explicit runtime arguments with spaces and retention of the runtime/cache environment across cookie recovery. Final focused regressions: 25 tests / two suites passed. Fourteen release configuration tests passed.
- Xcode Release and SwiftPM production builds, App Intents metadata, Developer ID signing, strict bundle verification, and the signed Deno execution check passed. yt-dlp stayed at 2026.08.19, isolating the runtime change.
- The signed `com.muses.acceptance.playlist-061-fix-oct21` candidate used a fresh current-library snapshot, cold media cache, Chrome playback source, 256k quality and Finder PATH. Live resolver arguments referenced the helper inside this exact bundle.
- Real Liked playback advanced to 0:35, held while paused, resumed through 0:46, advanced Sugar Time to 0:10 with Next, and returned to the first item with Previous. The returned first item advanced and paused at 12,469.34240362812 ms. The user confirmed hearing music.
- The rendered Queue retained the 534-item current collection and separate empty Up Next. Four database checkpoints preserved every queue occurrence ID and all canonical video ordering; indices were 0 → 0 → 1 → 0. The immediate Next checkpoint precedes the next position save and is not used as a settled offset assertion. On exit, queue and listening-session scalars both saved 12,469.34240362812 ms.
- In the isolated GUI, browser access triggered the existing cookie recovery path. Its audible playback is native playback evidence, while the separate packaged authenticated resolver comparison covers the original challenge failure. These are distinct observations; authenticated GUI behavior on the installed app was not re-tested with a replacement installation.

## Preservation and boundaries

The installed 0.6.1 bundle's complete file/mode/link inventory, all 27 normal database tables and all 47 typed preferences matched the new baseline after testing. Candidate imports/order, playlist revisions, notes, bookmarks, follows, Track identities, likes and library membership stayed identical. Only the two played Tracks' counts/last-played timestamps changed; events increased 8 → 11, with the current session/queue and ORM lifecycle writes audited separately.

Both task-created GUI processes exited. Their temporary preferences were restored, including a second stopped-state restoration after lifecycle defaults were re-created. The obsolete unmodified reproduction is archived with verified bytes, modes and symlinks before cleanup. The current signed fixed candidate and private checkpoints remain available under `~/.muses/tmp/playlist-playback-061-oct21/` for follow-up; normal app/data/credentials, original release artifacts and older engineering evidence remain intact.

This is a focused code fix and native acceptance, not publication or installation of a new stable version. No 0.6.1 asset was replaced. Broader account/device/platform matrices and unrelated backlog work are not accepted by this session; XW-74 remains paused.
