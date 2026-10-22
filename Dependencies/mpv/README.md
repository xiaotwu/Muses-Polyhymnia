# Muses libmpv audio dependency

This recipe builds mpv 0.41.0 in its upstream LGPL mode (`gpl=false`) and
FFmpeg 8.0 without GPL, version3 or nonfree components. It does not reuse the
GPL-enabled official mpv.app distribution. Source archive URLs, versions and
SHA-256 digests are fixed in source-lock.json; isolated Meson/Ninja wheels are
fixed in tool-lock.json. Downloads are checked before extraction or execution.
A small hash-locked mpv Meson patch includes osdep/utils-mac.c for CoreAudio
when Cocoa UI is disabled. Upstream otherwise leaves cfstr_from_cstr unresolved;
enabling Cocoa also requires its Swift UI bridge. The patch changes only the
build source list, is included with corresponding sources, and is applied by
the recipe. Strict undefined-symbol linking is enabled for libmpv.
No Homebrew install or developer PATH library is required. Prerequisites:
arm64 Mac with macOS 26+, Xcode command-line tools and Python 3.12+ with venv/pip.
The compiler and SDK version remain host inputs: this is a reproducible recipe,
not a claim of byte-identical output across Xcode versions.

Run `python3 Scripts/prepare-mpv.py --work-dir /absolute/dedicated/mpv-work`.
The same recipe and Dependencies/mpv lock layout are retained in MPV-Sources.
Set MUSES_MPV_DEPENDENCY_DIR to that directory when running build-app.sh.
The build never prepares dependencies implicitly; absent/invalid dependencies
fail closed. build-app.sh copies libraries only into a newly assembled bundle,
rewrites IDs/dependencies to @loader_path, checks closure and arm64/minimum OS,
and signs every copied dylib with the app identity before the app signature.
The engine opens Contents/Frameworks/libmpv.2.dylib by exact path.

This is an audio-only build for Muses. AAC, Opus, MP3, FLAC, ALAC and basic PCM,
MOV/MP4, Matroska/WebM, Ogg, ADTS, WAV, FLAC and HLS are enabled. HTTPS uses
Apple Secure Transport. libplacebo and libass are required mpv build inputs,
but video decoders, windowed rendering backends, script engines and yt-dlp
hooks are not enabled. Optional third-party features use explicit disabled defaults. No runtime search of global libraries is intended.
Only selected FFmpeg audio filters are compiled; EQ/rate/seek/output and actual
YouTube formats still require native acceptance. This recipe does not imply
successful playback or entitlement availability.

All upstream COPYING/LICENSE/Copyright files found in every source tree are
copied under Resources/MPV-Licenses. Resources/MPV-Sources contains the exact
corresponding source archives, locks and recipe. Resources/MPV-Provenance.json
contains the pre-relocation library hashes; a separate bundle manifest records
post-relocation hashes before signing. Source archives contain full upstream
license texts and attribution, including FreeType FTL, HarfBuzz MIT, libass ISC,
libplacebo/mpv/FFmpeg/FriBidi LGPL, Vulkan-Headers Apache-2.0 OR MIT,
and pkgconf ISC. Vulkan headers are build-only inputs. Build-only tools are not
runtime components. Do not remove source/notices from distribution. This
component inventory is not a claim that all mpv release binaries are LGPL.

Replacing LGPL libraries requires re-signing the modified app on macOS; the
build accepts rebuilt libraries through the dependency directory and includes
this recipe to permit rebuilding the same dynamic interface. Muses source
license is unchanged. A future change to dependencies/features must update the
license audit and locked sources before distribution.

Official asset inspected on 2026-10-21:
https://github.com/mpv-player/mpv/releases/download/v0.41.0/mpv-v0.41.0-macos-26-arm.zip
SHA256: 09820c0d84f6687446b84eb9df81fcf6a26ebe869cee58ea1857d7948cfb7c71
The ZIP contains mpv.tar.gz with mpv.app, its executable and third-party dylibs,
including GPL components such as libx264. It contains no libmpv or license files.
It is not used as an embedding dependency.
