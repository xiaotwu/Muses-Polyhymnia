# In-process App Intent handoff

2026-10-10 source repair of XW-86 under XW-75. The two existing actions now submit to the running application's shared services instead of returning an `OpenURLIntent` containing a custom `muses://` URL. Apple's [initializer contract](https://developer.apple.com/documentation/appintents/openurlintent/init(_:)) requires a universal link. This repair removes that API mismatch without adopting a new website or URL scheme.

## Implementation

`MusesApp.init` registers its already-created `ExternalPlaybackRouter` with `AppDependencyManager` after service composition, before scene construction. The registration captures a local reference to the same router injected into the view environment. It does not build another service graph or depend on view appearance.

`PlayYouTubeLinkIntent.perform` runs on MainActor, validates the supplied URL using `ExternalPlaybackRoute`, presents the main browse window through the existing entry, and submits the original URL directly to its `@Dependency` router. Unsupported parameters throw before window or playback handoff. Playback resolution and engine failures retain the existing shared UI reporting. The returned empty result does not assert that asynchronous playback succeeded.

`SearchLyricsIntent.perform` runs on MainActor and sends its query directly to `MusesSingleInstance.requestLyricsSearch`. Prefixing to 400 Swift characters and then trimming whitespace preserves the previous Intent-plus-URL-parser behavior, including an empty query for the current recording. The existing pending query remains available when the main view has not mounted yet. External URL parsing and registration are preserved for their existing callers.

The system-facing action titles, descriptions, URL/string parameters, default query, shortcut phrases and localization resources retain their existing declarations. Unit constructors bind an explicit router and window/request callbacks so tests never activate AppKit or create parallel services. These bindings are not a system invocation mechanism.

## Verification

`AppIntentHandoffTests`, `ExternalPlaybackRouterTests` and `OctoberInteractionTests`: 13 tests in three suites passed with serial Swift Testing. The new behavior tests call the actual `perform` methods with deliberate dependency and presentation bindings. They cover YouTube URL variants, shared playback identity, current-item collection occurrence and Up Next preservation, invalid parameters before side effects, shared-router resolution errors, empty/Unicode/reserved-character queries, the 400-character boundary, and ordinary empty results. They replace the old test that searched source strings for a route implementation.

Release compilation passed in 72.88 seconds. `Scripts/build-app-intents.sh Release` wrote fresh metadata only to `~/.muses/tmp/engineering-oct08/round-3/intent-metadata`. Both discoverable foreground actions retained their single URL/string parameter, titles and descriptions; the lyrics query retained its empty default. Output flags are 0, the two shortcut declarations retained their three phrases and glyphs, and all copied localization files matched source bytes. Four protected normal/installed bundle core files retained their SHA-256 hashes. `intents-metadata-verification.json` records the checks. No complete package assembly/signing or full test suite was repeated.

This phase does not claim Siri, Shortcuts or AppIntentsTesting execution. Compiler metadata and direct unit calls do not prove native system dependency resolution, cold activation or modal presentation. No application was launched or registered, no normal app bundle was overwritten, and no OS/Siri settings or global URL handler were changed. Extracted metadata and verification logs live in the private round-3 directory; the coordinator owns final CI and package verification.

## Remaining native acceptance

XW-75 remains open for an exact isolated system invocation, actual playback and provider query, cold/closed/minimized main window recovery, and existing sheet/import/gallery/Now Playing/video overlay boundaries. The source repair does not infer a modal defect or change presentation arbitration. The pending query is still consumed immediately by the current RootView notification handler; behavior while another modal is active must be checked in the native application. Actual macOS 26 and the established accessibility/device matrices remain separate acceptance work.
