# Muses 0.6.3 / 20261105.1

[Muses 0.6.3](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.3) became the latest stable release on November 5, 2026 Pacific time. Release ID 435930832 targets source `12260f050a374ee949053e8f63b039fe20f15148`. The exact-source [macOS CI run](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/42132346340) passed 1,154 tests across 154 suites, 15 strict-worker checks, the disk failure check, 50 release checks, App Intents metadata generation and preview packaging.

## Distribution

The application and DMG passed Apple notarization, ticket validation and Gatekeeper. The notarization submissions were `5fdb7a39-287f-4521-a839-8cdf9b44d0bd` and `8d343348-9c07-4240-a656-6500df963930`. The independent check compared all 624 application nodes in the ZIP and read-only DMG mount, checked 442 signatures across 229 Mach-O leaves, and verified arm64 and macOS 26.0. The public static product client configuration matches 0.6.2. The local installed application and personal account state were outside the packaging scope.

| Public artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Muses-0.6.3.dmg | 175790862 | `0a5cadef91e0b2acd596405dd41bac6b64019a5c522709859fe9d12c71e258f7` |
| Muses-0.6.3.zip | 182465740 | `192b4297c6dac82c5115afb1ba7168bae4e88985959a5852f85344df8b9b5a44` |
| SHA256SUMS | 164 | `c9ad31d8af0c5b9bec4884073e494042c96310bfc123e58ff2ce0ca827007c2c` |

The draft and anonymous stable downloads match the exact asset IDs and bytes. Two local packaging stops remain recorded. Recovery reused the pinned resolver tree after checking its manifest and retried the same signed application after the Mac was unlocked. A separate ZIP verification stop was traced to the extraction process changing symlink modes. Matching the extraction mask to the archived modes restored the exact 624-node comparison.

## Isolated runtime

The private derivative retains all 37 compiled sections and the exact nested code and resources. It disables update, account and Web Home authority. The user confirmed continuous audible Prima Donna at 25% app volume on the exact derivative. The isolated player moved through Catch Catch and back, and clearing 2.9 MB of downloaded media showed Zero KB. The repeat cleared the cache, stayed paused at 1:11, saved approximately 71,000 ms in the queue and session, and reopened paused at 1:11. An earlier cold restart displayed 80.586 seconds after the screen had shown 1:11. The first stopped checkpoint was unavailable, so the cause and whether the difference occurred before or after restarting remain open. The release notes record that observation and the previously reproduced Songs cover-wall focus issue.

All three candidate processes exited through the application menu. The stopped copy retained 535 stable track records, 534 ordered Liked import members, 1,064 import members, the 534 queue occurrences and all 40 original listening events. Two additional events reflect the isolated playback. Seven queue JSON fields are equal after decoding. Three have raw serialization differences. The scoped audit excludes intentional playback counter and lifecycle changes from its equality claims.

The candidate application, profile, HTTP storage and empty preference file were moved recoverably. The exact candidate Launch Services registration and Spotlight key were withdrawn, the work locks were released, and the protected installed app, data, preferences and build-root metadata matched their baseline. The isolated Trash allocation was 371,539,968 bytes. System Settings UI residuals were outside this check.

## Automatic updates

The [public appcast](https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/updates/appcast.xml) is asset 715342915, 4,495 bytes with SHA-256 `7fcd2b4b1c0f7386e62bc16d639b6bc2b7a2534c8334c329e1f5065e2a1312c8`. Its canonical anonymous response and authenticated asset match the signed local bytes. The previous four item trees, including the macOS 14/15 compatibility entry, are identical. The first canonical request after switching received cached old bytes. The new asset identity remained stable, and the canonical link then returned and verified the new feed without another write.
