# Traditional Chinese Settings copy — XW-104

While continuing XW-71, the real Settings page switched immediately to Traditional Chinese but left several General, Appearance, typography and Help labels in Simplified Chinese. This was a concrete localization gap, separately tracked as XW-104 under XW-71.

The repair adds 34 missing static translations to `zh-Hant.json`, preserving all original 762 mappings unchanged, and provides an explicit Traditional Chinese template for the dynamic information-button label (`關於…`). It does not transliterate user/provider text or change layout, focus, preferences or permissions.

## Validation

The final Release compiled successfully. All 11 existing localization/theme and font-keyboard tests passed, as did 14 release checks. The signed isolated `com.muses.acceptance.hant-settings-oct20`, build `20261020.736271.2`, contains the exact new resource bytes from source and the fresh Xcode resource bundle. Its self-contained resource alias, fresh App Intents metadata and strict/deep Developer ID signature were checked. Product inputs are frozen independently from the private scrolling diagnostic.

The actual 1280×804pt Light window on macOS 27.0.1 showed Traditional Chinese General and Appearance labels after switching language. Large text and keyboard search/Down/Return selected Georgia; all three title/track/lyric specimens were legible. The font was returned to Classic. The information button exposed `關於歌曲表格分頁`; its visible title and body used Traditional Chinese. Background tool Escape left that popover unchanged, so it adds no physical-key acceptance; the exposed AX Cancel action closed it. Earlier [XW-99](settings-info-escape-acceptance.md) human focus/Escape acceptance remains scoped to its recorded conditions.

All four Help disclosures were opened with pointer actions, and their actual text plus the visible Support labels used Traditional Chinese. No support link, account login, notification permission, output selection, Play or Import was activated. Standard size, Classic font, Simplified Chinese and General were restored through the candidate UI before normal quit. All 20 initial preferences were then compared and restored by exact value and type.

The stopped copy retains 531 Tracks and six listening events, with all user-library/import/history tables equal to the initial backup and lifecycle/ORM differences separately audited. The formal 0.6.0 app, normal library/preferences, immutable seed, earlier evidence and shared Release remain unchanged. A first backup's residual SHM check failed; that attempt and detached sidecars were retained, and the accepted stopped snapshot has DELETE journal headers, a passing immutable quick check and no required sidecar.

GitHub CI and integration are tracked in the repair pull request. This closes the demonstrated copy gap only. XW-71 remains In Review for full VoiceOver, actual macOS 26 and other unexercised configurations; no system keyboard-navigation setting changed during this follow-up.
