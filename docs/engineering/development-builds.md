# Complete development bundles

Run development packaging from this macOS repository using Python 3.11 or later,
Xcode and the prepared, pinned libmpv dependency. For an existing prepared
dependency, set `MUSES_MPV_DEPENDENCY_DIR` to its dedicated directory; the
packager checks its libraries, source archives, notices and provenance before
changing generated resources or the output application. To prepare a new one:

```sh
python3 Scripts/prepare-mpv.py --work-dir "$HOME/.muses/tmp/muses-development-mpv" --jobs 3
export MUSES_MPV_DEPENDENCY_DIR="$HOME/.muses/tmp/muses-development-mpv"
```

On a clean checkout, complete these two steps before the first development run:

```sh
xcodebuild -scheme Muses -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/out CODE_SIGNING_ALLOWED=NO build
./Scripts/build_and_run.sh --verify
```

The first step generates the Debug compiler values needed for system App Intents
metadata. Repeat it after changing intent declarations or their metadata. A
missing matching configuration stops packaging before downloads or output
replacement and prints the exact command. SwiftPM's ordinary `swift build`
may use a backend that does not provide the Xcode metadata layout consumed by
the metadata exporter; the explicit Xcode command produces the supported layout.

The second step assembles and verifies a complete Debug application at
`build/MusesDevelopment.app`, including both in-place resolver runtimes,
libmpv, Deno, Sparkle and App Intents metadata. It checks the signed dependency
receipts, executes Deno and both resolver copies, and never launches the GUI.
Every development mode rebuilds through the same complete packaging path;
previous `.app` resources and signatures are not reused.

Use `./Scripts/build_and_run.sh run`, `--debug`, `--logs` or `--telemetry` to
build and open the development application in the corresponding mode. It uses
`com.muses.acceptance.development`, with application data and caches under
`~/.muses/acceptance/com.muses.acceptance.development/`. The `--isolated` mode
uses a separate `build/MusesValidation.app` and
`com.muses.acceptance.validation`, and requests an in-memory store. Both
identities have independent preferences; packaging removes account authority
and disables update feeds even when the shell contains release configuration.

Quit the specific output application before rebuilding it. The packager checks
actual executable paths, including nested helpers, and refuses to overwrite a
running output. Other applications can continue running. The runner never
terminates processes by name or re-signs nested helpers with the main
application's entitlement set.

`Scripts/build-app.sh` continues to default to Release and `build/Muses.app`.
Its optional `--configuration debug|release`, `--bundle-id
com.muses.acceptance.<name>` and `--output <path.app>` parameters support other
explicitly isolated builds. Release packaging requires the corresponding
Release Xcode metadata. Packaging and verification do not constitute native
playback, accessibility, Developer ID or notarization acceptance.
