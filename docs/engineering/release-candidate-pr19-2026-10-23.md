# 0.6.2 / 20261023.4 candidate with XW-121

October 23, 2026. The user authorized PR #19 review/merge, a fresh candidate, Linear reconciliation, publication after verification, and then the remaining acceptance cells. This supersedes the earlier publication hold; it does not resume XW-74, Premium or Erato.

## Identity and review

[PR #19](https://github.com/xiaotwu/Muses-Polyhymnia/pull/19), reviewed head `ca3b1a0c59d70eed70b6d8a9ff162f2312e80e0e`, passed independent source/test review and complete CI 40039614760. It merged as `34fa44cf3a6c41f51c4353a413309d526cac28b3`; merge CI 40041957655 also passed. The frozen release source is **`73f1dbe6e5a93f6cb7fdf147e98f2e8ef037ee12`**, version **0.6.2**, build **20261023.4**. Its [complete CI 40042082311](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40042082311) passed.

A fresh private Git archive contains 869 tracked files, including 272 Swift inputs. Swift/Xcode outputs, caches and the pinned audio dependency rebuild used this new root. Canonical build/output and the entire previous `.3` evidence root remained protected. The `.3` candidate and historical failures are retained with their own evidence boundaries.

## Fresh build and final package

- 1,092 reported tests / 148 suites; 15 strict single-cooperative-worker checks / five suites; the separate real disk-failure recovery case; all 50 release checks; Release and App Intents metadata passed.
- Developer ID, team `9URWGD9Q86`, hardened runtime and timestamps verified across 229 Mach-O leaves / 442 architecture checks. Only Deno has the JIT entitlement. Both complete resolver manifests and the pinned libmpv dependency/source closure passed. Deno evaluation and both packaged resolver version commands executed successfully.
- Official static product account-client configuration was retained from the SHA-256-verified published 0.6.1 distribution. All three configuration fields match; no personal token, Keychain item, cookie or browser state was copied. This is configuration continuity, not authenticated or Premium acceptance.
- Application notarization `20904b2b-38ad-4d06-b3a6-b899a35dc5d0` and DMG notarization `89e667a6-465e-4934-bb35-3e5dec94707e` are Accepted. Tickets, Gatekeeper and signatures passed. ZIP extraction and a read-only DMG mount reproduce the complete 624-node application inventory, including modes and symlinks.
- An independent artifact review found no blocker. Its ZIP reader initially counted AppleDouble metadata as extra application nodes; that preparation error and its correction remain recorded.

| Final artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Muses-0.6.2.zip | 182623001 | `d73d95dfdf7d993df8450bb3a28eac995b325fd0161cec5a3f27f6520391d96a` |
| Muses-0.6.2.dmg | 175602595 | `6f94932aab2fe98eb2cf89c8f940753b39841212ad0a0cde6f9093243f4b128c` |

The signed offline appcast verifies both feed and archive signatures. All fields of builds `20261021.1`, `20261012.1` and `20261001.5` are preserved; the only new build is `.4`. The live feed remained at SHA-256 `421427e863fc76c4dfe299dbe08c4d8043bc73e934e94b905e287646c06fa35d` during preparation. macOS 26 / Apple Silicon remains the current product boundary, with the old compatible macOS 14/15 entry retained.

## New native evidence

The production bundle was never registered or launched. Its isolated, separately signed/notarized derivative `com.muses.acceptance.rc-20261023-4` has all 37 compiled sections and nested code equal to the production app. Only bundle configuration and the outer signature differ; updates, account configuration, cookies and web Home are disabled. Its initial public runtime, media, typed-stream and catalog caches were absent.

The first all-cache-empty Prima load reached FILE_LOADED at 10.280769 seconds and positive position at 10.383537 seconds. Subsequent stopped rounds archive only this candidate's media cache, restart the process to clear typed-stream memory, and retain public Deno/resolver caches. The fixed nine loads below are genuine media-cold loads, not nine empty-runtime installations:

| Round | Prima positive position | Showtime positive position | Ooh Baby positive position |
| --- | ---: | ---: | ---: |
| 1 | 8.417438 s | 8.360584 s | 7.631122 s |
| 2 | 10.737851 s | 7.938387 s | 7.673181 s |
| 3 | 7.669285 s | 7.870405 s | 7.559721 s |

All nine have actual typed resolution, exit-zero matching resolver intervals, no media-cache selection, positive native position and reviewed title/codec/clock/Pause images. Across the three captured PIDs, 82 resolver requests contain no timeout event and native diagnostics contain no failure event. Resolver/native association uses adjacent timestamps, not a shared identity claim. The existing 20-second deadline was unchanged.

Additional actual controls cover the real 534-song Liked Play All, Next/Previous, rapid Next with an unfinished preparation-handoff event followed by a successful load, Opus/AAC playback, pause, an AX seek to 60 seconds followed by 1:02/Pause, cached replay, and 1:11 paused restart restoration. Ordinary native handoff does not prove the background slots were saturated; that exact XW-121 condition is covered separately by controlled production-component regressions.

The candidate played Ooh Baby at its own 25% volume for about 30 seconds and was returned to mute. **The user directly confirmed continuous normal music for this exact build `.4` listening question.** This new human answer belongs to the newly built package; the previous `.3` confirmation is not transferred.

The new package also showed the real Lehre der Rose album after Roselia search and preserved the loaded detail through Home → Back. Exact first-request cancellation, failed Retry, other sources/accounts/platforms and full accessibility matrices remain separate. A harness Return after the debounced search selected an existing Roselia recording; that playback is recorded, paused, and followed by restoration of the real Liked context and Prima at 1:11. It is not a search-detail acceptance action.

## Data and cleanup

Every stopped checkpoint preserved closed DB/WAL/SHM evidence before a read-only SQLite backup; no WAL was discarded to manufacture a clean snapshot. All 27 tables were read with typed values. The final checkpoint retains all 535 stable Track identities/non-playback fields, the ordered 534 queue Track UUIDs, imports, playlists, notes and other ordinary models. All original 19 events retain their complete values; the final count is 38. Playback counts/dates, lifecycle/checkpoints and ORM updates are reported separately.

The default strict audit receipts deliberately remain failed on one decoded `ZSMARTSHUFFLEJSON.collectionID` rotation. A separate precise supplement explains the new collection identity from actual Play All/focus-card context selections and frozen source; Smart Shuffle remains off and every other decoded field is equal. Occurrence UUID regeneration is separately reported. This narrow expected context change is accepted explicitly; the strict audit is not relabeled as an unchanged whole database.

All 15 seeded preference values, including the exact original EQ string, were restored. EQ values were already semantically equal before restoration. Two task-created route/collection keys were removed after an intermediate export demonstrated that `defaults import` merges extra keys. Window geometry is restored, all five task candidate PIDs exited normally, the named Cua session ended and its registration was withdrawn. The shared driver remains running. All ten protected roots match the fresh baseline, including formal application/data/preferences, canonical build/output and previous evidence.

## Publication checkpoint and next work

[Muses 0.6.2](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.2) was published at 2026-10-24 01:18:18 UTC (October 23 locally), release ID `422439646`, with tag resolving exactly to `73f1dbe6e5a93f6cb7fdf147e98f2e8ef037ee12`. It is the stable/latest release. The DMG, ZIP and SHA256SUMS authenticated draft and actual anonymous public downloads match their final bytes/digests and numeric asset IDs `670914513`, `670915266` and `670915959`. The checksum-file SHA-256 is `775f7f6eceafb90afb5265d4a9b05f75adf03a16da0e4aac8ad78098ac9f7c30`.

The public update feed is asset `670917691`, 3,711 bytes, SHA-256 `d54fb90e440a2d903e1b9a8ff48f209bebd834f9298a52ad5cf414b0fc193f0f`. Its feed/archive signatures verify, bytes match the signed local feed, and all three historical items retain every field. The updates release remains prerelease and is not latest. An independent audit also downloaded all three public assets and the feed. A first draft-list visibility check and a transient feed/API readback mismatch stopped the helper; exact remote state was reconciled before resuming the same release and assets. These preparation stops remain recorded and are not native playback failures. Final publication readback completed at 01:20:19 UTC. The family repository will aggregate the already-published identical bytes.

Publication is complete. Continue the Dark/Large minimum-width Songs/Liked focus-card cell and the genuine two-adjacent-line desktop-lyrics cell. The latter requires actual matching synced lyrics selected in the UI; the seed has none for the target recording. Broader matrices remain open, and paused work remains paused.

Private evidence is under `~/.muses/tmp/engineering-oct15/release-062-pr19-oct23-01a16186/`; no raw model values, lyric content, signed URLs, credentials or screenshots are published here.
