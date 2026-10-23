# Playback architecture research — 2026-10-21

Status: research and proposed experiments. The production engine has not changed.
The user reports that playback still fails. The 0.6.2 release remains held.

## Decision and evidence boundary

Prioritize a complete stream-resolution contract, then compare a single libmpv
backend with a simple AVPlayer control using the same resolved media. libmpv is
the preferred replacement to evaluate, because existing macOS and music clients
demonstrate its integration. This is an engineering recommendation, not evidence
that replacing AVPlayer fixes the current failure.

The latest retained native Next attempt failed during resolution after
20.146791 seconds. A different decoder cannot repair an extraction timeout.
The user subsequently reported continuing failure, and the isolated R3 window
was observed at song 13 with Retry and 0:00. It was quit normally and its stopped
data/preferences were copied into the private research evidence directory.
No native pass receipt was created.

Direct executable readback during this research corrected an earlier version
assumption:

| Package | yt-dlp version | Evidence |
| --- | --- | --- |
| Installed Muses 0.6.1 | 2026.08.19 | Packaged executable `--version` |
| Signed 0.6.2 R3 acceptance app | 2026.10.21 | Packaged executable `--version`; qualified inventory matches |
| Canonical signed 0.6.2 distribution | 2026.10.21 | Same executable digest as R3; qualified inventory matches |

Consequently, upgrading yt-dlp alone is already insufficient for the failed R3
case. The earlier missing-JavaScript-runtime and cooperative pipe-reader fixes
remain valid bounded findings; neither establishes complete playback reliability.
See [the runtime investigation](playlist-playback-runtime-061.md),
[the subprocess investigation](playlist-pipe-progress.md), and
[the held release](release-0.6.2.md).

The formal app inventory, normal data directory, normal preferences, earlier
engineering evidence and shared builds matched the existing preservation baseline
at the research checkpoint. The formal app was left running. No credentials,
browser state or original Shortcuts were copied. XW-74 remains paused.

## Primary-source survey

Repository metadata and selected source files were retrieved on 2026-10-21.
Stars below are approximate discovery signals, not reliability measurements.
Source snapshots use exact commits; current development code is not assumed to
be the same as a published release. None of these applications was installed or
runtime-tested in this research.

| Project | Current checkpoint | Actual implementation inspected | Relevance |
| --- | --- | --- | --- |
| Pear Desktop, formerly th-ch/youtube-music | About 33.9k stars; latest stable v3.12.0, June 28 | Electron loads the official music website through its configured URL | Reference for a complete browser-player product, rather than a native stream extractor |
| YTMDesktop | About 6.7k stars; v2.0.12, September 8 | A persistent Electron BrowserView loads `music.youtube.com` | Same browser-player category; separate login/session and UI costs |
| Metrolist | About 13.7k stars; v13.7.0, September 7 | Media3/ExoPlayer; InnerTubeX extraction; typed stream headers, expiry and range requirements | Strongest music-specific reference for stream/session contracts and bounded recovery |
| SimpMusic | About 12.3k stars; v2.3.0, October 10 | Current development core resolves streams separately and uses libmpv for desktop playback | Demonstrates a music facade with a replaceable native backend; not a guarantee against resolver failures |
| IINA | About 46.9k stars; v1.5.0, October 3 | Swift controller creates and initializes libmpv | Strong macOS integration reference |
| FreeTube | About 22.1k stars; latest listed release v0.25.3-beta, August 28 | Shaka plus a local SABR parser/transport using YouTube.js-related components | Evidence that newer web streaming can require a protocol implementation beyond a single URL |
| OuterTune | About 5.4k stars; latest stable v0.10.1, December 2025 | Default README explicitly says active development has stopped | Historical reference only; do not select it because of an old recommendation list |

Pear's [configured URL](https://github.com/pear-devs/pear-desktop/blob/7c55260773c7d8477d6b3339f36a9a3eff9ae112/src/config/defaults.ts#L53)
is loaded by its [main window](https://github.com/pear-devs/pear-desktop/blob/7c55260773c7d8477d6b3339f36a9a3eff9ae112/src/index.ts#L528).
YTMDesktop creates its [persistent BrowserView](https://github.com/ytmdesktop/ytmdesktop/blob/882db48b6fa0594ee38b58e7098161261f048078/src/main/index.ts#L1024)
and [loads the music website](https://github.com/ytmdesktop/ytmdesktop/blob/882db48b6fa0594ee38b58e7098161261f048078/src/main/index.ts#L1191).
These projects do not demonstrate an alternative native extractor simply by
having a desktop window or a downloader plugin.

Metrolist's released [13.7.0 notes](https://github.com/MetrolistGroup/Metrolist/releases/tag/v13.7.0)
describe migration to InnerTubeX and automatic client fallback. Its current
[stream cache](https://github.com/MetrolistGroup/Metrolist/blob/6d08504262de76a4ba841dc24489a754e2f48e4f/app/src/main/kotlin/com/metrolist/music/playback/StreamUrlCache.kt)
carries request headers, client identity, expiry and bounded-range requirements;
generation checks reject stale cache writes. Its
[playback data source](https://github.com/MetrolistGroup/Metrolist/blob/6d08504262de76a4ba841dc24489a754e2f48e4f/app/src/main/kotlin/com/metrolist/music/playback/MusicService.kt#L3812)
uses those values with Media3's cache/data-source layer.

Metrolist's current Android [extraction adapter](https://github.com/MetrolistGroup/Metrolist/blob/6d08504262de76a4ba841dc24489a754e2f48e4f/app/src/main/kotlin/com/metrolist/music/utils/InnerTubeXPlayer.kt)
reuses its extractor, integrates a token provider and remembers rejected stream
clients. It explicitly disables HLS/SABR for that host's playback capabilities.
This distinction matters: a library supporting a protocol does not prove that
every consuming app uses it.

The [InnerTubeX v0.11.0 library](https://github.com/MetrolistGroup/innertubex/blob/9276796a23dd6542dc211472aa8b2b66375664ac/README.md)
separates extraction, cipher processing, token provision and host playback. Its
0.x API is experimental and platform token minting remains host-owned. Its
[client-health implementation](https://github.com/MetrolistGroup/innertubex/blob/9276796a23dd6542dc211472aa8b2b66375664ac/src/commonMain/kotlin/com/metrolist/innertubex/extraction/strategy/ClientHealthTracker.kt)
demotes repeatedly failing clients within a session. These are useful design
patterns; the Kotlin library is not a drop-in Swift/macOS dependency.

SimpMusic pins a [separate core repository](https://github.com/maxrave-dev/SimpMusic/blob/0bc02c66db8482822800ecc7cf56413625048702/.gitmodules).
The inspected [desktop adapter](https://github.com/maxrave-dev/core/blob/adac4c90d118cc836d9a3dad77b15a17646ee613/media/media-jvm/src/main/java/com/simpmusic/media_jvm/mpv/MpvPlayerAdapter.kt)
implements its player interface using libmpv. Its
[libmpv setup](https://github.com/maxrave-dev/core/blob/adac4c90d118cc836d9a3dad77b15a17646ee613/media/media-jvm/src/main/java/com/simpmusic/media_jvm/mpv/MpvPlayer.kt#L230)
disables mpv's own yt-dlp hook because the app already resolves URLs, preventing
duplicate extraction. The same file configures bounded buffering and distinct
live/VOD reconnect behavior. These settings are implementation examples to test,
not values to copy blindly. Its historical
[desktop 403 report](https://github.com/maxrave-dev/SimpMusic/issues/2381)
also shows why an mpv backend alone is not sufficient.

IINA's [Swift MPVController](https://github.com/iina/iina/blob/7f2c767312858c0c55daf123252caee742edcaed/iina/MPVController.swift)
provides a native embedding reference; the [project site](https://iina.io/)
confirms mpv is its playback foundation. FreeTube's
[release explanation](https://github.com/FreeTubeApp/FreeTube/releases)
describes its SABR transition, retry/reload behavior and ongoing protocol work;
its [SABR scheme plugin](https://github.com/FreeTubeApp/FreeTube/blob/416d2c2c12961484651288c74f6bf397da49fdc7/src/renderer/helpers/player/SabrSchemePlugin.js)
is an actual transport implementation. OuterTune's
[maintainer notice](https://github.com/OuterTune/OuterTune/blob/1b91406d758a95271e53c44ddfd9ce88b50a904e/README.md)
is the reason it is excluded from the shortlist.

## What a maintained yt-dlp integration requires

### Versioned resolver components

The official [EJS guide](https://github.com/yt-dlp/yt-dlp/wiki/EJS) distinguishes
the JavaScript runtime from the solver scripts. Official bundled executables
include EJS, while its compatibility must track yt-dlp. Deno is recommended;
finding a developer-shell executable is not a packaged-app solution.

The [2026.10.21 release](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.21)
changes YouTube extraction, including the default Samsung TV client. Therefore
hard-coded client recipes age independently of Muses UI releases. The upstream
[update-channel guidance](https://github.com/yt-dlp/yt-dlp#update)
even recommends nightly for regular command-line users. For Muses, the proposed
policy is tested exact versions with provenance, matched EJS/runtime requirements
and rollback, rather than unreviewed automatic execution of every nightly.

`Scripts/copy-ytdlp.sh` currently fetches mutable `latest` assets. A future
reproducible build should record an exact release and verified asset digest.
An eventual independent resolver updater must not rewrite a signed app bundle.
That updater is a separate implementation task, not part of this research.

### Session, client and attestation are separate from decoding

The official [YouTube extractor guidance](https://github.com/yt-dlp/yt-dlp/wiki/Extractors)
recommends cookies when content requires an account; it also states that yt-dlp's
YouTube OAuth login is no longer functional. This is distinct from Muses' OAuth
authority for its existing Data API/library features.

The official [PO Token guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide)
describes separate media-server, player and subtitle token contexts. Deno/EJS
does not itself provide these tokens. The guide currently recommends a provider
plugin, with `mweb` as a supported recovery route, and warns that manually reused
tokens are no longer the recommended approach. Client requirements change; the
guide's older client table must not override newer executable source.

[BgUtils POT Provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider)
offers a persistent local provider and an on-demand script. Its authors prefer
the persistent method for performance and explicitly do not guarantee that a
token fixes all 403 responses. A packaged, lifecycle-controlled provider is a
candidate experiment. A Docker requirement or a remote credential relay is not
an acceptable ordinary Muses setup.

Public playback, account-required content and entitled high quality need
explicit session policies. Browser-cookie failure should not be paid again on
every public track, but silently dropping an account-required/Premium request
to anonymous playback is also incorrect. Preserve existing consent and keep
credential handling in the authorized isolated boundary.

### Return a stream description, not only a URL

mpv's [yt-dlp hook](https://github.com/mpv-player/mpv/blob/a43ab319fdb7aec31874999e5562c9975328cbda/player/lua/ytdl_hook.lua#L890)
requests JSON. It then [applies supplied request headers](https://github.com/mpv-player/mpv/blob/a43ab319fdb7aec31874999e5562c9975328cbda/player/lua/ytdl_hook.lua#L142)
and handles the extracted media/protocol metadata. A URL being returned does not
mean a different HTTP stack can necessarily fetch and play it in isolation.

Proposed resolver result for Muses: media identity, selected format ID, codec,
container, actual bitrate/sample rate, protocol, required request context,
expiry, session generation and an opaque credential-context handle. Do not log
raw extractor JSON, signed URLs, cookies or tokens. Sensitive request state
stays in the isolated transport/helper; only necessary non-sensitive fields
cross into UI-facing state. Cache metadata and media by actual format and
session scope, not only a requested quality label.

### High quality means the actual selected source

The official [audio-quality documentation](https://support.google.com/youtubemusic/answer/9076559?hl=en)
lists AAC/Opus quality levels, with High up to 256 kbps and Premium quality
selection. It does not promise lossless audio, 320 kbps or identical available
formats for every account/client/song. Transcoding a lower-quality source does
not add source detail.

Muses should select the best available supported audio representation for the
chosen policy and display the resolved codec/bitrate. A codec preference can be
a compatibility policy; it must not silently masquerade as the highest quality.
Public and authorized Premium samples must be reported separately.

## Confirmed Muses integration gaps

These are source findings at `dfe0ae6`; they are not a claim that all observed
failures share one cause.

| Area | Current source | Consequence to investigate |
| --- | --- | --- |
| Resolution contract | [YTDlpBridge](../../Sources/Muses/Infrastructure/YTDlpBridge.swift) uses `-g`, returns the first URL | The interface cannot carry extractor-provided headers, actual codec/bitrate or transport requirements |
| Quality | `256k` tries `ba[ext=m4a][abr<=256]` before other audio | If 128 kbps AAC and 256 kbps Opus are both available, the first branch can select AAC; the label is a cap, not proof of 256 kbps |
| Diagnostics | Resolution arguments include `--no-warnings`; engine maps final resolution failure to source unavailable | Preserve safe structured categories and stage timings instead of collapsing all failures into a generic Retry |
| HTTP | [SharedStreamResource](../../Sources/Muses/Infrastructure/SharedStreamResource.swift) supplies Range but has no extracted request-header input | Test CDN/context failures independently of decoding; do not assume all formats support the same request contract |
| Playback lifecycle | [YouTubeStreamEngine](../../Sources/Muses/Services/Playback/YouTubeStreamEngine.swift) streams through AVPlayer/custom loader, downloads, then swaps to AVAudioEngine | Additional cancellation, state, seek and handoff boundaries; compare a single backend before retaining this complexity |
| Error observation | `startAVPlayer` installs clock/completion observers; no explicit item-status/failed-to-end observer is installed there | Add meaningful failure/stall attribution in a bounded experiment; a moving UI clock is not evidence of audible output |
| Cache identity | [StreamURLCache](../../Sources/Muses/Infrastructure/StreamURLCache.swift) keys URLs by video plus requested quality | It already bounds signed expiry and invalidates URLs; extend rather than pretend expiry handling is absent |

The current coordinator already coalesces resolutions and the shared resource
already validates ranges and can renew a rejected URL. The repair direction is
to make these contracts complete and testable, not to add redundant generic
caches/retries. Merely raising 20 seconds to 24 seconds was already tried and
rejected after another native Next failure.

## Feasible routes and recommendation

| Route | Benefit | Main cost / limit | Decision |
| --- | --- | --- | --- |
| Complete yt-dlp result + direct AVPlayer | Smallest native control; isolates custom loader/handoff costs | Must verify each container/codec and preserve request context; existing EQ/spectrum handoff still needs a design | Required experimental control |
| Complete resolver + libmpv | Existing Swift embedding; mature demux/decode/seek/buffer implementation; one backend can cover streaming and cached playback | Bundle/sign native dependencies; implement event/thread boundary, output switching, EQ and spectrum integration | Preferred backend to evaluate |
| Long-lived YouTube.js helper + googlevideo/SABR + native backend | Reusable session/player state; handles newer transport models | Token provider, JS execution isolation, seekable protocol bridge and maintenance are additional work | Second resolver/transport experiment if the bounded yt-dlp route misses gates |
| InnerTubeX / NewPipeExtractor | Existing client-selection and extraction strategies | Kotlin/Java integration, host-specific attestation and distribution license differences | Study patterns; do not assume direct Swift portability |
| Complete official music website in a browser engine | Lets the website own its playback/session protocol | Reworks product/session/UI model; native processing and resource use must be reassessed | Alternative product direction, not a hidden fallback |
| Public proxy/server extraction | Moves some protocol maintenance off the device | Adds operator, network, privacy and availability dependencies | Not the default for this personal native player |

YouTube.js documents [session/player caching](https://ytjs.dev/guide/caching),
and requires a host-provided [JavaScript execution implementation](https://ytjs.dev/guide/getting-started#providing-a-custom-javascript-interpreter).
[GoogleVideo](https://github.com/LuanRT/googlevideo) supplies UMP/SABR components.
Its [Shaka example](https://github.com/LuanRT/googlevideo/blob/f5e960f4ae277164b22bc5f2c4a9faa9736bf6f6/examples/sabr-shaka-example/src/main.ts)
coordinates token minting and player-response reloads. A persistent helper may
reduce setup overhead; no Muses timing improvement has been measured.

SABR requires protocol state, not simply changing the URL suffix or returning
a different format ID. It is also not automatically more reliable: PipePipe's
[maintainer account of its 2026 rollout](https://github.com/InfinityLoop1308/PipePipe/issues/2820)
records a retreat to other clients and a subsequent corrected SABR flow. Treat
that as project-specific history, not a universal failure-rate estimate.

The [official IFrame API](https://developers.google.com/youtube/iframe_api_reference)
is a video embed API and has minimum visible-player dimensions. The
[required functionality rules](https://developers.google.com/youtube/terms/required-minimum-functionality#overlays-and-frames)
also constrain obscuring its player. It is not a documented headless Music SDK.
Pear's complete-site approach and an invisible IFrame are different designs.
The existing Muses contract forbids a WebView audio source; no change to that
contract or implementation is made by this report.

Invidious's current [installation guide](https://docs.invidious.io/installation/)
requires its companion service and server infrastructure. Moving extraction
to a public instance does not remove the upstream protocol dependency.

## Bounded implementation sequence

1. Build one isolated resolver probe around the failed public samples and
   already-authorized session modes. Return a typed result and safe stage
   diagnostics. Record resolver/client/session versions and the selected actual
   format. Observe whether failure occurs before a usable stream, at the first
   media request, in demux/decode, or after output begins. Start with the already
   packaged 2026.10.21 version so another version change does not confound it.
2. Feed the same successful resolution/context to two small signed candidates:
   direct AVPlayer with no custom loader/handoff, and libmpv with one app-owned
   player and no duplicate yt-dlp hook. Compare healthy public playback first;
   then the authorized account/quality cases. Keep account boundaries exact.
   If extraction itself fails, evaluate a maintained PO-token provider/client
   strategy before interpreting decoder comparisons.
3. Choose the passing path using measurements. Integrate it behind the existing
   `PlaybackService` facade, preserving queue occurrences, Up Next, history,
   resume positions, media keys, lyrics and persisted library IDs. Validate
   selected audio output, volume, rate, EQ and spectrum; none is automatically
   preserved by adopting libmpv. Only then make a new signed release candidate.

The intended steady-state shape is native UI/system integrations → existing
playback facade → one cancellable load/session state machine → complete
resolver/transport context → one player backend. Resolve at most the current
track and a bounded likely next track in the initial experiment. Reuse successful
player/session work and short-lived format metadata, cancel stale work, and
avoid retrying the same known-broken client without changing recovery state.

Keep the resolver and player separately replaceable. Do not build an automatic
multi-engine retry maze in the first patch. No new global user setting, browser
permission, shell dependency or library migration is required for the prototype.

## Proposed native acceptance gates

These are experiment/release targets, not measured results or promises about
all networks. Timing includes the user's wait; protocol backoff and failures
must be reported, not excluded to improve percentiles.

| Gate | Proposed evidence |
| --- | --- |
| Reproduction set | At least 20 available public tracks, including the observed failures and multiple channel/content types; fixed identities, source formats and trial order |
| Cold startup | Three real Finder cold launches with separate cold media/URL and warm-cache groups; target cold p50 ≤3 s and p95 ≤8 s on the current healthy network |
| Cached / prefetched transition | Target p95 ≤1 s for a ready cached or prefetched next track; record misses and unnecessary re-resolution |
| Reliability | At least 100 combined starts/transitions across the fixed set with zero unexplained Retry/0:00 failures; this sample is not a statistical guarantee of long-term availability |
| Sustained playback | At least one hour of uninterrupted mixed playback plus seek, pause/resume, rapid Next/Previous and an expired-URL recovery case |
| Audio quality | Actual format ID, codec, bitrate, sample rate and entitlement/session mode; no upsampling/transcoding quality claims |
| Audible output | Advancing media and decoder/output evidence plus a bounded real-listening confirmation; resolver success or a clock alone cannot pass |
| State / preservation | Collection queue and occurrence order, Up Next/history/resume, account scope, app volume/output, normal app/data/credentials and old evidence preserved |
| Distribution | Exact final signed/notarized package launched through Finder, bundled helpers/dependencies present, no developer PATH or manual dependency install |

Collect monotonic intervals for action → extraction → challenge/token work →
usable stream → first media bytes → demux/decode → output/clock, with explicit
names for what each observer really measures. Keep warm-cache, public and
authenticated results separate. Classify unavailable/private/regional/account
requirements honestly, with bounded recovery and an intact queue.

## Packaging and reuse boundaries

Muses source is MIT. Metrolist, InnerTubeX, SimpMusic and NewPipeExtractor have
GPL-family licenses; study architecture without silently copying their code
into the MIT project. YouTube.js and GoogleVideo are MIT. mpv documents a
conditional [LGPL build mode](https://github.com/mpv-player/mpv/blob/a43ab319fdb7aec31874999e5562c9975328cbda/Copyright),
including dependency constraints; select and verify the actual mpv/FFmpeg build
and notices rather than assuming any downloaded binary has that license.
The yt-dlp [release-file guidance](https://github.com/yt-dlp/yt-dlp#license)
also distinguishes its source license from bundled executable dependencies.
This is dependency/provenance work, not a conclusion about the legality of
every possible product design.

## Local research evidence

Private public-source snapshots, repository metadata, exact commit manifests,
packaged resolver-version readback and stopped-candidate evidence are retained
at `~/.muses/tmp/engineering-oct15/playback-research-oct21/`. In particular:

- `packaged-resolver-versions.json`: live formal/R3/canonical version and digest.
- `failed-native-gate.json`: continuing user failure, observed Retry, stopped
  candidate, unchanged release gate, exact package inventory verification.
- `failed-r3-snapshot/`: isolated candidate data and preferences, not normal data.
- `research-preservation-start.json`: production/data preservation checkpoint.
- `source-manifest*.json` and `*--head.json`: primary-source retrieval provenance.

Research changed documentation only. It did not run comparative playback
benchmarks, replace the production engine, merge PR #16, create a 0.6.2 tag or
release, modify the update feed, or resume XW-74. The next required artifact is
the bounded comparative probe and its measured results.
