# Native playback backend refactor

2026-10-22 update: the [cold-source startup correction](cold-resolution-timing.md#startup-stack-and-controlled-correction--2026-10-22) replaces the same-version one-file resolver with its pinned onedir runtime. A fresh signed candidate passed9/9 cold resolutions (2.937–10.671s), muted real Opus/AAC controls/cache replay and paused-position restart. All1,077 Swift/34 packaging/7 strict-worker checks passed locally. Final distribution/integration gates remain open; earlier failures and evidence boundaries below are retained.

Status: integration in progress, 2026-10-21. No new release or native playback
acceptance is implied by source, subprocess, or dependency initialization checks.
The human authorized the backend change and three Muses project chats. The current
acceptance scope is public playback; authenticated/Premium quality comes later.

## Problem and decision

The installed 0.6.1 and subsequent release candidates still fail real playlist
playback. Updating the extractor alone did not satisfy the final native gate.
The previous implementation resolved a URL, streamed through AVPlayer, separately
downloaded media, then handed audio to AVAudioEngine. This left several transport,
format, cancellation and readiness authorities to coordinate.

Production now composes one `StreamResolutionCoordinator` with one
`MpvStreamEngine`. `PlaybackService` continues to own play/pause intent, collection
queue, Up Next, completion, history and saved offsets. It does not delegate the
application queue or system media controls to mpv. The retained legacy engine is
a test/control implementation, not a runtime fallback.

libmpv is a mature decoding and buffering component, also used by
[IINA](https://iina.io/). This is a reason to test the design, not evidence that
Muses playback has passed. Extractor session, media HTTP access, decoding and
actual device output remain distinct stages.

## Resolution and source quality

- Typed JSON returns URL, safe request headers, selected format, codec,
  container, reported bitrate/sample rate/size, expiry and an opaque session ID.
  Raw JSON, signed URLs, cookies and tokens are not logged or stored in typed caches.
- Public playback does not read configured browser/file Cookie settings. Import
  and catalog operations retain their existing authorized configuration. The
  separately injectable account policy fails closed without an authorized source.
- One bounded extraction uses official `--check-formats`, without hard-coded
  alternate client recipes or identical outer retries. Output retention is bounded
  before JSON decoding. Session/quality identity and consumer cancellation apply
  to both cache hits and shared in-flight requests.
- Best/High select the best available audio representation, without an AAC-first
  preference or a fabricated 256 kbps claim. Legacy video-profile values map to
  audio-only selection without rewriting user preferences. The UI reports known
  source metadata; an unknown value cannot inherit stale library FLAC/bitrate data.

Private public-session probes of three prior samples resolved Opus/WebM format251.
Two returned media HTTP206. The thirteenth item initially returned HTTP403 even
with extracted headers. Three checked-format trials subsequently returned actual
audio bytes; those extractions took roughly 8–10 seconds. Unchecked repeats were
inconsistent. This supports a bounded checked-format trial, not a causal guarantee,
audible acceptance or a fast-start claim. Next-source preparation and completed
media cache replay must be measured separately from cold extraction.

## Native engine and cache

The client loads only `Contents/Frameworks/libmpv.2.dylib`. C calls, event draining
and destruction stay on a dedicated serial queue; borrowed event memory is copied
before crossing to MainActor. Every load and control carries a generation. The
engine starts paused and waits for media readiness; only the facade grants play
intent. Cancellation, replacement, pending seek and natural EOF cannot authorize
stale audio or advance a replacement queue occurrence.

The player does not load user mpv configuration, scripts, yt-dlp hooks or mpv
system-media controls. Volume, rate and EQ use real native controls. EQ capability
is reported separately from spectrum: the client API supplies no PCM spectrum
tap, so spectrum is unavailable rather than synthesized. A resolved next URL is
not a decoded gapless standby; normal loading consumes the bounded preparation.

Completed app-owned media cache entries remain readable. Only exact regular
files under the app's stream root can acquire local playback authority; provider
file URLs, partials, sidecars and escaping symlinks are rejected. A corrupt cache
may recover remotely once without deleting the old file. Public full downloads
use the typed headers/container, no-cookie/no-credential sessions, validated Range
responses, cancellation publication gates and atomic completion. Foreground
playback does not wait for a duplicate whole-file download; paused/idle downloads
and the opt-in budgeted pre-download service populate replay cache. Account media
caching is deferred. No signed URL/header/context sidecar is written.

Decoder-rejected cache identities are moved recoverably to a unique hidden
`.quarantine` file before remote recovery. Exact inode/device/size/timestamp
checks protect a concurrently replaced entry. Subsequent loads can use a healthy
replacement; device initialization failures and timeouts do not retire media.

## Dependency and distribution

The inspected official mpv macOS archive contains a CLI app and no libmpv. It is
not used. `Dependencies/mpv` instead pins an audio-only LGPL source closure and
build tools. The native recipe builds mpv0.41.0 and FFmpeg8.0 without GPL/nonfree
components, uses Secure Transport, retains all notices and exact corresponding
source/patch/recipe, and needs no global Homebrew installation. The build permits
rebuilding/replacing LGPL libraries and re-signing the modified application.

Packaging normalizes and audits every non-system dependency, arm64 deployment
target, install ID and signature. Missing dependencies fail before packaging
inputs change. yt-dlp2026.10.21 and Deno2.9.7 are checksum-pinned separately.
An actual 13-dylib closure, no-media API2.5 probe and exact C-shim
open/initialize/version/close have passed in private staging. This does not
establish real media or Developer ID/notarization acceptance for the final app.

## Verification and preservation

Current private evidence is under
`~/.muses/tmp/engineering-oct15/playback-backend-refactor-oct21`.
Integrated Swift build and all 1,066 tests in 144 suites passed in a private home,
including a test of that home/path boundary. The final cache/facade subset passed
21 checks, packaging policy passed 27, and the strict single-cooperative-worker
subprocess scope passed five. Early full runs exposed missing icon assets in the
private source copy; completing the tracked build inputs resolved those setup
failures without weakening the tests. Final signed candidate playback remains a
separate gate. A failed build is a compiler result, not a native
playback failure. The final candidate must exercise cold public samples, sustained
clock and audible output, next/previous, pause/seek, retries, cached replay,
actual EQ/rate/volume and selected output without changing system settings.

The formal `/Applications/Muses.app`, normal data/preferences/credentials,
original Shortcuts, older release evidence and canonical shared build directories
remain protected. New builds and test namespaces are private. No release, feed,
tag or installation update is authorized by a source/CI success alone. XW-74 stays
paused. Membership/Premium acceptance is explicitly deferred by the human.

## First native gate and output-format correction

The first signed Debug candidate at dd56fce still failed the original thirteenth
public item. Its actual trace reached typed resolution (10.846s), FILE_LOADED and
PLAYBACK_RESTART, then returned mpv AO initialization error -14. The candidate
was normally quit; this was a failed native gate, despite the source/test passes.

A controlled no-cookie probe fetched 64KiB of that same Opus251 representation.
With the exact packaged library, options and controls, decoded floatp failed at
CoreAudio's input channel-layout setup with OSStatus-50; integer and packed-float
WAV controls succeeded. Adding only audio-format=float to the paused Opus case
allowed CoreAudio to initialize. The same packed-format case then ran muted,
advanced beyond3.6s and ended with natural EOF/error0. The waveform data and
library were unchanged, and no system output setting was changed. Thus a GUI or
hardened-runtime condition is not necessary to reproduce this failure.

The C boundary now requests packed float PCM. This changes device format
negotiation, not extractor quality or the advertised source bit depth. The first
candidate and diagnostics are retained. A rebuilt signed application must still
pass real sustained public playback and audible-output acceptance; the muted
prefix probe alone cannot satisfy that gate.

## Audible public playback and delayed library cleanup

The rebuilt hardened, ad-hoc signed Debug candidate at fa6317a played the original
thirteenth item through to its natural successor, then another successor. The
human confirmed continuous audible music. Actual source displays covered
Opus48kHz/132.4kbps and AAC44.1kHz/129.6kbps. Pause, a changed seek position and
resumed advancing clock passed. A manually requested prepared next track reached
FILE_LOADED in0.274s and positive position in0.394s. These are warm/prepared
measurements: initial public extraction had timed out at20.151s, and the explicit
retry resolved in14.427s. Fast or uniformly successful cold start is not accepted.

That manual transition exposed a separate SIGSEGV about seven seconds later.
The system report identifies `io.mpv.coreaudio_stop_during_idle` while disposing
a dispatch block. The client destroyed each player and immediately dlclosed its
library; mpv0.41.0 schedules a seven-second CoreAudio idle block whose canceled
object can remain retained by libdispatch after player destruction.

A deterministic, muted local-WAV control used the exact packaged library and
three open/load/play/pause/close cycles. The original C boundary crashed with
SIGSEGV after8.323s. Retaining one process-lifetime library reference survived
12.279s, including the delayed-cleanup interval, without native errors.
This separates the unload failure from extraction, networking and UI automation.
The loader now retains one exact-path library instance for process lifetime,
while still destroying every player and balancing its per-player references.
A native subprocess regression uses a fake library with delayed callbacks and
cumulative create/load/destroy counters, checking both safe code lifetime and
state reuse across three opens without an inspection reference holding it alive.
Its unpinned control must fail in an isolated child. It does not retain one new
player/library reference per song, change the upstream idle timer, or require a
dependency rebuild.

The fresh signed candidate at680b9d9 survived four real loads in one process,
manual Next/Previous and the delayed-cleanup windows. Cache replay reached
FILE_LOADED in0.110s; a prepared next reached positive position in0.365s. Paused
seek to100s, resumed clock through126s, application volume25→20→25 and a read-only
MacBook Pro Speakers selection passed. The new completed cache was produced
inside that candidate's namespace. A separate muted three-load native probe
also accepted real EQ/rate/volume controls without decoder errors. This does not
accept podcast rate UI or a full device-switch matrix. The candidate was normally
quit and the full formal-app/data/preferences/shared-build guard passed again.
Cold next still took21.121s; no fast cold-load claim is made.

## Unfinished next-resolution ownership

A behavioral regression on the prior implementation reproduced another avoidable
wait: pressing Next during an unfinished preparation canceled it and started a
second extraction (two requests, one cancellation). The facade now claims a
matching pending preparation synchronously before canceling its old caller.
The foreground load consumes that original task, retaining its existing deadline.
Track/video/quality/session identity, explicit cancellation, replacement, expired
results, unused handoffs and deinitialization retain bounded ownership and cleanup.
A cache hit cancels the now-unneeded remote task. No scheduler, timeout, client or
account policy is changed. Safe numeric native stage8 records a claimed handoff.

Eight handoff tests passed, including the formerly failing behavioral regression.
The integrated private-home run passed1,074 tests in145 suites and the application
build passed. The native loader/configuration scope has28 passing checks. A fresh
signed application's unfinished-preparation transition remains a separate check;
source success does not establish its real start time or audible output.

## Earlier cold-source gate before the onedir correction

The signed candidate atf4e6bfc recorded stage8 before a real Next into an unfinished
resolution. Its original operation timed out after20.090s; foreground waited only
16.372s, consistent with retaining that operation and deadline. Explicit Retry
also timed out after20.119s. These failures remain in the evidence, despite the
successful handoff regression and cache replay.

After normally quitting the candidate, the same bundled extractor/runtime,
public video identity and cache produced accessible Opus251 in two CLI controls
(8.489s and11.717s, media HTTP206). The actual `YTDlpRunner.swift`, compiled into
an isolated no-GUI control, succeeded in8.882s. Restarting the unchanged signed
application in the background then resolved that same song in11.934s and reached
FILE_LOADED in13.986s. Real playback advanced through1:04 to1:22 and displayed
Opus48kHz/133.2kbps; it was paused and normally quit. No system output setting,
credential or formal-app state was changed. The final candidate retained535 track
identities; only playback counters/times, queue/session and listening events
changed. The full formal-app/data/preferences/shared-build protection audit passed.

Neither background state, utility QoS nor the diagnostics' temporary-directory
choice is an established cause: successful controls exist without changing them.
No speculative activity assertion, scheduler rewrite or enlarged timeout was
added. Next investigation should separate slot wait, process launch, first pipe
bytes, process exit, pipe EOF and typed parsing using fixed labels/numbers only,
then interleave repeated app/runner trials with one fixed public identity and
cache condition. Do not log signed URLs, arguments, raw stderr or cookies.

The backend refactor remains in draft review and0.6.2 remains unpublished.
Reliable fast cold resolution, the final Developer ID/notarized package and its
native gate remain open. Authenticated/Premium quality is deferred by the human;
no256kbps, gapless, real spectrum or complete device-switch acceptance is claimed.

The complete [source CI atf4e6bfc](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/39709566345)
passed tests, single-worker subprocess progress, disk recovery, App Intents
metadata, a fresh pinned native dependency build, preview packaging/signature
checks and artifact upload. Later documentation-only evidence updates do not
replace that source result or establish release/native acceptance.
