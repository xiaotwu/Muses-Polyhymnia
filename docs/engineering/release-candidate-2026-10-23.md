# 0.6.2 integrated release candidate — October 23

Build `20261023.3` is a private, verified public-playback candidate. The user explicitly requested **no publication**. No release tag, release asset, website deployment or production update-feed change was made.

## Integrated source

PR #18 passed independent review and exact-head CI [40014778884](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40014778884), then merged as `c8c7863db0bf70f05e1063d812995becf07d4759`. Its merge tree equals tested `82eaade`. XW-119 is Done for the narrow catalog recovery repair.

PR #17 incorporated that main and fixed XW-120: focus warmup now yields to an unfinished prepared Next request. The held B → focus C → Next B regression fails three assertions on the old code (C starts, B starts twice, B is cancelled once), then passes with the one-line guard. The handoff/engine suites pass 22 tests.

Reviewed head `c1f946d74e5bb056da852df15a7b8abdd84f9699` passed complete [CI 40032998389](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40032998389): 1,082 Swift tests/146 suites, 50 release checks, seven strict-worker tests/three suites, separate disk recovery, Release/App Intents, independent pinned audio rebuild and signed preview upload. A fresh private local build passes the same test categories and Release metadata/packaging. All 272 Swift source inputs and tracked packaging inputs match the frozen commit.

PR #17 merged as `02ebc7d6a5b44955b124278be035f6a0f8e056ea`; its whole tree equals `c1f946d`. PR #16's `dfe0ae6` is an ancestor and GitHub automatically marked it Merged. The exact merge run is [40036009685](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40036009685); its outcome is tracked separately from the already successful head run. XW-107, XW-118 and XW-120 are Done at their repaired scope.

## Release artifacts and update preparation

The fresh Release uses Xcode 27.1 / Swift 6.4 / macOS 27.0 SDK, targeting macOS 26 on arm64. No prior SwiftPM build or Xcode derived-data tree was copied. The pinned unsigned prepared audio closure and resolver/runtime archives were verified before reuse.

Developer ID Team `9URWGD9Q86`, secure timestamps and hardened runtime pass for all 229 Mach-O files and every architecture. Deno alone has `allow-jit`. Both complete resolver receipts, Python framework links, actual resolver version execution, Deno JIT execution, 13 audio libraries/20 aliases, App Intents metadata and deep/strict signatures pass. The production-identifier app was never registered or launched.

- Application submission `8c38deca-0b34-4b59-b562-794c804f037b`: Accepted, stapled, validated; Gatekeeper reports Notarized Developer ID.
- DMG submission `b0ebd9f1-0eab-4898-b2a9-e8cfba305ff9`: Accepted, stapled, validated; Gatekeeper passes.
- Final ZIP: 182,615,137 bytes; SHA-256 `088d0dff339eec4fbcafacfdf12b736fbc42a10daf88e3109873c4ed8c5cfaa3`.
- Final DMG: 175,622,310 bytes; SHA-256 `7188a9fdcb20a1f0f6e94cbea85b6738d4335e16c358b89324c90504daef6ff6`.
- ZIP extraction and read-only DMG mounting preserve the full 624-node application inventory, including file bytes, modes and symbolic links. The installer Applications link is correct.

The offline appcast's feed/archive signatures and current build/version/size/minimum-OS fields match this exact DMG and app key. Older builds `20261021.1`, `20261012.1` and `20261001.5` retain every item field. Production appcast readback is unchanged (SHA-256 `421427e863fc76c4dfe299dbe08c4d8043bc73e934e94b905e287646c06fa35d`). This is local update preparation; nothing was uploaded or switched.

The production-identifier RC has no configured OAuth client. Its public update key/feed are configured. Account provisioning and authenticated/Premium acceptance remain outside this public-playback result.

## Real isolated Release acceptance

The derivative `com.muses.acceptance.rc-20261023-3` changes only application identity/configuration and the enclosing executable signature. All 37 compiled Mach-O sections and all nested code remain byte-identical to the staged product. Its independent submission `5aad90ca-1aaa-4e3b-beb0-e39719865467` is Accepted, stapled and Gatekeeper accepted. OAuth, cookies, Web Home and updates are disabled; no credential/browser state was copied.

Native execution used macOS 27.0.1 arm64, English, a 1280×804pt window and two exact processes (61772, then 63502). The 535-track closed seed retained all metadata, and media/typed/catalog caches started empty while public runtime/extractor caches were retained. This is cold media/source resolution, not an OS cold-disk claim.

| Real path | Time to FILE_LOADED | Observed result |
| --- | ---: | --- |
| Initial paused Prima Donna restore | 10.169 s | Same 1:22 checkpoint; Opus 48 kHz; continuous clock, pause, 60 s AX seek and resume |
| Previous → Showtime Ignition | 8.081 s | AAC 44.1 kHz; advancing clock, pause, 60 s seek and resume |
| Previous → Ooh Baby | 7.487 s | AAC 44.1 kHz; advancing clock; user heard continuous normal music at 25% application volume |
| New process restores Ooh Baby cache | 0.584 s | Same song and 1:11 paused position after normal Quit; cache-selected stage recorded |
| Liked, 534 songs, real Play All | 8.198 s | First song Take Me to Tiffany's cold-loads and plays beyond 0:35 |
| Two rapid Next actions | 0.158 s ready Next; 7.745 s final load | Same process survives; unfinished preparation-handoff stage recorded, then Resonating Beats plays beyond 0:10 |

The explicit final Play All and Next actions preserve the 534 ordered queue track identities. No foreground media load timeout or native failure was observed in these bounded checks. Numeric resolver/native logs contain fixed stages/timing only, scoped to the exact PID and appropriate logger subsystem; signed URLs, payloads, cookies and raw stderr are not retained.

Roselia search → Lehre der Rose painted the actual title, artist and initial tracks. Home → Back retained the same query/detail on this Release. The first detail was already loaded at the first captured observation; no native in-flight-at-disappearance proof is claimed. Held-provider regression remains the evidence for that timing, and XW-73 retains the distinct cell.

Both processes quit normally and were confirmed absent. Application volume returned to zero. All 15 initial preference values/types were restored and read back, including the original EQ bytes (runtime JSON ordering changed, decoded bands were equal); two navigation/presentation keys remain as audited runtime state. The owned Cua session ended and only this candidate's registration was removed.

## Preservation and remaining conditions

The stopped database passes integrity checks: all 535 track identities and non-playback fields remain equal; no tracks were added or removed. Six tracks have expected play-count/last-played changes and six listening events were added (19→25); queue/session checkpoints and ORM transaction counters reflect the real actions. The final candidate position is the paused Resonating Beats checkpoint around 54.923 s, separate from the independently proven 71 s restart checkpoint.

All nine protected roots match this turn's fresh baseline: formal app, normal data/preferences, canonical build/output and four prior evidence roots. The earlier shared-cache mistake remains frozen and documented in its original evidence; no claim is made that its pre-mistake cache bytes were restored. The two earlier failed 0.6.2 artifacts remain retained.

Genuine native failure/Retry, the full device/rate matrix, macOS 26 GUI, VoiceOver and remaining XW-71/72/73/75 cells are not completed by this candidate. Premium remains deferred, XW-74 remains paused, and Erato's separate hold remains. Public publication still requires a new user instruction.

Private receipts, screenshots, source manifest, actual data diff and archives are retained under `~/.muses/tmp/engineering-oct15/pr18-integration-rc-oct23-01a16186`. Preparation corrections are preserved: an unsupported Python verification attempt, an incorrect source-popup option, a background slider press that did not seek, and the initial incomplete resolver-log subsystem filter. Supported-Python verification, AX seek with visible readback and corrected numeric captures completed afterward; these preparation attempts are not product failures or passes.
